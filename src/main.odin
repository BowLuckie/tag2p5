package tag2p5

import "core:fmt"
import "core:mem"
import rl "vendor:raylib"

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	context.allocator = mem.tracking_allocator(&track)
	defer {
		if len(track.allocation_map) != 0 {
			fmt.printf("tracking allocator: %d live allocation(s):\n", len(track.allocation_map))
			for _, leak in track.allocation_map {
				fmt.printf("%v leaked %m\n", leak.location, leak.size)
			}
		} else {
			fmt.println("tracking allocator: no leaks")
		}
	}

	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT, .FULLSCREEN_MODE})
	rl.InitWindow(GAME_WIDTH, GAME_HEIGHT, "Tag 2.5")
	game := create_test_game()

	rl.SetTargetFPS(60)

	target := rl.LoadRenderTexture(GAME_WIDTH, GAME_HEIGHT)


	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		update_game(&game, dt)
		render_game(&game, target)

		draw_screen(target)
	}

	free_game(&game)
	rl.UnloadRenderTexture(target)
	rl.CloseWindow()
}
