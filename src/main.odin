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
	game := new_game()

	music_player := new_mplayer()

	defer {
		free_game(&game)
		rl.CloseWindow()
		delete(clay_arena.memory[:clay_arena.capacity])
		delete(renderer.raylib_fonts)
		free_mplayer(music_player)
	}

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		update_clay(dt)
		handle_keypresses(&game)
		update_game(&game, dt)

		ui_commands := build_ui(&game, dt)
		render_game(&game, mouse_pos(), game.target, ui_commands)
		draw_screen(game.target)

		update_music(&music_player, dt)

		if game.suicidal {
			break
		}

		if game.pending_restart_idx >= 0 {
			restart_game(&game)
		}
	}
}
