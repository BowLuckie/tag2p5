package tag2p5

import rl "vendor:raylib"

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(GAME_WIDTH, GAME_HEIGHT, "raylib!")
	rl.SetWindowMinSize(GAME_WIDTH / 4, GAME_HEIGHT / 4)
	game := create_test_game()

	target := rl.LoadRenderTexture(GAME_WIDTH, GAME_HEIGHT)


	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		update_game(&game, dt)
		render_game(&game, target)
		draw_screen(target)
	}

	rl.UnloadRenderTexture(target)
	rl.CloseWindow()
}
