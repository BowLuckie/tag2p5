package tag2p5

import "base:runtime"
import clay "clay-odin"
import "core:fmt"
import "core:mem"
import rl "vendor:raylib"

clay_error_handler :: proc "c" (errorData: clay.ErrorData) {
	context = runtime.default_context()
	fmt.printf("clay error: %d\n", errorData.errorType)
}

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		defer mem.tracking_allocator_destroy(&track)
		context.allocator = mem.tracking_allocator(&track)
		defer {
			if len(track.allocation_map) != 0 {
				fmt.printf(
					"tracking allocator: %d live allocation(s):\n",
					len(track.allocation_map),
				)
				for _, leak in track.allocation_map {
					fmt.printf("leaked %v %m\n", leak.location, leak.size)
				}
			} else {
				fmt.println("tracking allocator: no leaks")
			}
		}
	}

	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(GAME_WIDTH, GAME_HEIGHT, "Tag 2.5")
	rl.SetTargetFPS(60)

	min_memory_size := clay.MinMemorySize()
	game_memory := make([]u8, min_memory_size)
	clay_arena := clay.CreateArenaWithCapacityAndMemory(
		uint(min_memory_size),
		raw_data(game_memory),
	)
	clay.Initialize(clay_arena, {GAME_WIDTH, GAME_HEIGHT}, {handler = clay_error_handler})
	clay.SetMeasureTextFunction(measure_text, nil)

	game := create_test_game()
	game.clay_memory = game_memory

	target := rl.LoadRenderTexture(GAME_WIDTH, GAME_HEIGHT)
	defer {
		free_game(&game)
		rl.UnloadRenderTexture(target)
		rl.CloseWindow()
	}


	for !rl.WindowShouldClose() {
		if rl.GetScreenWidth() < GAME_WIDTH / 2 || rl.GetScreenHeight() < GAME_HEIGHT / 2 {
			rl.SetWindowSize(
				max(rl.GetScreenWidth(), GAME_WIDTH / 2),
				max(rl.GetScreenHeight(), GAME_HEIGHT / 2),
			)
		}

		dt := rl.GetFrameTime()

		// Feed input to Clay
		clay.SetLayoutDimensions({cast(f32)rl.GetScreenWidth(), cast(f32)rl.GetScreenHeight()})
		clay.SetPointerState(
			transmute(clay.Vector2)rl.GetMousePosition(),
			rl.IsMouseButtonDown(.LEFT),
		)
		clay.UpdateScrollContainers(false, transmute(clay.Vector2)rl.GetMouseWheelMoveV(), dt)

		update_game(&game, dt)
		render_game(&game, target)

		draw_screen(target)
	}
}
