package tag2p5

import "core:fmt"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

update_camera :: proc(gc: ^GameCamera, p1, p2: Vector2, screen_w, screen_h, dt: f32) {
	target := (p1 + p2) / 2

	min_x := min(p1.x, p2.x) - CAM_PADDING
	max_x := max(p1.x, p2.x) + CAM_PADDING
	min_y := min(p1.y, p2.y) - CAM_PADDING
	max_y := max(p1.y, p2.y) + CAM_PADDING

	needed_w := max_x - min_x
	needed_h := max_y - min_y

	zoom_x := screen_w / needed_w
	zoom_y := screen_h / needed_h
	zoom := min(zoom_x, zoom_y)

	zoom = clamp(zoom, gc.min_zoom, gc.max_zoom)

	t_pos := clamp(CAM_FOLLOW_SPEED * dt, 0, 1)
	t_zoom := clamp(CAM_ZOOM_SPEED * dt, 0, 1)
	gc.cam.target = linalg.lerp(gc.cam.target, target, t_pos)
	gc.cam.zoom = math.lerp(gc.cam.zoom, zoom, t_zoom)

	gc.cam.offset = {screen_w / 2, screen_h / 2}
}

free_game :: proc(game: ^Game) {
	delete(game.players)
	rl.UnloadTexture(game.tilemap.tileset_tex)
	delete(game.segments)
	for btn in game.buttons {
		rl.UnloadTexture(btn.glyph)
	}
	delete(game.buttons)
}

make_button :: proc(
	rect: rl.Rectangle,
	glyph: rl.Texture2D,
	states: bit_set[PlayState],
	on_click: proc(game: ^Game),
) -> Button {
	return Button{rect, glyph, states, on_click}
}

create_game :: proc(
	tilemap_path: string,
	player_configs: []PlayerConfig,
	game_time: f32 = GAME_TIME,
) -> Game {
	tilemap, _ := load_tilemap(tilemap_path)

	restart_tex := rl.LoadTexture("./static/restart.png")
	play_tex := rl.LoadTexture("./static/play.png")
	pause_tex := rl.LoadTexture("./static/pause.png")

	players := make([]Entity, len(player_configs))
	for i in 0 ..< len(player_configs) {
		pc := player_configs[i]
		players[i] = Entity {
			center            = pc.center,
			vel               = 0,
			radius            = pc.radius,
			color             = pc.color,
			movement_callback = pc.movement_callback,
			tagged            = i == 0,
		}
	}

	gc := GameCamera {
		cam = rl.Camera2D{zoom = 1, offset = {GAME_WIDTH / 2, GAME_HEIGHT / 2}},
		min_zoom = MIN_ZOOM,
		max_zoom = MAX_ZOOM,
		padding = CAM_PADDING,
	}

	game := Game {
		gc         = gc,
		players    = players,
		tilemap    = tilemap,
		segments   = generate_segments(tilemap),
		last_tag   = 0,
		game_time  = game_time,
		play_state = .MainMenu,
	}

	buttons := make([]Button, 4, context.allocator)
	buttons[0] = make_button(
		{GAME_WIDTH / 2 - 200, GAME_HEIGHT * .6, 400, 120},
		play_tex,
		{.MainMenu},
		proc(game: ^Game) {game.play_state = .Playing},
	)
	buttons[1] = make_button(
		{GAME_WIDTH / 2 - 200, GAME_HEIGHT * .6, 400, 120},
		restart_tex,
		{.GameOver},
		restart_game,
	)
	buttons[2] = make_button(
		{GAME_WIDTH / 2, GAME_HEIGHT * 0.9, 64, 64},
		pause_tex,
		{.Playing},
		proc(game: ^Game) {game.play_state = .Paused},
	)
	buttons[3] = make_button(
		{GAME_WIDTH / 2 - 200, GAME_HEIGHT * .6, 400, 120},
		play_tex,
		{.Paused},
		proc(game: ^Game) {game.play_state = .Playing},
	)

	game.buttons = buttons

	return game
}

