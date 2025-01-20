#if OS == .WASM
{
    Window_Type :: *void;
    INVALID_WINDOW : Window_Type : null;
}
else
{
    #load "../../../jai/modules/Window_Type.jai";
}

