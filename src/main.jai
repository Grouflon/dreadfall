// Build Parameters
DEBUG_MEMORY :: true;

Test :: struct
{
    _bool: bool;
    _s8: s8;
    _s16: s16;
    _s32: s32;
    _s64: s64;
    _u8: u8;
    _u16: u16;
    _u32: u32;
    _u64: u64;
    _int: int;
    _float32: float32;
    _float64: float64;
    _float: float;
    _string: string;
}

test_serializer :: ()
{
    test: = Test.{
        true,
        1,2,3,4,
        5,6,7,8,
        9,
        43.2,53.3,
        67.1515,
        "hello"
    };

    serializer: JsonSerializer;
    serializer_begin(*serializer, .WRITE);
    assert(serialize(*serializer, *test));
    serializer_end(*serializer);

    test2: Test;
    serializer_begin(*serializer, .READ);
    assert(serialize(*serializer, *test2));
    serializer_end(*serializer);

    print("%\n", test2);
}

// Globals
game: Game;

main :: ()
{
    test_serializer();

    // normalize working directory
    {
        exe_directory: = path_strip_filename(get_path_of_running_executable());
        root_directory: = tprint("%/..", exe_directory);
        set_working_directory(root_directory);
    }

    game_run(*game);

    #if DEBUG_MEMORY
    {
        report: = make_leak_report();
        if report.sorted_summaries.count
        {
            log_error("\n=========\nMemory Leak!!\n=========");
            log_leak_report(report);
            assert(false);
        }
    }
}

// Loads
#load "game.jai";
#load "bird.jai";

// Global imports
#import "Basic"()(MEMORY_DEBUGGER = DEBUG_MEMORY);
#import "yae";
#import "Math";
#import "Hash_Table";

rl :: #import "raylib";
ImGui :: #import "ImGui";

#scope_file
// Local imports
#import "String";
#import "System";
