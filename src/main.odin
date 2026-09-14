package tag2p5

import "base:runtime"
import clay "clay-odin"
import "core:fmt"
import "core:mem"
import "renderer"
import rl "vendor:raylib"

_clay_error_handler :: proc "c" (errorData: clay.ErrorData) {
	context = runtime.default_context()
	fmt.panicf("clay error: %d\n", errorData.errorType)
}

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
	rl.InitWindow(GAME_WIDTH, GAME_HEIGHT, "Tag 2.5")
	rl.SetWindowMinSize(GAME_WIDTH * 0.1, GAME_HEIGHT * 0.1)
	rl.SetTargetFPS(60)

	append(
		&renderer.raylib_fonts,
		renderer.Raylib_Font {
			fontId = u16(Fonts.TheOneFont),
			font = rl.LoadFontEx("./assets/PeaberryBase.ttf", 96, nil, 0),
		},
	)

	min_memory_size := clay.MinMemorySize()
	clay_memory := make([]u8, min_memory_size)

	clay_arena := clay.CreateArenaWithCapacityAndMemory(
		uint(min_memory_size),
		raw_data(clay_memory),
	)

	game := new_game()

	clay.Initialize(clay_arena, {GAME_WIDTH, GAME_HEIGHT}, {handler = _clay_error_handler})
	clay.SetMeasureTextFunction(renderer.measure_text, &game.font)

	target := rl.LoadRenderTexture(GAME_WIDTH, GAME_HEIGHT)

	defer {
		free_game(&game)
		rl.UnloadRenderTexture(target)
		rl.CloseWindow()
		delete(clay_memory)
		delete(renderer.raylib_fonts)
	}

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		clay.SetPointerState(transmute(clay.Vector2)mouse_pos(), rl.IsMouseButtonDown(.LEFT))
		clay.UpdateScrollContainers(
			true,
			transmute(clay.Vector2)rl.GetMouseWheelMoveV() * SCROLL_SPEED,
			dt,
		)

		update_game(&game, dt)

		clay.BeginLayout()
		build_ui(&game)
		// clay.SetDebugModeEnabled(true)
		ui_commands := clay.EndLayout(dt)

		render_game(&game, target, ui_commands)
		draw_screen(target)

		if game.suicidal {
			break
		}
	}
}
