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

function read_jstring(ptr)
{
    ptr = Number(ptr);
    const buffer = w.instance.exports.memory.buffer;
    const count = read_u64(ptr);
    const str_ptr = read_u64(ptr+8);
    const bytes = new Uint8Array(buffer, str_ptr, count);
    return text_decoder.decode(bytes);
}

function read_cstring(ptr)
{
    ptr = Number(ptr);
    const buffer = w.instance.exports.memory.buffer;
    const bytes = new Uint8Array(buffer, ptr, strlen(ptr));
    return text_decoder.decode(bytes);
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
    const str_bytes = text_encoder.encode(str);
    console.assert(str_bytes.byteLength < RETURN_BUFFER_SIZE, "string \"%s\" is too long for the return buffer of %d bytes", str, RETURN_BUFFER_SIZE);
    const buffer = w.instance.exports.memory.buffer;
    var bytes = new Uint8Array(buffer);
    bytes.set(str_bytes, Number(return_buffer_ptr));
    bytes.set(0, Number(return_buffer_ptr) + str_bytes.byteLength);
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

        gl.vbos = new Array();
        gl.vbos.push(null);
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

    _glBindVertexArray(array)
    {
        array = Number(array);
        let vao = gl.vaos[array];
        console.assert(vao, "undefined vertex array %d", array);
        gl.bindVertexArray(vao);
    },

    _glGenBuffers: (n, buffers) =>
    {
        for (i = 0; i < n; ++i)
        {
            gl.vbos.push(gl.createBuffer());
            write_u32(Number(buffers) + i, gl.vbos.length - 1);
        }
    },

    _glBindBuffer(target, buffer)
    {
        buffer = Number(buffer);
        let vbo = gl.vbos[buffer];
        console.assert(vbo, "undefined buffer %d", buffer);
        gl.bindBuffer(target, vbo);
    },

    _glClearColor: (r, g, b, a) =>
    {
        gl.clearColor(r, g, b, a);
    },

    _glClear: (mask) =>
    {
        gl.clear(mask);
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