create_test_game :: proc() -> Game {
	player_configs := [2]PlayerConfig {
		{
			center = {300, 300},
			radius = PLAYER_RAD,
			color = rl.BLUE,
			movement_callback = p1_movement,
		},
		{
			center = {300, 300},
			radius = PLAYER_RAD,
			color = rl.RED,
			movement_callback = p1_movement,
		},
	}
	return create_game("./static/basic.json", player_configs[:])
}

restart_game :: proc(game: ^Game) {
	free_game(game)
	game^ = create_test_game()
	game.play_state = .Playing
}

update_game :: proc(game: ^Game, dt: f32) {
	if rl.IsMouseButtonPressed(.LEFT) {
		fmt.print(mouse_pos())
		handle_click(game, mouse_pos())
	}

	if game.play_state != .Playing {return}
	for &player in game.players {
		update_entity(game.segments, &player, dt)
	}

	resolve_entity_tagging(game, dt)

	update_camera(
		&game.gc,
		game.players[0].center,
		game.players[1].center,
		GAME_WIDTH,
		GAME_HEIGHT,
		dt,
	)

	game.game_time -= dt
	if game.game_time < 0 {
		game.game_time = 0
		declare_win(game)
	}
}

handle_click :: proc(game: ^Game, mouse_pos: Vector2) {
	for button in game.buttons {
		if rl.CheckCollisionPointRec(mouse_pos, button.rect) && game.play_state in button.states {
			button.on_click(game)
		}
	}
}

render_game :: proc(game: ^Game, target: rl.RenderTexture2D) {
	rl.BeginTextureMode(target)
	rl.ClearBackground(rl.WHITE)

	rl.BeginMode2D(game.gc.cam)
	draw_segs(game.segments)
	draw_tilemap(game.tilemap)

	for &player in game.players {
		draw_entity(player)
	}

	rl.EndMode2D()

	rl.DrawText(fmt.ctprintf("%.0f", game.game_time), GAME_WIDTH / 2, 30, 30, rl.BLACK)

	if game.play_state == .GameOver {
		rl.DrawRectangle(0, 0, GAME_WIDTH, GAME_HEIGHT, rl.Fade(rl.BLACK, 0.3))
		draw_text("Game Over!", PosX = GAME_WIDTH / 2, PosY = GAME_HEIGHT / 2)
	} else if game.play_state == .Paused {
		rl.DrawRectangle(0, 0, GAME_WIDTH, GAME_HEIGHT, rl.Fade(rl.BLACK, 0.3))
		draw_text("Paused", PosX = GAME_WIDTH / 2, PosY = GAME_HEIGHT / 2)
	} else if game.play_state == .MainMenu {
		rl.DrawRectangle(0, 0, GAME_WIDTH, GAME_HEIGHT, rl.WHITE)
		draw_text("Tag 2.5", PosX = GAME_WIDTH / 2, PosY = GAME_HEIGHT / 2)
	}

	draw_buttons(game)

	rl.EndTextureMode()
}

draw_text :: proc(
	text: cstring,
	font_size: i32 = 100,
	PosX, PosY: i32,
	color: rl.Color = rl.BLACK,
) {
	text_width := rl.MeasureText(text, font_size)

	rl.DrawText(text, PosX - text_width / 2, PosY - font_size / 2, font_size, color)
}

draw_buttons :: proc(game: ^Game) {
	for btn in game.buttons {
		if game.play_state in btn.states {
			tex_w := f32(btn.glyph.width)
			tex_h := f32(btn.glyph.height)

			scale := min(btn.rect.width / tex_w, btn.rect.height / tex_h)
			draw_w := tex_w * scale
			draw_h := tex_h * scale

			dest := rl.Rectangle {
				btn.rect.x + (btn.rect.width - draw_w) / 2,
				btn.rect.y + (btn.rect.height - draw_h) / 2,
				draw_w,
				draw_h,
			}

			src := rl.Rectangle{0, 0, tex_w, tex_h}
			rl.DrawTexturePro(btn.glyph, src, dest, {0, 0}, 0, rl.WHITE)
		}
	}
}

declare_win :: proc(game: ^Game) {
	for player in game.players {
		if !player.tagged {
			fmt.printf("player %s won!", player.color)
		}
	}

	game.play_state = .GameOver
}
