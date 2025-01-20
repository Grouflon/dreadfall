#if OS == .WASM
{
    WT :: #import "Window_Type";
    Window_Type :: WT.Window_Type;

    DEFAULT_MSAA : s32 : 4;
    DEFAULT_WINDOW_CREATION_COLOR :: float.[.15,.15,.2];

    create_window :: (width: int, height: int, window_name: string, window_x := -1, window_y := -1, parent: Window_Type = null, background_color_rgb := DEFAULT_WINDOW_CREATION_COLOR, wanted_msaa := DEFAULT_MSAA) -> Window_Type
    {
        return wasm_create_window(width, height, temp_c_string(window_name), *background_color_rgb, wanted_msaa);
    }

    #scope_file
    wasm_create_window :: (width: int, height: int, window_name: *u8, background_color: *[3]float32, wanted_msaa :int) -> Window_Type #foreign;

    #import "Basic";

    
}
else
{
    #load "../../../jai/modules/Window_Creation/module.jai";
}



