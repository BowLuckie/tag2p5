package tag2p5

import "renderer"
import rl "vendor:raylib"

main :: proc() {
	when ODIN_DEBUG {
		ctx := context
		tracking_allocator_start(&ctx)
		context = ctx
	}

	init_raylib()

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
