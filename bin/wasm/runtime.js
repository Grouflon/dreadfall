const text_decoder = new TextDecoder();
const text_encoder = new TextEncoder();
let w; // the WASM module
let canvas;
let gl;

const RETURN_BUFFER_SIZE = 1024n
let return_buffer_ptr;

const content = document.getElementById("content");

function find_name_by_regexp(exports, prefix)
{
    const re = new RegExp('^'+prefix+'_[0-9a-z]+$');
    for (let name in exports) {
        if (re.test(name)) {
            return exports[name];
        }
    }
    return null;
}

function make_environment(...envs)
{
    return new Proxy(envs, {
        get(target, prop, receiver) {
            for (let env of envs) {
                if (env.hasOwnProperty(prop)) {
                    return env[prop];
                }
            }
            return (...args) => {console.error("NOT IMPLEMENTED: "+prop, args)}
        }
    });
}

function read_float32(ptr)
{
    ptr = Number(ptr);
    const buffer = w.instance.exports.memory.buffer;
    return new Float32Array(buffer)[ptr/4];
}

function read_u8(ptr)
{
    ptr = Number(ptr);
    const buffer = w.instance.exports.memory.buffer;
    return new Uint8Array(buffer)[ptr];
}

function read_u32(ptr)
{
    ptr = Number(ptr);
    const buffer = w.instance.exports.memory.buffer;
    return new Uint32Array(buffer, ptr, 4)[0];
}

function read_u64(ptr)
{
    ptr = Number(ptr);
    const buffer = w.instance.exports.memory.buffer;
    return Number(new BigUint64Array(buffer, ptr, 8)[0]);
}

function read_color(ptr)
{
    ptr = Number(ptr);
    const buffer = w.instance.exports.memory.buffer;
    const bytes = new Uint8Array(buffer);
    return {
        r: bytes[ptr],
        g: bytes[ptr+1],
        b: bytes[ptr+2],
        a: bytes[ptr+3],
    }
}

function read_string(ptr, length)
{
    ptr = Number(ptr);
    length = Number(length);
    const buffer = w.instance.exports.memory.buffer;
    const bytes = new Uint8Array(buffer, ptr, length);
    return text_decoder.decode(bytes);
}

function read_jstring(ptr)
{
    ptr = Number(ptr);
    const buffer = w.instance.exports.memory.buffer;
    const count = read_u64(ptr);
    const str_ptr = read_u64(ptr+8);
    return read_string(str_ptr, count);
}

function read_cstring(ptr)
{
    ptr = Number(ptr);
    return read_string(ptr, strlen(ptr));
}

function write_cstring(ptr, str)
{
    console.assert(typeof str == "string", "str is not a string", str);
    const str_bytes = text_encoder.encode(str);
    const buffer = w.instance.exports.memory.buffer;
    var bytes = new Uint8Array(buffer);
    bytes.set(str_bytes, Number(ptr));
    bytes.set(0, Number(ptr) + str_bytes.byteLength);
}

function write_u32(ptr, n)
{
    console.assert(typeof n == "number", "n is not a number", n);
    console.assert(n >= 0, "%f is not an unsigned number", n);
    ptr = Number(ptr);
    
    const buffer = w.instance.exports.memory.buffer;
    const bytes = new Uint8Array(buffer);
    const n_bytes = number_to_ubytes(n).slice(0,4);
    bytes.set(n_bytes, ptr);
}

function strlen(ptr, max_size = 256)
{
    ptr = Number(ptr);
    const buffer = w.instance.exports.memory.buffer;
    const bytes = new Uint8Array(buffer);
    end = ptr;
    while (bytes[end] != 0 && end < ptr + max_size) { ++end; }
    return end - ptr;
}

function number_to_ubytes(x)
{
    // stolen here: https://stackoverflow.com/questions/8482309/converting-javascript-integer-to-byte-array-and-back
    // but reversed endianness
    // Don't know if it is actually robust or not + we surely need a different algorithm for signed and unsigned
    let y= Math.floor(x/2**32);
    return [(x<<24),(x<<16),(x<<8),x,(y<<24),(y<<16),(y<<8),y].map(z=> z>>>24)
}

function return_string(str)
{
    console.assert(str.length < RETURN_BUFFER_SIZE, "string \"%s\" is too long for the return buffer of %d bytes", str, RETURN_BUFFER_SIZE);
    write_cstring(return_buffer_ptr, str);
    return return_buffer_ptr;
}

