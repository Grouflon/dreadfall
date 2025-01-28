// API

DEFAULT_WINDOW_CREATION_COLOR :: Color.{38,38,51,255};

// create_window :: (width: int, height: int, window_name: string, background_color: Color = DEFAULT_WINDOW_CREATION_COLOR) -> *void;
// update_input_events :: ();
// init_opengl_context :: (window: *void);
// swap_buffers :: (window: *void);

TextureData :: struct
{
    data: *u8;
    width: u32;
    height: u32;
    channels: u32;
}
// load_texture_data :: (filename: string, allocator: *Allocator) -> TextureData;

#if OS == .WINDOWS
{
    #load "backend_windows.jai";
}
#if OS == .WASM
{
    #load "backend_wasm.jai";
}