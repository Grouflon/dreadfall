#scope_export

create_window :: (width: int, height: int, window_name: string, background_color: Color = DEFAULT_WINDOW_CREATION_COLOR) -> *void #foreign;

update_input_events :: ()
{
    input_per_frame_event_and_flag_update();

    for event : pending_events
    {
        if event.type ==
        {
            case .KEYBOARD;
            {
                if event.key_pressed
                {
                    if (input_button_states[event.key_code] & .DOWN) == 0
                    {
                        input_button_states[event.key_code] = .DOWN | .START;
                    }
                }
                else
                {
                    if (input_button_states[event.key_code] & .DOWN) != 0
                    {
                        input_button_states[event.key_code] = .END;
                    }
                }
            }
        }
    }

    array_add(*events_this_frame, ..pending_events);
    pending_events.count = 0;
}

create_opengl_context :: () #foreign;

init_opengl_context :: (window: *void)
{
    create_opengl_context();
    gl_load_wasm(*gl);
}

swap_buffers :: (window: *void)
{

}

#scope_file
wasm_to_jai_key_code :: (key_code: u32) -> Key_Code
{
    if key_code ==
    {
        case 16; return Key_Code.SHIFT;
        case 17; return Key_Code.CTRL;
        case 18; return Key_Code.ALT;
        case 19; return Key_Code.PAUSE;

        case 33; return Key_Code.PAGE_UP;
        case 34; return Key_Code.PAGE_DOWN;
        case 35; return Key_Code.END;
        case 36; return Key_Code.HOME;
        case 37; return Key_Code.ARROW_LEFT;
        case 38; return Key_Code.ARROW_UP;
        case 39; return Key_Code.ARROW_RIGHT;
        case 40; return Key_Code.ARROW_DOWN;

        case 45; return Key_Code.INSERT;
        case 46; return Key_Code.DELETE;

        case 112; return Key_Code.F1;
        case 113; return Key_Code.F2;
        case 114; return Key_Code.F3;
        case 115; return Key_Code.F4;
        case 116; return Key_Code.F5;
        case 117; return Key_Code.F6;
        case 118; return Key_Code.F7;
        case 119; return Key_Code.F8;
        case 120; return Key_Code.F9;
        case 121; return Key_Code.F10;
        case 122; return Key_Code.F11;
        case 123; return Key_Code.F12;

        case 145; return Key_Code.SCROLL_LOCK;

        case; return xx key_code;
    }
}

on_key_event :: (key_code: u32, pressed: bool)
{
    jai_key_code: = wasm_to_jai_key_code(key_code);
    array_add(*pending_events, .{
        shift_pressed = (input_button_states[Key_Code.SHIFT] & .DOWN) != 0,
        ctrl_pressed = (input_button_states[Key_Code.CTRL] & .DOWN) != 0,
        alt_pressed = (input_button_states[Key_Code.ALT] & .DOWN) != 0,
        type = Event_Type.KEYBOARD,
        key_pressed = xx pressed,
        key_code = jai_key_code,
        repeat = xx (input_button_states[jai_key_code] & .DOWN),
    });
}

pending_events : [..]Event;

#import "Input";

#scope_export

// WASM callbacks
on_wasm_keydown :: (key_code: u32) #c_call
{
    push_context
    {
        on_key_event(key_code, true);
    }
}

on_wasm_keyup :: (key_code: u32) #c_call
{
    push_context
    {
        on_key_event(key_code, false);
    }
}

wasm_alloc :: (size: s64) -> *void #c_call
{
    push_context
    {
        return alloc(size);
    }
}

// GL bindings
gl_load_wasm :: (procs: *GL_Procedures)
{
    procs.glGetString = _glGetString;
    procs.glGenVertexArrays = _glGenVertexArrays;
    procs.glBindVertexArray = _glBindVertexArray;
    procs.glGenBuffers = _glGenBuffers;
    procs.glBindBuffer = _glBindBuffer;
    procs.glClearColor = _glClearColor;
    procs.glClear = _glClear;
}

_glGetString :: (pname: GLenum) -> *GLubyte #foreign;
_glGenVertexArrays :: (n: GLsizei, arrays: *GLuint) #foreign;
_glBindVertexArray :: (array: GLuint) #foreign;
_glGenBuffers :: (n: GLsizei, buffers: *GLuint) #foreign;
_glBindBuffer :: (target: GLenum, buffer: GLuint) #foreign;
_glClearColor :: (red: GLfloat, green: GLfloat, blue: GLfloat, alpha: GLfloat) #foreign;
_glClear :: (mask: GLbitfield) #foreign;

