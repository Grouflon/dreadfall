// API

DEFAULT_WINDOW_CREATION_COLOR :: Color.{38,38,51,255};

// create_window :: (width: int, height: int, window_name: string, background_color: Color = DEFAULT_WINDOW_CREATION_COLOR) -> *void;
// update_input_events :: ();
// init_opengl_context :: (window: *void);
// swap_buffers :: (window: *void);

#if OS == .WINDOWS
{
    #load "backend_windows.jai";
}
#if OS == .WASM
{
    #load "backend_wasm.jai";
}