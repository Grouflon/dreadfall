#run build();

BUILD_NAME :: "dreadfall";
BUILD_OUTPUT_DIRECTORY :: "bin";

build :: ()
{
    // Read arguments
    args := get_build_options().compile_time_command_line;

    compile := array_find(args, "compile");
    run := array_find(args, "run");
    debug := array_find(args, "debug");

    // Make bin directory
    make_directory_if_it_does_not_exist(BUILD_OUTPUT_DIRECTORY, recursive = true);

    // Copy raylib dll
    copy_file_set_if_newer("modules/raylib/windows", BUILD_OUTPUT_DIRECTORY, "raylib", .["dll", "pdb"]);

    // Compile
    w := compiler_create_workspace(BUILD_NAME);
    
    options := get_build_options();
    options.output_path = BUILD_OUTPUT_DIRECTORY;
    options.output_executable_name = BUILD_NAME;
    options.use_natvis_compatible_types = true;
    if debug
    {
        set_optimization(*options, .DEBUG);
    }
    set_build_options(options, w);
    
    error_count: = 0;
    compiler_begin_intercept(w);
    add_build_file("src/main.jai", w);
    while true
    {
        message: = compiler_wait_for_message();
        if message.kind == {
            case .ERROR; error_count += 1;
            case .COMPLETE;
            {
                mc := cast(*Message_Complete) message;
                if mc.error_code != .NONE 
                {
                    error_count += 1;
                }
                break;
            }
        }
    }
    compiler_end_intercept(w);
    if error_count != 0
    {
        log(tprint("Compilation failed with % error% :@", error_count, ifx error_count > 1 then "s" else ""));
        return;
    }
    log("Compilation completed without error :)");

    // No executable for this workspace.
    set_build_options_dc(.{do_output=false});

    exe_path: = tprint("%/%.exe", BUILD_OUTPUT_DIRECTORY, BUILD_NAME);
    if debug
    {
        cmd: []string = .[
            "remedybg", "-g", "-q",
            tprint("%.rdbg", BUILD_NAME),
        ];
        result, output_string: = run_command(..cmd, capture_and_return_output= true);
        print("\n");
        log(output_string);
    }
    else if run
    {
        result, output_string: = run_command(exe_path, capture_and_return_output= true);
        print("\n");
        log(output_string);
    }
}

#import "Basic";
#import "File";
#import "File_Utilities";
#import "Compiler";
#import "Process";
#import "yae";