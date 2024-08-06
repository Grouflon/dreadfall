// Build Parameters
DEBUG_MEMORY :: true;

// Globals
game: Game;

main :: ()
{
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

// Global imports
#import "Basic"()(MEMORY_DEBUGGER = DEBUG_MEMORY);
#import "yae";
rl :: #import "raylib";
ImGui :: #import "ImGui";

#scope_file
// Local imports
#import "String";
#import "System";
