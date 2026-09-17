package tag2p5

import rl "vendor:raylib"

handle_keypresses :: proc(game: ^Game) {
	if rl.IsKeyPressed(.ESCAPE) {
		on_esc(game)
	} else if rl.IsKeyPressed(.ENTER) {
		on_enter(game)
	}
}

@(private = "file")
on_esc :: proc(game: ^Game) {
	switch game.play_state {
	case .MainMenu:
		game.suicidal = true

	case .MapSel:
		game.play_state = .MainMenu

	case .Playing:
		game.play_state = .Paused

	case .Paused, .GameOver:
		game.play_state = .MainMenu
	}
}

@(private = "file")
on_enter :: proc(game: ^Game) {
	#partial switch game.play_state {
	case .MainMenu:
		game.play_state = .MapSel

	case .Paused:
		game.play_state = .Playing

	case .GameOver:
		restart_game(game)

	case:
		break
	}
}