// console.log and console.error always add newlines so we need to buffer the output from write_string
// to simulate a more basic I/O behavior. We’ll flush it after a certain time so that you still
// see the last line if you forget to terminate it with a newline for some reason.
let console_buffer = "";
let console_buffer_is_standard_error;
let console_timeout;
const FLUSH_CONSOLE_AFTER_MS = 3;
function write_to_console_log(str, to_standard_error) {
    if (console_buffer && console_buffer_is_standard_error != to_standard_error) {
        flush_buffer();
    }

    console_buffer_is_standard_error = to_standard_error;
    const lines = str.split("\n");
    for (let i = 0; i < lines.length - 1; i++) {
        console_buffer += lines[i];
        flush_buffer();
    }

    console_buffer += lines[lines.length - 1];

    clearTimeout(console_timeout);
    if (console_buffer) {
        console_timeout = setTimeout(() => {
            flush_buffer();
        }, FLUSH_CONSOLE_AFTER_MS);
    }

    function flush_buffer() {
        if (!console_buffer) return;

        if (console_buffer_is_standard_error) {
            console.error(console_buffer);
        } else {
            console.log(console_buffer);
        }

        console_buffer = "";
    }
}

// Jai foreign functions
const jai_exports =
{
    wasm_write_string: (s_count, s_data, to_standard_error) =>
    {
        if (s_count <= 0) return;
        const buffer = w.instance.exports.memory.buffer;
        const bytes = new Uint8Array(buffer, Number(s_data), Number(s_count));
        const s = text_decoder.decode(bytes);
        write_to_console_log(s, to_standard_error);
    },

    wasm_debug_break: () =>
    {
        debugger;
    },
}

const gl_exports =
{
    create_opengl_context: () =>
    {
        gl = canvas.getContext("webgl2");

        // Resources containers since webgl does not use indices
        gl.vaos = new Array();
        gl.vaos.push(null);
        gl.get_vao = (array_index) =>
        {
            array_index = Number(array_index);
            let vao = gl.vaos[array_index];
            console.assert(vao, "undefined vertex array %d", array_index);
            return vao;
        }

        gl.vbos = new Array();
        gl.vbos.push(null);
        gl.get_vbo = (buffer_index) =>
        {
            buffer_index = Number(buffer_index);
            let vbo = gl.vbos[buffer_index];
            console.assert(vbo, "undefined buffer %d", buffer_index);
            return vbo;
        }

        gl.shaders = new Array();
        gl.shaders.push(null);
        gl.get_shader = (shader_index) =>
        {
            shader_index = Number(shader_index);
            let shader = gl.shaders[shader_index];
            console.assert(shader, "undefined shader %d", shader_index);
            return shader;
        }

        gl.programs = new Array();
        gl.programs.push(null);
        gl.get_program = (program_index) =>
        {
            program_index = Number(program_index);
            let program = gl.programs[program_index];
            console.assert(program, "undefined program %d", program_index);
            return program;
        }
    },

    _glGetString: (pname) =>
    {
        return return_string(gl.getParameter(pname));
    },

    _glGenVertexArrays: (n, arrays) =>
    {
        for (i = 0; i < n; ++i)
        {
            gl.vaos.push(gl.createVertexArray());
            write_u32(Number(arrays) + i, gl.vaos.length - 1);
        }
    },

    _glBindVertexArray: (array_index)  =>
    {
        gl.bindVertexArray(gl.get_vao(array_index));
    },

    _glVertexAttribPointer : (index, size, type, normalized, stride, pointer) =>
    {
        gl.vertexAttribPointer(index, size, type, normalized, Number(stride), Number(pointer));
    },

    _glEnableVertexAttribArray : (index) =>
    {
        gl.enableVertexAttribArray(index);
    },

    _glGenBuffers: (n, buffers) =>
    {
        for (i = 0; i < n; ++i)
        {
            gl.vbos.push(gl.createBuffer());
            write_u32(Number(buffers) + i, gl.vbos.length - 1);
        }
    },

    _glBindBuffer(target, buffer_index)
    {
        gl.bindBuffer(target, gl.get_vbo(buffer_index));
    },

    _glBufferData : (target, size, data, usage) =>
    {
        const buffer = w.instance.exports.memory.buffer;
        const bytes = new Uint8Array(buffer, Number(data), Number(size));
        gl.bufferData(target, bytes, usage);
    },

    _glClearColor: (r, g, b, a) =>
    {
        gl.clearColor(r, g, b, a);
    },

    _glClear: (mask) =>
    {
        gl.clear(mask);
    },

    _glCreateShader: (type) =>
    {
        gl.shaders.push(gl.createShader(type));
        return gl.shaders.length - 1;
    },

    _glShaderSource: (shader_index, count, str_array, length_array) =>
    {
        let final_source = "";
        for (i = 0; i < count; ++i)
        {
            const str = read_u64(Number(str_array) + i);
            const len = read_u32(Number(length_array) + i);
            const source = read_string(str, len);
            final_source += source;
        }

        gl.shaderSource(gl.get_shader(shader_index), final_source);
    },

    _glCompileShader: (shader_index) =>
    {
        gl.compileShader(gl.get_shader(shader_index));
    },

    _glGetShaderiv: (shader_index, pname, params) =>
    {
        let param = gl.getShaderParameter(gl.get_shader(shader_index), pname);
        if (typeof param == "boolean")
        {
            param = param ? 1 : 0;
        }
        write_u32(params, param);
    },

    _glGetShaderInfoLog: (shader_index, buf_size, length, info_log_ptr) =>
    {
        let info_log = gl.getShaderInfoLog(gl.get_shader(shader_index));

        info_log = info_log.substring(0, Math.min(info_log.length, buf_size - 1));
        write_cstring(info_log_ptr, info_log);
        write_u32(length, info_log.length);
    },

    _glDeleteShader: (shader_index) =>
    {
        gl.deleteShader(gl.get_shader(shader_index));
    },

    _glCreateProgram: () =>
    {
        gl.programs.push(gl.createProgram());
        return gl.programs.length - 1;
    },

    _glAttachShader: (program_index, shader_index) =>
    {
        gl.attachShader(gl.get_program(program_index), gl.get_shader(shader_index));
    },

    _glLinkProgram: (program_index) =>
    {
        gl.linkProgram(gl.get_program(program_index));
    },

    _glGetProgramiv: (program_index, pname, params) =>
    {
        let param = gl.getProgramParameter(gl.get_program(program_index), pname);
        if (typeof param == "boolean")
        {
            param = param ? 1 : 0;
        }
        write_u32(params, param);
    },

    _glGetProgramInfoLog: (program_index, buf_size, length, info_log_ptr) =>
    {
        let info_log = gl.getProgramInfoLog(gl.get_program(program_index));

        info_log = info_log.substring(0, Math.min(info_log.length, buf_size - 1));
        write_cstring(info_log_ptr, info_log);
        write_u32(length, info_log.length);
    },

    _glUseProgram: (program_index) =>
    {
        gl.useProgram(gl.get_program(program_index));
    },

    _glDrawArrays: (mode, first, count) =>
    {
        gl.drawArrays(mode, first, count);
    },
}

