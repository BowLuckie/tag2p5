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
	tilemap, err := load_tilemap(tilemap_path)
	if err != nil {fmt.panicf("failed to load tilemap %s", err)}

	restart_tex := rl.LoadTexture("./static/restart.png")
	play_tex := rl.LoadTexture("./static/play.png")
	pause_tex := rl.LoadTexture("./static/pause.png")

	players := make([]Entity, len(player_configs))
	for i in 0 ..< len(player_configs) {
		pc := player_configs[i]
		animation := pc.animation
		if animation.frame_duration <= 0 do animation.frame_duration = 0.5
		if animation.tile_count == 0 do animation.tile_count = 15
		if animation.columns == 0 do animation.columns = 5
		if animation.tile_h == 0 do animation.tile_h = 16
		if animation.tile_w == 0 do animation.tile_w = 16
		if animation.tilesheet.id == 0 do animation.tilesheet = rl.LoadTexture("./static/pretty.png")

		players[i] = Entity {
			center            = pc.center,
			vel               = 0,
			radius            = pc.radius,
			color             = pc.color,
			movement_callback = pc.movement_callback,
			tagged            = i == 0,
			animation         = animation,
			tex               = pc.tex,
		}
	}

	gc := GameCamera {
		cam = rl.Camera2D{zoom = 1, offset = {GAME_WIDTH / 2, GAME_HEIGHT / 2}},
		min_zoom = MIN_ZOOM,
		max_zoom = MAX_ZOOM,
		padding = CAM_PADDING,
	}


	buttons := make([dynamic]Button)
	append(
		&buttons,
		make_button(
			{GAME_WIDTH / 2 - 200, GAME_HEIGHT * .6, 400, 120},
			play_tex,
			{.MainMenu},
			proc(game: ^Game) {game.play_state = .Playing},
		),
	)
	append(
		&buttons,
		make_button(
			{GAME_WIDTH / 2 - 200, GAME_HEIGHT * .6, 400, 120},
			restart_tex,
			{.GameOver},
			restart_game,
		),
	)
	append(
		&buttons,
		make_button(
			{GAME_WIDTH / 2, GAME_HEIGHT * 0.9, 64, 64},
			pause_tex,
			{.Playing},
			proc(game: ^Game) {game.play_state = .Paused},
		),
	)
	append(
		&buttons,
		make_button(
			{GAME_WIDTH / 2 - 200, GAME_HEIGHT * .6, 400, 120},
			play_tex,
			{.Paused},
			proc(game: ^Game) {game.play_state = .Playing},
		),
	)

	layers := make([dynamic]ParallaxLayer)
	append(&layers, ParallaxLayer{rl.LoadTexture("./static/bg3.png"), 0.1})
	append(&layers, ParallaxLayer{rl.LoadTexture("./static/bg2.png"), 0.3})
	append(&layers, ParallaxLayer{rl.LoadTexture("./static/bg.png"), 0.9})
	append(&layers, ParallaxLayer{rl.LoadTexture("./static/filler.png"), 0})

	game := Game {
		gc         = gc,
		players    = players,
		tilemap    = tilemap,
		segments   = generate_segments(tilemap),
		last_tag   = 0,
		game_time  = game_time,
		play_state = .MainMenu,
		buttons    = buttons[:],
		bg_layers  = layers[:],
	}

	return game
}

create_test_game :: proc() -> Game {

	ring_anim := AnimationObj {
		frame_duration = 0.18,
		tile_count     = 6,
		columns        = 6,
		tile_w         = 64,
		tile_h         = 64,
		tilesheet      = rl.LoadTexture("./static/ringsheet.png"),
	}

	player_configs := [2]PlayerConfig {
		{
			center = {600, 300},
			radius = PLAYER_RAD,
			color = rl.BLUE,
			movement_callback = p1_movement,
			tex = rl.LoadTexture("./static/blue_p.png"),
			animation = ring_anim,
		},
		{
			center = {800, 350},
			radius = PLAYER_RAD,
			color = rl.RED,
			movement_callback = p2_movement,
			tex = rl.LoadTexture("./static/red_p.png"),
			animation = ring_anim,
		},
	}
	return create_game("./static/pretty.json", player_configs[:]) // change me!
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


draw_segs :: proc(segs: []Segment) {
	for seg in segs {
		rl.DrawLineEx(seg.a, seg.b, 3, rl.BLACK)
	}
}

render_game :: proc(game: ^Game, target: rl.RenderTexture2D) {
	rl.BeginTextureMode(target)
	rl.ClearBackground(SKY_COLOR)

	draw_parallax_layers(game^)

	rl.BeginMode2D(game.gc.cam)
	// draw_segs(game.segments)
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

draw_parallax_layers :: proc(game: Game) {
	for layer in game.bg_layers {
		tex_w := f32(layer.tex.width)
		tex_h := f32(layer.tex.height)

		scale := f32(GAME_HEIGHT) / tex_h
		draw_w := tex_w * scale
		draw_h := tex_h * scale

		lcam := rl.Camera2D {
			offset = {f32(GAME_WIDTH) / 2, f32(GAME_HEIGHT) / 2},
			target = {game.gc.cam.target.x * layer.factor, 0},
			zoom   = 1,
		}
		rl.BeginMode2D(lcam)

		half_w := f32(GAME_WIDTH) / 2
		left := lcam.target.x - half_w
		right := lcam.target.x + half_w

		start_x := left - math.mod(left, draw_w) - draw_w

		for x := start_x; x < right + draw_w; x += draw_w {
			rl.DrawTexturePro(
				layer.tex,
				{0, 0, tex_w, tex_h},
				{x, -draw_h / 2, draw_w, draw_h},
				{0, 0},
				0,
				rl.WHITE,
			)
		}

		rl.EndMode2D()
	}
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


// TODO: improve game over screen
declare_win :: proc(game: ^Game) {
	for player in game.players {
		if !player.tagged {
			fmt.printf("player %s won!", player.color)
		}
	}

	game.play_state = .GameOver
}

update_animation :: proc {
	update_animation_a,
	update_animation_e,
}

update_animation_e :: proc(entity: ^Entity, dt: f32) {
	update_animation(&entity.animation, dt)
}

update_animation_a :: proc(animation_obj: ^AnimationObj, dt: f32) {
	animation_obj.frame_time += dt

	if animation_obj.frame_time >= animation_obj.frame_duration {
		animation_obj.frame_time = 0
		animation_obj.frame += 1
	}

	if animation_obj.frame >= animation_obj.tile_count {
		animation_obj.frame = 0
	}
}

animation_rect :: proc(animation_obj: AnimationObj) -> rl.Rectangle {
	return rl.Rectangle {
		f32(animation_obj.frame % animation_obj.columns) * animation_obj.tile_w,
		f32(animation_obj.frame / animation_obj.columns) * animation_obj.tile_h,
		f32(animation_obj.tile_h),
		f32(animation_obj.tile_w),
	}
}
