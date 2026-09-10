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
	// tilemap
	for _, points in &game.tilemap.collide_data {
		delete(points)
	}
	delete(game.tilemap.collide_data)
	delete(game.tilemap.tiles)
	rl.UnloadTexture(game.tilemap.tileset_tex)

	// players
	for p in game.players {
		rl.UnloadTexture(p.tex)
		rl.UnloadTexture(p.triangle_tex)
	}
	delete(game.players)

	// parallax layers
	for layer in game.bg_layers {
		rl.UnloadTexture(layer.tex)
	}
	delete(game.bg_layers)

	// segments
	delete(game.segments)

	// scenes — unload shared button textures once, then free slices
	seen := make(map[u32]bool)
	for state, scene in &game.scenes {
		_ = state
		for btn in scene.buttons {
			if _, found := seen[btn.glyph.id]; !found {
				rl.UnloadTexture(btn.glyph)
				seen[btn.glyph.id] = true
			}
		}
		delete(scene.buttons)
		delete(scene.labels)
	}
	delete(game.scenes)
	delete(seen)
}

make_button :: proc(rect: rl.Rectangle, glyph: Texture2D, on_click: proc(game: ^Game)) -> Button {
	return Button{rect, glyph, on_click}
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
	mm_tex := rl.LoadTexture("./static/menu.png")

	players := make([]Entity, len(player_configs))
	for i in 0 ..< len(player_configs) {
		pc := player_configs[i]
		animation := pc.animation
		if animation.frame_duration <= 0 do animation.frame_duration = 0.5
		if animation.tile_count == 0 do animation.tile_count = 15
		if animation.columns == 0 do animation.columns = 5
		if animation.tile_h == 0 do animation.tile_h = 16
		if animation.tile_w == 0 do animation.tile_w = 16

		players[i] = Entity {
			center            = pc.center,
			vel               = 0,
			radius            = pc.radius,
			movement_callback = pc.movement_callback,
			tagged            = i == 0,
			animation         = animation,
			tex               = pc.tex,
			pid               = pc.pid,
			triangle_tex      = pc.triangle_tex,
		}
	}

	gc := GameCamera {
		cam = rl.Camera2D{zoom = 1, offset = {GAME_WIDTH / 2, GAME_HEIGHT / 2}},
		min_zoom = 0,
		max_zoom = MAX_ZOOM,
		padding = CAM_PADDING,
	}


	layers := make([dynamic]ParallaxLayer)
	append(&layers, ParallaxLayer{rl.LoadTexture("./static/bg3.png"), 0.1})
	append(&layers, ParallaxLayer{rl.LoadTexture("./static/bg2.png"), 0.3})
	append(&layers, ParallaxLayer{rl.LoadTexture("./static/bg.png"), 0.9})
	append(&layers, ParallaxLayer{rl.LoadTexture("./static/filler.png"), 0})

	// main menu buttons
	mm_b := make([]Button, 1)
	mm_b[0] = make_button(
		{GAME_WIDTH / 2 - 200, GAME_HEIGHT / 2 + 120, 400, 120},
		play_tex,
		proc(game: ^Game) {game.play_state = .Playing},
	)

	// main menu labels
	mm_l := make([]Label, 1)
	mm_l[0] = Label {
		text      = fmt.ctprint("tag 2.5"),
		font_size = 100,
		posx      = GAME_WIDTH / 2,
		posy      = GAME_HEIGHT / 2,
		color     = rl.BLACK,
	}

	main_menu := Scene {
		scene   = .MainMenu,
		buttons = mm_b,
		labels  = mm_l,
	}

	pause_button := make([]Button, 1)
	pause_button[0] = make_button(
		{GAME_WIDTH / 2, GAME_HEIGHT * 0.9, 128, 128},
		pause_tex,
		proc(game: ^Game) {game.play_state = .Paused},
	)

	playing := Scene {
		scene   = .Playing,
		buttons = pause_button,
		labels  = nil,
	}

	// pause menu buttons
	pm_b := make([dynamic]Button)
	append(
		&pm_b,
		make_button(
			{GAME_WIDTH / 2 - 200, GAME_HEIGHT / 2 + 80, 400, 120},
			play_tex,
			proc(game: ^Game) {game.play_state = .Playing},
		),
	)
	append(
		&pm_b,
		make_button(
			{GAME_WIDTH / 2 - 200, GAME_HEIGHT / 2 + 200, 400, 120},
			restart_tex,
			restart_game,
		),
	)
	append(
		&pm_b,
		make_button(
			{GAME_WIDTH / 2 - 200, GAME_HEIGHT / 2 + 320, 400, 120},
			mm_tex,
			proc(game: ^Game) {restart_game(game); game.play_state = .MainMenu},
		),
	)

	// pause menu labels
	pm_l := make([]Label, 1)
	pm_l[0] = Label {
		text      = fmt.ctprintf("Paused"),
		font_size = 100,
		posx      = GAME_WIDTH / 2,
		posy      = GAME_HEIGHT / 2,
		color     = rl.WHITE,
	}

	pause_menu := Scene {
		scene   = .Paused,
		buttons = pm_b[:],
		labels  = pm_l,
	}

	// game over menu buttons
	go_b := make([dynamic]Button, 2)
	append(
		&go_b,
		make_button(
			{GAME_WIDTH / 4 - 200, GAME_HEIGHT / 2 + 80, 400, 120},
			restart_tex,
			restart_game,
		),
	)
	append(
		&go_b,
		make_button(
			{GAME_WIDTH / 4 - 200, GAME_HEIGHT / 2 + 200, 400, 120},
			mm_tex,
			proc(game: ^Game) {restart_game(game); game.play_state = .MainMenu},
		),
	)

	// game over menu labels
	go_l := make([]Label, 1)
	go_l[0] = Label {
		text      = fmt.ctprintf("Game Over"),
		font_size = 100,
		posx      = GAME_WIDTH / 4,
		posy      = GAME_HEIGHT / 2,
		color     = rl.WHITE,
	}

	game_over := Scene {
		scene   = .GameOver,
		buttons = go_b[:],
		labels  = go_l,
	}

	scenes := make(map[GameState]Scene)
	scenes[.MainMenu] = main_menu
	scenes[.Playing] = playing
	scenes[.Paused] = pause_menu
	scenes[.GameOver] = game_over

	game := Game {
		gc         = gc,
		players    = players,
		tilemap    = tilemap,
		segments   = generate_segments(tilemap),
		last_tag   = 0,
		game_time  = game_time,
		play_state = .MainMenu,
		bg_layers  = layers[:],
		scenes     = scenes,
	}

	return game
}

