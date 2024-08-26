GROUND_HEIGHT :: 400;

GameSettings :: struct
{
    bird_max_speed: float = 8.0;
}

Game :: struct
{
    bird_data: *AsepriteData;
    bird_texture: rl.Texture2D;

    bird: Bird;

    bird_idle: Animation;
    bird_run: Animation;

    settings: GameSettings;
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

    load_game_settings(GAME_SETTINGS_PATH, *game.settings);
    save_game_settings(GAME_SETTINGS_PATH, *game.settings);

    raylib_imgui_init(.{
        theme = ImGuiTheme.DARK,
        font_file = "data/fonts/monoOne.otf",
        font_size = 17,
    });

    bird_data = aseprite_load_data("data/sprites/bird.json");
    bird_texture = rl.LoadTexture(temp_c_string(bird_data.image_path));

    found: bool;
    bird_idle.data = bird_data;
    bird_idle.texture = bird_texture;
    bird_idle.index, found = table_find(*bird_data.name_to_tag, "idle");
    if !found bird_idle.index = -1;

    bird_run.data = bird_data;
    bird_run.texture = bird_texture;
    bird_run.index, found = table_find(*bird_data.name_to_tag, "run");
    if !found bird_run.index = -1;

    bird_init(*bird);
}

game_shutdown :: (using game: *Game)
{
    aseprite_release_data(bird_data);
    rl.UnloadTexture(bird_texture);

    raylib_imgui_shutdown();

    rl.CloseWindow();
}

game_should_exit :: (using game: *Game) -> bool
{
    return rl.WindowShouldClose();
}

game_update :: (using game: *Game, dt: float)
{
    bird_update(*bird);
    // ImGui.ShowDemoWindow();
}

game_draw :: (using game: *Game)
{
    rl.BeginDrawing();
    defer rl.EndDrawing();

    rl.ClearBackground(rl.LIGHTGRAY);

    {
        game_camera: = rl.Camera2D.{ zoom = 2 };
        rl.BeginMode2D(game_camera);
        defer rl.EndMode2D();

        rl.DrawRectangleV(.{0, GROUND_HEIGHT}, .{5000, 500}, rl.DARKGRAY);
        bird_draw(*bird);
    }

    raylib_imgui_render();

    rl.DrawFPS(rl.GetScreenWidth() - 90, 10);     
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