GROUND_HEIGHT :: 0;

GameSettings :: struct
{
    bird_max_speed: float = 8.0; @drag @step=0.1 @min=0
    bird_acceleration: float = 1.0; @drag @step=0.1 @min=0
    bird_deceleration: float = 1.0; @drag @step=0.1 @min=0
}

Game :: struct
{
    bird: Bird;

    settings: GameSettings;

    viewport: PixelPerfectViewport;
}

// Globals
game: Game;

settings :: () -> *GameSettings
{
    return *game.settings;
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

GAME_SETTINGS_PATH :: "data/settings.json";

game_initialize :: (using game: *Game)
{
    window_flags: rl.ConfigFlags;
    window_flags |= .FLAG_WINDOW_RESIZABLE;

    rl.InitWindow(1600, 900, "Game");
    rl.SetWindowState(xx window_flags);
    rl.SetTargetFPS(60);
    rl.SetExitKey(.KEY_NULL);

    viewport = .{
        min_render_width = 512,
        min_render_height = 256,
        min_pixel_ratio = 2,
        max_pixel_ratio = 3,
    };

    load_game_settings(GAME_SETTINGS_PATH, *game.settings);
    save_game_settings(GAME_SETTINGS_PATH, *game.settings);

    raylib_imgui_init(.{
        theme = ImGuiTheme.DARK,
        font_file = "data/fonts/monoOne.otf",
        font_size = 17,
    });

    bird_init(*bird);
}

game_shutdown :: (using game: *Game)
{
    bird_shutdown(*bird);

    raylib_imgui_shutdown();

    rl.CloseWindow();
}

game_should_exit :: (using game: *Game) -> bool
{
    return rl.WindowShouldClose();
}

game_update :: (using game: *Game, dt: float)
{
    if ImGui.Begin("settings")
    {
        if imgui_edit("settings", *game.settings)
        {
            save_game_settings(GAME_SETTINGS_PATH, *game.settings);
        }
    }
    ImGui.End();

    viewport_update(*game.viewport);

    bird_update(*bird);
    // ImGui.ShowDemoWindow();
}

game_draw :: (using game: *Game)
{
    background_color: = rl.LIGHTGRAY;

    {
        viewport.camera.target = .{ 0.0, 70.0 };
        viewport_begin_render(viewport);
        defer viewport_end_render(viewport);

        rl.ClearBackground(background_color);

        rl.DrawRectangleV(.{-1000, GROUND_HEIGHT - 500}, .{2000, 500}, rl.DARKGRAY);
        bird_draw(*bird);

        GIZMO_SIZE :: 20.0;
        rl.DrawLineEx(.{}, .{ 1.0, 0.0 } * GIZMO_SIZE, 2, rl.RED);
        rl.DrawLineEx(.{}, .{ 0.0, 1.0 } * GIZMO_SIZE, 2, rl.GREEN);
    }

    {
        rl.BeginDrawing();
        defer rl.EndDrawing();

        render_camera: = rl.Camera2D.{ zoom = 1.0 };
        rl.BeginMode2D(render_camera);
        defer rl.EndMode2D();

        viewport_draw(viewport);

        rl.DrawFPS(rl.GetScreenWidth() - 90, 10);
        raylib_imgui_render();
    }
}

load_game_settings :: (path: string, settings: *GameSettings)
{
    serializer: JsonSerializer;
    if !json_serializer_open_json_file(*serializer, path) { return; }

    serializer_begin(*serializer, .READ);
    serialize(*serializer, settings);
    serializer_end(*serializer);

    log("Loaded settings \"%\".", path);
}

save_game_settings :: (path: string, settings: *GameSettings)
{
    serializer: JsonSerializer;

    serializer_begin(*serializer, .WRITE);
    serialize(*serializer, settings);
    serializer_end(*serializer);

    json_serializer_write_json_file(*serializer, path);

    log("Saved settings \"%\".", path);
}

#import "File";