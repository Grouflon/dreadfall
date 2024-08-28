Bird :: struct
{
    position: Vector2;
    speed: float;
    player: AnimationPlayer;
    last_direction: float;
}

bird_init :: (using bird: *Bird)
{
    position = .{0, GROUND_HEIGHT};
    animation_player_play(*player, game.bird_run);
}

bird_update :: (using bird: *Bird)
{
    direction: = 0.0; 
    if rl.IsKeyDown(.KEY_LEFT) direction -= 1.0;
    if rl.IsKeyDown(.KEY_RIGHT) direction += 1.0;

    previous_speed: = speed;
    if direction == 0 || sign(direction) != sign(speed)
    {
        speed += -sign(speed) * settings().bird_deceleration;
        if direction == 0 && sign(previous_speed) != sign(speed)
        {
            speed = 0.0;
        }
    }
    if direction != 0
    {
        speed += sign(direction) * settings().bird_acceleration;
    }
    speed = sign(speed) * min(abs(speed), settings().bird_max_speed);
    position.x += speed;

    if speed == 0.0
    {
        animation_player_play(*player, game.bird_idle);
    }
    else
    {
        last_direction = sign(speed);
        animation_player_play(*player, game.bird_run);
    }

    animation_player_update(*player, 0.03);
}

bird_draw :: (using bird: *Bird)
{
    draw_position: = position - .{32, 16};
    flip: = last_direction < 0.0;
    animation_player_draw(*player, draw_position, flip);
    // rl.DrawCircleV(position, 2.0, rl.RED);
}