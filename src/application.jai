InitFunction :: #type ();
UpdateFunction :: #type (dt: float32);
ShutdownFunction :: #type ();

Application :: struct
{
    window: *void;
    stop_requested: bool;

    init_function: InitFunction;
    update_function: UpdateFunction;
    shutdown_function: ShutdownFunction;
}

ApplicationParameters :: struct
{
    width: int;
    height: int;
    name: string;

    init_function: InitFunction;
    update_function: UpdateFunction;
    shutdown_function: ShutdownFunction;
}

app: Application;

VERTICES: []Vector3 = .[
    .{-0.5, -0.5, 0.0 },
    .{ 0.5, -0.5, 0.0 },
    .{ 0.0,  0.5, 0.0 },
];
VERTEX_SHADER_SRC :: #string END
#version 300 es
precision mediump float;
layout (location = 0) in vec3 aPos;

void main()
{
    gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
}
END
FRAGMENT_SHADER_SRC :: #string END
#version 300 es
precision mediump float;
out vec4 FragColor;

void main()
{
    FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
}
END

vao: GLuint;
vbo: GLuint;
shader_program: GLuint;

application_start :: (parameters: ApplicationParameters)
{
    app.init_function = parameters.init_function;
    app.update_function = parameters.update_function;
    app.shutdown_function = parameters.shutdown_function;

    app.window = create_window(parameters.width, parameters.height, parameters.name);
    init_opengl_context(app.window);

    gl_version: = glGetString(GL_VERSION);
    log(tprint("Initialized OpenGL %", to_string(gl_version)));

    glGenVertexArrays(1, *vao);
    log("%", vao);
    glGenBuffers(1, *vbo);
    log("%", vbo);

    glBindVertexArray(vao);

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, VERTICES.count * size_of(Vector3), VERTICES.data, GL_STATIC_DRAW);

    // glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * size_of(float), null);
    // glEnableVertexAttribArray(0);

    // compile_shader :: (shader: GLuint, src: *u8, src_length: s32)
    // {
    //     glShaderSource(shader, 1, *src, *src_length);
    //     glCompileShader(shader);
    //     success: GLint;
    //     glGetShaderiv(shader, GL_COMPILE_STATUS, *success);
    //     if (!success)
    //     {
    //         info_log: [512]u8;
    //         size: GLsizei;
    //         glGetShaderInfoLog(shader, 512, *size, info_log.data);
    //         info: = string.{ size, info_log.data };
    //         log(tprint("Shader Compilation Failed: %", info));
    //     }
    // }

    // vertex_shader: = glCreateShader(GL_VERTEX_SHADER);
    // compile_shader(vertex_shader, VERTEX_SHADER_SRC.data, xx VERTEX_SHADER_SRC.count);

    // fragment_shader: = glCreateShader(GL_FRAGMENT_SHADER);
    // compile_shader(fragment_shader, FRAGMENT_SHADER_SRC.data, xx FRAGMENT_SHADER_SRC.count);

    // shader_program = glCreateProgram();
    // glAttachShader(shader_program, vertex_shader);
    // glAttachShader(shader_program, fragment_shader);
    // glLinkProgram(shader_program);

    // success: GLint;
    // glGetProgramiv(shader_program, GL_LINK_STATUS, *success);
    // if (!success)
    // {
    //     info_log: [512]u8;
    //     size: GLsizei;
    //     glGetProgramInfoLog(shader_program, 512, *size, info_log.data);
    //     info: = string.{ size, info_log.data };
    //     log(tprint("Program Link Failed: %", info));
    // }

    // glDeleteShader(vertex_shader);
    // glDeleteShader(fragment_shader); 

    if app.init_function != null then app.init_function();

    #if OS == .WASM
    {
        // Nothing, js will call on_wasm_update
    }
    else
    {
        t := seconds_since_init();
        while !app.stop_requested
        {
            previous_t: = t;
            t = seconds_since_init();
            dt: float32 = xx (t - previous_t);

            application_update(dt);
        }

        if app.shutdown_function != null then app.shutdown_function();
    }
}

application_request_stop :: ()
{
    app.stop_requested = true;
}

#if OS == .WASM
{
    on_wasm_update :: (dt: float32) #c_call
    {
        push_context
        {
            application_update(dt);
        }
    }
}

#scope_file

application_update :: (dt: float32)
{
    update_input_events();

    for events_this_frame
    {
        if it.type == .QUIT then application_request_stop();

        if it.type == .KEYBOARD
        {
            if it.key_pressed == 0 continue;

            if it.key_code == .ESCAPE
            {
                application_request_stop();
            }
        }
    }

    if app.update_function != null then app.update_function(dt);

    glClearColor(0.0, 1.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);

    // glUseProgram(shader_program);
    // glBindVertexArray(vao);
    // glDrawArrays(GL_TRIANGLES, 0, 3);

    swap_buffers(app.window);
}

#import "Input";
#import "Basic";
#import "GL";
#import "Math";
