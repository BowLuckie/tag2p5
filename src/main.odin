package main

import rl "vendor:raylib"

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(GAME_WIDTH, GAME_HEIGHT, "raylib!")
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
