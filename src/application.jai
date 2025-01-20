InitFunction :: #type ();
UpdateFunction :: #type (dt: float32);
ShutdownFunction :: #type ();

Application :: struct
{
    window: Window_Type;
    stop_requested: bool;

    init_function: InitFunction;
    update_function: UpdateFunction;
    shutdown_function: ShutdownFunction;
}

ApplicationParameters :: struct
{
    width: int;
    height: int;
    name: string;

    init_function: InitFunction;
    update_function: UpdateFunction;
    shutdown_function: ShutdownFunction;
}

app: Application;

application_start :: (parameters: ApplicationParameters)
{
    app.init_function = parameters.init_function;
    app.update_function = parameters.update_function;
    app.shutdown_function = parameters.shutdown_function;

    app.window = create_window(parameters.width, parameters.height, parameters.name);

    if app.init_function != null then app.init_function();

    #if OS == .WASM
    {
        // Nothing, js will call on_wasm_update
    }
    else
    {
        t := seconds_since_init();
        while !app.stop_requested
        {
            previous_t: = t;
            t = seconds_since_init();
            dt: float32 = xx (t - previous_t);
            application_update(dt);
        }

        if app.shutdown_function != null then app.shutdown_function();
    }
}

application_request_stop :: ()
{
    app.stop_requested = true;
}

#if OS == .WASM
{
    pending_events : [..]Event;

    #scope_export
    on_wasm_update :: (dt: float32) #c_call
    {
        push_context
        {
            application_update(dt);
        }
    }

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

    update_window_events :: ()
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
}

#scope_file

application_update :: (dt: float32)
{
    update_window_events();

    for events_this_frame
    {
        if it.type == .QUIT then application_request_stop();

        if it.type == .KEYBOARD
        {
            if it.key_pressed == 0 continue;

            if it.key_code == .ESCAPE
            {
                application_request_stop();
            }
        }
    }

    if app.update_function != null then app.update_function(dt);
}



#import "Window_Creation";
#import "Input";
#import "Basic";