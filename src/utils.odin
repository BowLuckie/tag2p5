package tag2p5

import "base:runtime"
import clay "clay-odin"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:slice"
import "renderer"
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

update_clay :: proc(dt: f32) {
	clay.SetPointerState(transmute(clay.Vector2)mouse_pos(), rl.IsMouseButtonDown(.LEFT))
	clay.UpdateScrollContainers(
		false,
		transmute(clay.Vector2)rl.GetMouseWheelMoveV() * SCROLL_SPEED,
		dt,
	)
}

create_clay_arena :: proc() -> clay.Arena {
	min_memory_size := clay.MinMemorySize()
	clay_memory := make([]u8, min_memory_size)

	clay_arena := clay.CreateArenaWithCapacityAndMemory(
		uint(min_memory_size),
		raw_data(clay_memory),
	)

	clay.Initialize(clay_arena, {GAME_WIDTH, GAME_HEIGHT}, {handler = _clay_error_handler})
	clay.SetMeasureTextFunction(renderer.measure_text, nil)

	return clay_arena
}

init_raylib :: proc() {
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
}

@(deferred_out = tracking_allocator_report)
tracking_allocator_start :: proc(ctx: ^runtime.Context) -> ^mem.Tracking_Allocator {
	track := new(mem.Tracking_Allocator, ctx.allocator)
	mem.tracking_allocator_init(track, ctx.allocator)
	ctx.allocator = mem.tracking_allocator(track)
	return track
}

tracking_allocator_report :: proc(track: ^mem.Tracking_Allocator) {
	defer mem.tracking_allocator_destroy(track)

	if len(track.bad_free_array) > 0 {
		fmt.printf("tracking allocator: %d bad free(s):\n", len(track.bad_free_array))
		for bad in track.bad_free_array {
			fmt.printf("  bad free at %v (memory: %p)\n", bad.location, bad.memory)
		}
	}

	if len(track.allocation_map) == 0 {
		fmt.println("tracking allocator: no leaks")
	} else {
		fmt.printf("tracking allocator: %d live allocation(s):\n", len(track.allocation_map))

		entries := make([dynamic]mem.Tracking_Allocator_Entry, 0, len(track.allocation_map))
		defer delete(entries)
		for _, leak in track.allocation_map {
			append(&entries, leak)
		}
		slice.sort_by(entries[:], proc(a, b: mem.Tracking_Allocator_Entry) -> bool {
			return a.location.file_path < b.location.file_path
		})

		for leak in entries {
			fmt.printf("  %v leaked %m\n", leak.location, leak.size)
		}
	}

	free(track, track.backing)
}
