Bird :: struct
{
    position: Vector2;
    player: AnimationPlayer;
    last_direction: float;
}

bird_init :: (using bird: *Bird)
{
    position = .{100, GROUND_HEIGHT};
    animation_player_play(*player, game.bird_run);
}

bird_update :: (using bird: *Bird)
{
    speed :: 8.0;
    direction: = 0.0; 
    if rl.IsKeyDown(.KEY_LEFT) direction -= 1.0;
    if rl.IsKeyDown(.KEY_RIGHT) direction += 1.0;

    if direction == 0.0
    {
        animation_player_play(*player, game.bird_idle);
    }
    else
    {
        last_direction = direction;
        animation_player_play(*player, game.bird_run);
    }
    position.x += direction * speed;

    animation_player_update(*player, 0.03);
}

bird_draw :: (using bird: *Bird)
{
    draw_position: = position - .{32, 49};
    flip: = last_direction < 0.0;
    animation_player_draw(*player, draw_position, flip);
    // rl.DrawCircleV(position, 2.0, rl.RED);
}