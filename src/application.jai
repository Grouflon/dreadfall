InitFunction :: #type ();
UpdateFunction :: #type (dt: float32);
ShutdownFunction :: #type ();

Application :: struct
{
    window: *void;
    stop_requested: bool;

    // TODO: should request from window instead of storing in the struct
    width: int;
    height: int;

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

Vertex :: struct
{
    position: Vector3;
    uv: Vector2;
    color: Vector4;
}

VERTICES: []Vertex = .[
    .{.{-0.5, -0.5, 0.0 }, .{0.0, 0.0}, .{1.0, 0.0, 0.0, 1.0} },
    .{.{ 0.5, -0.5, 0.0 }, .{0.0, 1.0}, .{0.0, 1.0, 0.0, 1.0} },
    .{.{ 0.0,  0.5, 0.0 }, .{1.0, 1.0}, .{0.0, 0.0, 1.0, 1.0} },
];
VERTEX_SHADER_SRC :: #string END
#version 300 es
precision mediump float;

layout (location = 0) in vec3 inPosition;
layout (location = 1) in vec2 inTexCoord;
layout (location = 2) in vec4 inColor;

out vec2 fragTexCoord;
out vec4 fragColor;

uniform sampler2D uTexture;

void main()
{
    gl_Position = vec4(inPosition.x, inPosition.y, inPosition.z, 1.0);
    fragTexCoord = inTexCoord;
    fragColor = inColor;
}
END
FRAGMENT_SHADER_SRC :: #string END
#version 300 es
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 outColor;

uniform sampler2D uTexture;

void main()
{
    vec4 pixel = texture(uTexture, fragTexCoord);
    outColor = pixel * fragColor;
    // outColor = vec4(fragTexCoord.x, fragTexCoord.y, 0, 1);
}
END

vao: GLuint;
vbo: GLuint;
shader_program: GLuint;
texture: GLuint;

texture_path: = "data/sprites/oro_avatar.png";

GL_VERIFY :: (c: Code) #expand #no_debug
{
    #insert c;
    #if OS != .WASM
    {
        DumpGLErrors("app");
    }
}

application_start :: (parameters: ApplicationParameters)
{
    app.width = parameters.width;
    app.height = parameters.height;

    app.init_function = parameters.init_function;
    app.update_function = parameters.update_function;
    app.shutdown_function = parameters.shutdown_function;

    app.window = create_window(parameters.width, parameters.height, parameters.name);

    #if OS == .WASM
    {
        wasm_preload(texture_path);
    }
    else
    {
        application_init();

        t := seconds_since_init();
        while !app.stop_requested
        {
            previous_t: = t;
            t = seconds_since_init();
            dt: float32 = xx (t - previous_t);

            application_update(dt);
        }

        application_shutdown();
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

    on_wasm_preload_end :: () #c_call
    {
        push_context
        {
            application_init();
        }
    }
}

#scope_file

application_init :: ()
{
    init_opengl_context(app.window);
    #if OS != .WASM
    {
        gl_enable_debug_output(true);
    }

    gl_version: = glGetString(GL_VERSION);
    log(tprint("Initialized OpenGL %", to_string(gl_version)));

    GL_VERIFY(glViewport(0, 0, xx app.width, xx app.height));
    GL_VERIFY(glScissor(0, 0, xx app.width, xx app.height));

    GL_VERIFY(glGenVertexArrays(1, *vao));
    GL_VERIFY(glGenBuffers(1, *vbo));

    GL_VERIFY(glBindVertexArray(vao));

    GL_VERIFY(glBindBuffer(GL_ARRAY_BUFFER, vbo));
    GL_VERIFY(glBufferData(GL_ARRAY_BUFFER, VERTICES.count * size_of(Vertex), VERTICES.data, GL_STATIC_DRAW));

    GL_VERIFY(glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), xx 0));
    GL_VERIFY(glVertexAttribPointer(1, 2, GL_FLOAT, GL_TRUE, size_of(Vertex), xx size_of(Vector3)));
    GL_VERIFY(glVertexAttribPointer(2, 4, GL_FLOAT, GL_TRUE, size_of(Vertex), xx (size_of(Vector3) + size_of(Vector2))));
    GL_VERIFY(glEnableVertexAttribArray(0));
    GL_VERIFY(glEnableVertexAttribArray(1));
    GL_VERIFY(glEnableVertexAttribArray(2));

    compile_shader :: (shader: GLuint, src: *u8, src_length: s32)
    {
        GL_VERIFY(glShaderSource(shader, 1, *src, *src_length));
        GL_VERIFY(glCompileShader(shader));
        success: GLint;
        GL_VERIFY(glGetShaderiv(shader, GL_COMPILE_STATUS, *success));
        if (!success)
        {
            info_log: [512]u8;
            size: GLsizei;
            GL_VERIFY(glGetShaderInfoLog(shader, 512, *size, info_log.data));
            info: = string.{ size, info_log.data };
            log(tprint("Shader Compilation Failed: %", info));
        }
    }

    vertex_shader: = glCreateShader(GL_VERTEX_SHADER);
    compile_shader(vertex_shader, VERTEX_SHADER_SRC.data, xx VERTEX_SHADER_SRC.count);

    fragment_shader: = glCreateShader(GL_FRAGMENT_SHADER);
    compile_shader(fragment_shader, FRAGMENT_SHADER_SRC.data, xx FRAGMENT_SHADER_SRC.count);

    shader_program = glCreateProgram();
    GL_VERIFY(glAttachShader(shader_program, vertex_shader));
    GL_VERIFY(glAttachShader(shader_program, fragment_shader));
    GL_VERIFY(glLinkProgram(shader_program));

    success: GLint;
    GL_VERIFY(glGetProgramiv(shader_program, GL_LINK_STATUS, *success));
    if (!success)
    {
        info_log: [512]u8;
        size: GLsizei;
        GL_VERIFY(glGetProgramInfoLog(shader_program, 512, *size, info_log.data));
        info: = string.{ size, info_log.data };
        log(tprint("Program Link Failed: %", info));
    }

    GL_VERIFY(glDeleteShader(vertex_shader));
    GL_VERIFY(glDeleteShader(fragment_shader));

    GL_VERIFY(glUseProgram(shader_program));

    texture_data: = load_texture_data(texture_path, *temporary_allocator);
    if texture_data.data != null
    {
        GL_VERIFY(glActiveTexture(GL_TEXTURE0));
        GL_VERIFY(glGenTextures(1, *texture));
        GL_VERIFY(glBindTexture(GL_TEXTURE_2D, texture));
        GL_VERIFY(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR));
        GL_VERIFY(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST));
        GL_VERIFY(glTexImage2D(
            GL_TEXTURE_2D,    // target
            0,                // level
            GL_RGBA8,         // internal format
            texture_data.width,           // width
            texture_data.height,          // height
            0,                // border, must be 0
            GL_RGBA,          // format
            GL_UNSIGNED_BYTE, // type
            texture_data.data
        ));
    }
    else
    {
        log("failed to load texture %", texture_path);
    }

    texture_location: = glGetUniformLocation(shader_program, "uTexture");
    GL_VERIFY(glUniform1i(texture_location, 0));

    if app.init_function != null then app.init_function();
}

application_update :: (dt: float32)
{
    reset_temporary_storage();

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

    GL_VERIFY(glClearColor(0.0, 1.0, 0.0, 1.0));
    GL_VERIFY(glClear(GL_COLOR_BUFFER_BIT));

    GL_VERIFY(glBindVertexArray(vao));
    GL_VERIFY(glDrawArrays(GL_TRIANGLES, 0, 3));

    swap_buffers(app.window);
}

application_shutdown :: ()
{
    if app.shutdown_function != null then app.shutdown_function();
}

#import "Input";
#import "Basic";
#import "GL"(DUMP_GL_ERRORS = true);
#import "Math";
