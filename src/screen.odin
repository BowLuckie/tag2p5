package tag2p5

import rl "vendor:raylib"

draw_screen :: proc(target: rl.RenderTexture2D) {
	screen_w := f32(rl.GetScreenWidth())
	screen_h := f32(rl.GetScreenHeight())
	scale := min(screen_w / GAME_WIDTH, screen_h / GAME_HEIGHT)

	dest := rl.Rectangle {
		(screen_w - GAME_WIDTH * scale) / 2,
		(screen_h - GAME_HEIGHT * scale) / 2,
		GAME_WIDTH * scale,
		GAME_HEIGHT * scale,
	}

	src := rl.Rectangle{0, 0, GAME_WIDTH, -GAME_HEIGHT}

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	rl.DrawTexturePro(target.texture, src, dest, {0, 0}, 0, rl.WHITE)
	rl.EndDrawing()
}

mouse_pos :: proc() -> Vector2 {
	mouse := rl.GetMousePosition()
	screen_w := f32(rl.GetScreenWidth())
	screen_h := f32(rl.GetScreenHeight())
	scale := min(screen_w / GAME_WIDTH, screen_h / GAME_HEIGHT)

	offset_x := (screen_w - GAME_WIDTH * scale) / 2
	offset_y := (screen_h - GAME_HEIGHT * scale) / 2

	return Vector2{(mouse.x - offset_x) / scale, (mouse.y - offset_y) / scale}
}