create_test_game :: proc() -> Game {
	player_anim := AnimationObj { 	// currently not using
		frame_duration = 0.1,
		tile_count     = 3,
		columns        = 1,
		tile_w         = 64,
		tile_h         = 64,
		tilesheet      = {},
	}

	player_configs := [2]PlayerConfig {
		{
			center = {600, 300},
			radius = PLAYER_RAD,
			movement_callback = p1_movement,
			tex = rl.LoadTexture("./static/blue_p.png"),
			triangle_tex = rl.LoadTexture("./static/triangle_b.png"),
			animation = player_anim,
			pid = 0,
		},
		{
			center = {800, 400},
			radius = PLAYER_RAD,
			movement_callback = p2_movement,
			tex = rl.LoadTexture("./static/red_p.png"),
			triangle_tex = rl.LoadTexture("./static/triangle_r.png"),
			animation = player_anim,
			pid = 1,
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
	for button in game.scenes[game.play_state].buttons {
		if rl.CheckCollisionPointRec(mouse_pos, button.rect) {
			button.on_click(game)
		}
	}
}

draw_entity :: proc(e: Entity) {
	sign: f32 = 1
	if e.vel.x < 0 {
		sign = -1
	}

	rl.DrawTexturePro(
		e.tex,
		{0, 0, f32(e.tex.width) * sign, f32(e.tex.height)},
		{e.center.x, e.center.y, e.radius * 2, e.radius * 2},
		{e.radius, e.radius},
		e.rotation,
		rl.WHITE,
	)

	if e.tagged {
		draw_triangle(e)
		// rect := animation_rect(e.animation)
		// rl.DrawTexturePro(
		// 	e.animation.tilesheet,
		// 	rect,
		// 	{e.center.x, e.center.y, e.radius * 4, e.radius * 4},
		// 	{e.radius * 2, e.radius * 2},
		// 	0,
		// 	rl.WHITE,
		// )
	}
}

draw_triangle :: proc(e: Entity) {
	// gap: f32 = e.radius * 0.3
	// tri_height: f32 = e.radius * 0.8
	// tri_width: f32 = e.radius
	//
	// base_y := e.center.y - e.radius - gap - tri_height
	// tip_y := base_y + tri_height
	//
	// tip := Vector2{e.center.x, tip_y}
	// left := Vector2{e.center.x - tri_width / 2, base_y}
	// right := Vector2{e.center.x + tri_width / 2, base_y}
	//
	// rl.DrawTriangle(tip, right, left, e.color)

	rl.DrawTexture(
		e.triangle_tex,
		i32(e.center.x) - (e.triangle_tex.width / 2) + 1,
		i32(e.center.y) - i32(e.radius * 2.2),
		rl.WHITE,
	)
}

draw_segs :: proc(segs: []Segment) {
	for seg in segs {
		rl.DrawLineEx(seg.a, seg.b, 1, rl.BLACK)
	}
}

render_game :: proc(game: ^Game, target: rl.RenderTexture2D) {
	rl.BeginTextureMode(target)
	defer rl.EndTextureMode()
	rl.ClearBackground(SKY_COLOR)

	if game.play_state == .MainMenu {
		draw_scene(game)
		rl.EndTextureMode()
		return
	}

	draw_parallax_layers(game^)

	rl.BeginMode2D(game.gc.cam)
	// draw_segs(game.segments)
	draw_tilemap(game.tilemap)

	for &player in game.players {
		draw_entity(player)
	}

	rl.EndMode2D()

	t_color := rl.BLACK
	t_int := uint(game.game_time)
	if t_int % 2 == 0 && game.game_time < 9 {
		t_color = rl.RED
	}
	rl.DrawText(fmt.ctprintf("%d", t_int), GAME_WIDTH / 2, 60, 80, t_color)

	draw_scene(game)
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
	font_size: uint = 100,
	PosX, PosY: i32,
	color: rl.Color = rl.BLACK,
) {
	text_width := rl.MeasureText(text, i32(font_size))
	rl.DrawText(text, PosX - text_width / 2, PosY - i32(font_size) / 2, i32(font_size), color)
}

draw_scene :: proc(game: ^Game) {
	scene, ok := game.scenes[game.play_state]
	if !ok {
		when ODIN_DEBUG {
			fmt.println(game.scenes)
		}
		fmt.panicf("play state does not have a corrosponding theme! %s", game.play_state)
	}

	if game.play_state == .MainMenu {
		rl.DrawRectangle(0, 0, GAME_WIDTH, GAME_HEIGHT, rl.WHITE)
	} else if game.play_state != .Playing {
		rl.DrawRectangle(0, 0, GAME_WIDTH, GAME_HEIGHT, (rl.Color{0, 0, 0, 100}))
	}

	if game.play_state == .GameOver {
		rl.DrawRectanglePro(
			{GAME_WIDTH * 0.8, GAME_HEIGHT * 0.8, GAME_WIDTH * 2, GAME_HEIGHT},
			{GAME_WIDTH / 2, GAME_HEIGHT / 2},
			-75,
			rl.WHITE,
		)

		e: Entity

		assert(game.mode == .Normal)
		for player in game.players {
			if player.tagged == true {
				e = player
				break
			}

			fmt.println("no tagged player found!")
		}

		rl.DrawTexturePro(
			e.tex,
			{0, 0, f32(e.tex.width), f32(e.tex.height)},
			{GAME_WIDTH * 0.65, GAME_HEIGHT / 2 - e.radius * 20, e.radius * 60, e.radius * 60},
			{0, 0},
			0,
			rl.WHITE,
		)

		rl.DrawText(
			fmt.ctprintf("Player %d lost!", e.pid + 1),
			GAME_WIDTH * 0.75 - 250,
			GAME_HEIGHT * 0.25 - 100,
			125,
			rl.BLACK,
		)
	}

	draw_buttons(scene.buttons)
	draw_labels(scene.labels)
}

draw_buttons :: proc(buttons: []Button) {
	for btn in buttons {
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

draw_labels :: proc(labels: []Label) {
	for lbl in labels {
		draw_text(lbl.text, lbl.font_size, lbl.posx, lbl.posy, lbl.color)
	}
}

declare_win :: proc(game: ^Game) {
	for player in game.players {
		if !player.tagged {
			fmt.printf("player %s won!", player.pid + 1)
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
