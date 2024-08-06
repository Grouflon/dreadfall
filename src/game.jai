Game :: struct
{

}

game_run :: (using game: *Game)
{
    game_initialize(game);
    defer game_shutdown(game);

    while !game_should_exit(game)
    {        
        reset_temporary_storage();

        dt: = rl.GetFrameTime();

        raylib_imgui_new_frame(dt);

        game_update(game, dt);
        game_draw(game);
    }
}

#scope_file

game_initialize :: (using game: *Game)
{
    window_flags: rl.ConfigFlags;
    window_flags |= .FLAG_WINDOW_RESIZABLE;

    rl.InitWindow(1600, 900, "Game");
    rl.SetWindowState(xx window_flags);
    rl.SetTargetFPS(60);
    rl.SetExitKey(.KEY_NULL);

    raylib_imgui_init(.{
        theme = ImGuiTheme.DARK,
        font_file = "data/fonts/monoOne.otf",
        font_size = 17,
    });
}

game_shutdown :: (using game: *Game)
{
    raylib_imgui_shutdown();

    rl.CloseWindow();
}

game_should_exit :: (using game: *Game) -> bool
{
    return rl.WindowShouldClose();
}

game_update :: (using game: *Game, dt: float)
{
    ImGui.ShowDemoWindow();
}

game_draw :: (using game: *Game)
{
    rl.BeginDrawing();
    defer rl.EndDrawing();

    rl.ClearBackground(rl.LIGHTGRAY);

    raylib_imgui_render();

    rl.DrawFPS(rl.GetScreenWidth() - 90, 10);     
}
