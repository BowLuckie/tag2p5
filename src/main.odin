package tag2p5

import rl "vendor:raylib"

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(GAME_WIDTH, GAME_HEIGHT, "raylib!")
	game := create_game("./static/basic.json")

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
