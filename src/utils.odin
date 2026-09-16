package tag2p5

import "base:runtime"
import clay "clay-odin"
import "core:fmt"
import "core:mem"
import "core:os"
import rl "vendor:raylib"

log_debug :: proc(args: ..any, sep := " ", flush := true) -> int {
	bytes_written := 0
	bytes_written += fmt.fprint(os.stderr, "\x1b[36m[DEBUG] ")
	bytes_written += fmt.fprint(os.stderr, ..args, sep = sep)
	bytes_written += fmt.fprintln(os.stderr, "\x1b[0m", flush = flush)

	return bytes_written
}

draw_screen :: proc(target: rl.RenderTexture2D) {
	screen_w := max(f32(rl.GetScreenWidth()), f32(GAME_WIDTH) / 4)
	screen_h := max(f32(rl.GetScreenHeight()), f32(GAME_HEIGHT) / 4)
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
	screen_w := max(f32(rl.GetScreenWidth()), f32(GAME_WIDTH) / 4)
	screen_h := max(f32(rl.GetScreenHeight()), f32(GAME_HEIGHT) / 4)
	scale := min(screen_w / GAME_WIDTH, screen_h / GAME_HEIGHT)

	offset_x := (screen_w - GAME_WIDTH * scale) / 2
	offset_y := (screen_h - GAME_HEIGHT * scale) / 2

	return Vector2{(mouse.x - offset_x) / scale, (mouse.y - offset_y) / scale}
}

_clay_error_handler :: proc "c" (errorData: clay.ErrorData) {
	context = runtime.default_context()
	fmt.panicf("clay error: %d\n", errorData.errorType)
}

squash_pairs :: proc(upaired: []f64, allocator: mem.Allocator) -> []Vector2 {
	assert(len(upaired) % 2 == 0, "malformed collision data pairings")
	result := make([]Vector2, len(upaired) / 2, allocator)
	for i in 0 ..< len(result) {
		result[i] = Vector2{f32(upaired[i * 2]), f32(upaired[i * 2 + 1])}
	}
	return result
}

bool_dir :: proc(b: bool) -> f32 {
	if b {
		return -1
	}

	return 1
}
