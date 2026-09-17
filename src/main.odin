package tag2p5

import "base:runtime"
import clay "clay-odin"
import "core:fmt"
import "core:mem"
import "renderer"
import rl "vendor:raylib"

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		defer mem.tracking_allocator_destroy(&track)

		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) == 0 {
				fmt.println("tracking allocator: no leaks")
			}

			fmt.printf("tracking allocator: %d live allocation(s):\n", len(track.allocation_map))

			for _, leak in track.allocation_map {
				fmt.printf("leaked %v %m\n", leak.location, leak.size)
			}
		}
	}

	rl.SetConfigFlags({.WINDOW_RESIZABLE, .WINDOW_TOPMOST, .FULLSCREEN_MODE})
	rl.SetTraceLogLevel(.WARNING)
	rl.InitWindow(GAME_WIDTH, GAME_HEIGHT, "Tag 2.5")
	rl.SetExitKey(.SLASH)
	// rl.SetExitKey(.KEY_NULL)
	rl.SetWindowMinSize(GAME_WIDTH * 0.1, GAME_HEIGHT * 0.1)
	rl.SetTargetFPS(60)
	rl.HideCursor()

	append(
		&renderer.raylib_fonts,
		renderer.Raylib_Font {
			fontId = u16(Fonts.TheOneFont),
			font = rl.LoadFontEx("./assets/PeaberryBase.ttf", 96, nil, 0),
		},
	)

	clay_arena := create_clay_arena()
	game: Game = new_game()

	defer {
		free_game(&game)
		rl.CloseWindow()
		delete(clay_arena.memory[:clay_arena.capacity])
		delete(renderer.raylib_fonts)
	}

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		// update
		update_clay(dt)
		update_game(&game, dt)
		handle_keypresses(&game)

		// render
		ui_commands := build_ui(&game, dt)
		render_game(&game, mouse_pos(), game.target, ui_commands)
		draw_screen(game.target)

		if game.suicidal {
			break
		}
	}
}
