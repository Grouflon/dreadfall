GROUND_HEIGHT :: 0;

GameSettings :: struct
{
    bird_max_speed: float = 8.0; @drag @step=0.1 @min=0
    bird_acceleration: float = 1.0; @drag @step=0.1 @min=0
    bird_deceleration: float = 1.0; @drag @step=0.1 @min=0

    test_curve: Curve;

    bird_acceleration_curve: Curve;
    bird_deceleration_curve: Curve;

    spline_initialized: bool = false;
    spline: Spline2D;

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

EDITOR_SETTINGS_PATH :: "data/editor_settings.json";
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

    load_editor_settings(EDITOR_SETTINGS_PATH);
    save_editor_settings(EDITOR_SETTINGS_PATH, make_editor_settings());

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

    if ImGui.Begin("settings", flags = .AlwaysVerticalScrollbar)
    {
        if ImGui.EditValue("settings", *game.settings)
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
    spline_editor.settings = settings.spline_editor_settings;
    if spline_editor_update(*spline_editor, mouse_state)
    {
        settings_modified = true;
    }

    if settings_modified
    {
        save_game_settings(GAME_SETTINGS_PATH, *game.settings);
    }

    editor_settings: = make_editor_settings();
    if memcmp(*editor_settings, *last_editor_settings, size_of(EditorSettings)) != 0
    {
        save_editor_settings(EDITOR_SETTINGS_PATH, editor_settings);
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
        p2: = spline_find_closest_position(*settings.spline, mouse_position);
        rl.DrawLineV(mouse_position, p2, rl.RED);
        rl.DrawCircleV(p2, 3.0, rl.RED);

        {
            // segment: [2]Vector2 = .[.{0, 0}, .{125, -30}];
            // rl.DrawLineV(segment[0], segment[1], rl.YELLOW);
            // p3: = find_closest_point_on_segment(mouse_position, segment[0], segment[1]);
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

EditorSettings :: struct
{
    game_window_initialized: bool;
    game_window_x: int;
    game_window_y: int;
    game_window_width: int;
    game_window_height: int;

    console_initialized: bool;
    console_x: int;
    console_y: int;
    console_width: int;
    console_height: int;

    debugger_initialized: bool;
    debugger_x: int;
    debugger_y: int;
    debugger_width: int;
    debugger_height: int;
}

last_editor_settings: EditorSettings;

searched_for_debugger: bool;
debugger_window_handle: *void;
get_debugger_window_handle :: () -> *void
{
    if !searched_for_debugger
    {
        debugger_window_handle = find_window_by_title_containing("RemedyBG");
        searched_for_debugger = true;
    }
    return debugger_window_handle;
}

make_editor_settings :: () -> EditorSettings
{
    settings: EditorSettings;

    {
        position: = rl.GetWindowPosition();
        settings.game_window_x = xx position.x;
        settings.game_window_y = xx position.y;
        settings.game_window_width = rl.GetRenderWidth();
        settings.game_window_height = rl.GetRenderHeight();
        settings.game_window_initialized = true;
    }

    {
        handle: = get_console_window_handle();
        if handle != null
        {
            x, y, w, h: = get_window_position(handle);
            settings.console_x = x;
            settings.console_y = y;
            settings.console_width = w;
            settings.console_height = h;
            settings.console_initialized = true;
        }
    }

    {
        handle: = get_debugger_window_handle();
        if handle != null
        {
            x, y, w, h: = get_window_position(handle);
            settings.debugger_x = x;
            settings.debugger_y = y;
            settings.debugger_width = w;
            settings.debugger_height = h;
            settings.debugger_initialized = true;
        }
    }

    return settings;
}

load_editor_settings :: (path: string)
{
    serializer: JsonSerializer;
    if !json_serializer_open_json_file(*serializer, path) { return; }

    settings: EditorSettings;
    serializer_begin(*serializer, .READ);
    serialize(*serializer, *settings);
    serializer_end(*serializer);

    if settings.game_window_initialized
    {
        rl.SetWindowPosition(xx settings.game_window_x, xx settings.game_window_y);
        rl.SetWindowSize(xx settings.game_window_width, xx settings.game_window_height);
    }

    {
        handle: = get_console_window_handle();
        if settings.console_initialized && handle != null
        {
            set_window_position(handle, settings.console_x, settings.console_y, settings.console_width, settings.console_height);
        }
    }

    {
        handle: = get_debugger_window_handle();
        if settings.debugger_initialized && handle != null
        {
            set_window_position(handle, settings.debugger_x, settings.debugger_y, settings.debugger_width, settings.debugger_height);
        }
    }

    if context.log_level >= .VERBOSE log("Loaded editor settings \"%\".", path, flags = .VERBOSE_ONLY);
}


save_editor_settings :: (path: string, settings: EditorSettings)
{
    serializer: JsonSerializer;

    serializer_begin(*serializer, .WRITE);
    serialize(*serializer, *settings);
    serializer_end(*serializer);

    json_serializer_write_json_file(*serializer, path);

    last_editor_settings = settings;

    if context.log_level >= .VERBOSE log("Saved editor settings \"%\".", path, flags = .VERBOSE_ONLY);
}

load_game_settings :: (path: string, settings: *GameSettings)
{
    serializer: JsonSerializer;
    if !json_serializer_open_json_file(*serializer, path) { return; }

    serializer_begin(*serializer, .READ);
    serialize(*serializer, settings);
    serializer_end(*serializer);

    if context.log_level >= .VERBOSE log("Loaded settings \"%\".", path, flags = .VERBOSE_ONLY);
}

save_game_settings :: (path: string, settings: *GameSettings)
{
    serializer: JsonSerializer;

    serializer_begin(*serializer, .WRITE);
    serialize(*serializer, settings);
    serializer_end(*serializer);

    json_serializer_write_json_file(*serializer, path);

    if context.log_level >= .VERBOSE log("Saved settings \"%\".", path, flags = .VERBOSE_ONLY);
}

#import "File";