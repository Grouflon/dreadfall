const text_decoder = new TextDecoder();
let w = null; // the WASM module
let canvas;

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

function ptr_to_float32(ptr)
{
    const buffer = w.instance.exports.memory.buffer;
    return new Float32Array(buffer)[Number(ptr)/4];
}

function strlen(ptr, max_size = 256)
{
    const buffer = w.instance.exports.memory.buffer;
    const bytes = new Uint8Array(buffer);
    ptr = Number(ptr);
    end = ptr;
    while (bytes[end] != 0 && end < ptr + max_size) { ++end; }
    return end - ptr;
}

function c_string_to_js_string(ptr)
{
    const buffer = w.instance.exports.memory.buffer;
    const bytes = new Uint8Array(buffer, Number(ptr), strlen(ptr));
    return text_decoder.decode(bytes);
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

// Core program foreign functions
const core =
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

    wasm_create_window: (width, height, window_name, background_color, wanted_msaa) =>
    {
        canvas = document.createElement("canvas");
        canvas.id = "window";
        canvas.style.cssText += "aspect-ratio:" + width + "/" + height + ";";
        canvas.style.cssText += "max-width:" + width + "px;";
        canvas.style.cssText += "max-height:" + height + "px;";

        var r = Math.floor(ptr_to_float32(background_color) * 255);
        var g = Math.floor(ptr_to_float32(background_color+4n) * 255);
        var b = Math.floor(ptr_to_float32(background_color+8n) * 255);
        canvas.style.cssText += "background-color: rgb("+r+","+g+","+b+");";

        document.title = c_string_to_js_string(window_name);

        content.append(canvas);
        return 1n;
    },
}

// Load the WASM file we compiled and run its main.
WebAssembly.instantiateStreaming(
    fetch("dreadfall.wasm"),
    { "env": make_environment(core) }
).then(
    (obj) => {
        w = obj;
        console.log(w);
        console.log(w.instance.exports);

        const on_wasm_update = find_name_by_regexp(w.instance.exports, "on_wasm_update");
        const on_wasm_keydown = find_name_by_regexp(w.instance.exports, "on_wasm_keydown");
        const on_wasm_keyup = find_name_by_regexp(w.instance.exports, "on_wasm_keyup");

        obj.instance.exports.main(0, BigInt(0));

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
