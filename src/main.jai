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
    _nested: Nested;
    _array_fixed: [4]s8;
    _array_view: []s8;
    _array_dynamic: [..]s8;
}

Nested :: struct
{
    a: int;
    b: float; 
}

test_serializer :: ()
{
    test: Test;
    test._bool = true;
    test._s8 = -8;
    test._s16 = -16;
    test._s32 = -32;
    test._s64 = -64;
    test._u8 = 8;
    test._u16 = 16;
    test._u32 = 32;
    test._u64 = 64;
    test._int = 42;
    test._float32 = 32.32;
    test._float64 = 64.64;
    test._float = 42.42;
    test._string = "hello";
    test._nested = .{ 12, 45.65 };
    test._array_fixed = .[1, 2, 3, 4];
    test._array_view = .[5, 6];
    array_add(*test._array_dynamic, 12);

    serializer: JsonSerializer;
    serializer_begin(*serializer, .WRITE);
    assert(serialize(*serializer, *test));
    serializer_end(*serializer);

    test2: Test;
    serializer_begin(*serializer, .READ);
    assert(serialize(*serializer, *test2));
    serializer_end(*serializer);

    print("%\n", test2);

    free(test2._string);
    free(test2._array_view.data);
    array_free(test._array_dynamic);
    array_free(test2._array_dynamic);
}

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