// Backend foreign functions
const backend_exports =
{
    create_window: (width, height, window_name, background_color) =>
    {
        canvas = document.createElement("canvas");
        canvas.id = "window";
        canvas.style.cssText += "aspect-ratio:" + width + "/" + height + ";";
        canvas.style.cssText += "max-width:" + width + "px;";
        canvas.style.cssText += "max-height:" + height + "px;";

        background_color = read_color(background_color);
        canvas.style.cssText += "background-color: rgb("+background_color.r+","+background_color.g+","+background_color.b+");";

        document.title = read_jstring(window_name);

        content.append(canvas);
        return 1n;
    },
}

// Load the WASM file we compiled and run its main.
WebAssembly.instantiateStreaming(
    fetch("dreadfall.wasm"),
    { "env": make_environment(jai_exports, gl_exports, backend_exports) }
).then(
    (obj) => {
        w = obj;
        // console.log(w);
        // console.log(w.instance.exports);

        const wasm_alloc = find_name_by_regexp(w.instance.exports, "wasm_alloc");
        const on_wasm_update = find_name_by_regexp(w.instance.exports, "on_wasm_update");
        const on_wasm_keydown = find_name_by_regexp(w.instance.exports, "on_wasm_keydown");
        const on_wasm_keyup = find_name_by_regexp(w.instance.exports, "on_wasm_keyup");

        return_buffer_ptr = wasm_alloc(RETURN_BUFFER_SIZE);

        obj.instance.exports.main(0, 0n);

        let _previous_timestamp = null;

        function first_frame(timestamp)
        {
            _previous_timestamp = timestamp;
            window.requestAnimationFrame(update_frame);
        }

        function update_frame(timestamp)
        {
            var dt = (timestamp - _previous_timestamp) * 0.001;
            _previous_timestamp = timestamp;
            on_wasm_update(dt);
            window.requestAnimationFrame(update_frame);
        }

        document.addEventListener('keydown', (e) =>
        {
            on_wasm_keydown(e.keyCode);
        });

        document.addEventListener('keyup', (e) =>
        {
            on_wasm_keyup(e.keyCode);
        });

        window.requestAnimationFrame(first_frame);
    }
);
