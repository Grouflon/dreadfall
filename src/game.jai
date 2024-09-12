GROUND_HEIGHT :: 0;

GameSettings :: struct
{
    bird_max_speed: float = 8.0; @drag @step=0.1 @min=0
    bird_acceleration: float = 1.0; @drag @step=0.1 @min=0
    bird_deceleration: float = 1.0; @drag @step=0.1 @min=0

    spline_initialized: bool = false;
    spline: Spline2D;
    iterations: int = 1; @drag @min=1

    spline_editor_settings: SplineEditorSettings;
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

spline_editor: SplineEditor;
time: float;

game_initialize :: (using game: *Game)
{
    spline_editor.spline = *settings.spline;

    window_flags: rl.ConfigFlags;
    window_flags |= .FLAG_WINDOW_RESIZABLE;

    rl.InitWindow(1600, 900, "Game");
    rl.SetWindowState(xx window_flags);
    rl.SetTargetFPS(60);
    rl.SetExitKey(.KEY_NULL);

    resource_manager_init();

    viewport = .{
        min_render_width = 512,
        min_render_height = 256,
        min_pixel_ratio = 2,
        max_pixel_ratio = 3,
    };

    load_game_settings(GAME_SETTINGS_PATH, *game.settings);
    if !settings.spline_initialized
    {
        spline_add_point(*settings.spline, .{0, 0}, .{0, 100});
        spline_add_point(*settings.spline, .{200, 200}, .{300, 300});
        settings.spline.is_looping = true;
        settings.spline_initialized = true;
    }

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

    resource_manager_shutdown();

    rl.CloseWindow();
}

game_should_exit :: (using game: *Game) -> bool
{
    return rl.WindowShouldClose();
}

game_update :: (using game: *Game, dt: float)
{
    time += dt;
    resource_manager_update();
    settings_modified: = false;

    if ImGui.Begin("settings")
    {
        if imgui_edit("settings", *game.settings)
        {
            settings_modified = true;
        }
    }
    ImGui.End();

    viewport_update(*game.viewport);

    bird_update(*bird);

    mouse_state: = MouseState.{
        position = screen_to_world_position(*viewport, rl.GetMousePosition()),
        left_button_down = rl.IsMouseButtonDown(0),
        right_button_down = rl.IsMouseButtonDown(1),
    };
    ImGui.Text(tprint("%", mouse_state.position));
    spline_editor.settings = settings.spline_editor_settings;
    if spline_editor_update(*spline_editor, mouse_state)
    {
        settings_modified = true;
    }

    if settings_modified
    {
        save_game_settings(GAME_SETTINGS_PATH, *game.settings);
    }
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

        spline_editor_draw(*spline_editor);

        p: = spline_sample_position(*settings.spline, positive_mod(time / 5.0, 1.0));
        rl.DrawCircleV(p, 4.0, rl.GREEN);

        mouse_position: = screen_to_world_position(*viewport, rl.GetMousePosition());
        // points: [4]Vector2;
        // points[0] = spline.points[0].point;
        // points[1] = spline.points[0].forward_tangent;
        // points[2] = spline.points[1].backward_tangent;
        // points[3] = spline.points[1].point;
        // p2: = approximate_closest_point_on_bezier_curve(mouse_position, points, settings.iterations);
        p2: = spline_find_closest_position(*settings.spline, mouse_position);
        rl.DrawLineV(mouse_position, p2, rl.RED);
        rl.DrawCircleV(p2, 3.0, rl.RED);

        {
            segment: [2]Vector2 = .[.{0, 0}, .{125, -30}];
            // rl.DrawLineV(segment[0], segment[1], rl.YELLOW);
            p3: = find_closest_point_on_segment(mouse_position, segment[0], segment[1]);
            // rl.DrawCircleV(p3, 3.0, rl.BLUE);
        }
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