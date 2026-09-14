package tag2p5

import clay "clay-odin"
import "core:c"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "renderer"
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
	if len(game.levels) == 0 {return}

	free_arena(&game.levels[0].arena)

	for p in game.levels[0].players {
		rl.UnloadTexture(p.tex)
		rl.UnloadTexture(p.triangle_tex)
	}
	delete(game.levels[0].players)

	delete(game.levels)
}

make_button :: proc(rect: rl.Rectangle, glyph: Texture2D, on_click: proc(game: ^Game)) -> Button {
	return Button{rect, glyph, on_click}
}

create_arena :: proc(tilemap_path: string, pspawns: []Vector2) -> Arena {
	arena_buf := make([]u8, 4 * 1024 * 1024)
	a: mem.Arena
	mem.arena_init(&a, arena_buf)
	alloc := mem.arena_allocator(&a)

	tilemap, err := load_tilemap(tilemap_path, alloc)
	if err != nil {fmt.panicf("failed to load tilemap %s", err)}

	layers := make([dynamic]ParallaxLayer, alloc)
	append(&layers, ParallaxLayer{rl.LoadTexture(ASSET_DIR + "bg3.png"), 0.6})
	append(&layers, ParallaxLayer{rl.LoadTexture(ASSET_DIR + "bg2.png"), 0.8})
	append(&layers, ParallaxLayer{rl.LoadTexture(ASSET_DIR + "bg.png"), 0.99})
	append(&layers, ParallaxLayer{rl.LoadTexture(ASSET_DIR + "filler.png"), 0})

	return Arena {
		tilemap = tilemap,
		segments = generate_segments(tilemap, alloc),
		bg_layers = layers[:],
		pspawns = pspawns,
		arena_buf = arena_buf,
		arena = a,
	}
}

free_arena :: proc(arena: ^Arena) {
	rl.UnloadTexture(arena.tilemap.tileset_tex)
	for layer in arena.bg_layers {
		rl.UnloadTexture(layer.tex)
	}
	delete(arena.arena_buf)
}

create_game :: proc(
	arenas: Arena,
	player_configs: []PlayerConfig,
	game_time: f32 = GAME_TIME,
) -> Game {
	restart_tex := rl.LoadTexture(ASSET_DIR + "restart.png")
	play_tex := rl.LoadTexture(ASSET_DIR + "play.png")
	pause_tex := rl.LoadTexture(ASSET_DIR + "pause.png")
	mm_tex := rl.LoadTexture(ASSET_DIR + "menu.png")

	players := make([]Entity, len(player_configs))
	for i in 0 ..< len(player_configs) {
		pc := player_configs[i]
		animation := pc.animation
		if animation.frame_duration <= 0 do animation.frame_duration = 0.5
		if animation.tile_count == 0 do animation.tile_count = 15
		if animation.columns == 0 do animation.columns = 5
		if animation.tile_h == 0 do animation.tile_h = 16
		if animation.tile_w == 0 do animation.tile_w = 16

		center := Vector2{0, 0}
		if i < len(arenas.pspawns) {
			center = arenas.pspawns[i]
		}

		players[i] = Entity {
			center            = center,
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

	assets := GuiAssets {
		play_button_tex = play_tex,
		quit_button_tex = mm_tex,
	}

	level := Level {
		gc        = gc,
		arena     = arenas,
		players   = players,
		last_tag  = 0,
		game_time = game_time,
		thumb     = rl.LoadTexture(ASSET_DIR + "maynard.png"),
	}

	levels := make([dynamic]Level)
	append(&levels, level)
	append(&levels, level)
	append(&levels, level)
	append(&levels, level)
	append(&levels, level)
	append(&levels, level)
	append(&levels, level)

	game := Game {
		play_state = .MainMenu,
		levels = levels[:],
		assets = assets,
		font = [Fonts]rl.Font {
			.TheOneFont = rl.LoadFontEx("./assets/PeaberryBase.ttf", 50, nil, 0),
		},
	}

	return game
}

get_maps_json :: proc() -> []string {
	file_list := rl.LoadDirectoryFilesEx(fmt.ctprint(ASSET_DIR), fmt.ctprint(".json"), true)
	file_slice := file_list.paths[:file_list.count]

	out := make([dynamic]string, file_list.count)
	for cstr in file_slice {
		append(&out, string(cstr))
	}

	rl.UnloadDirectoryFiles(file_list)
	return out[:]
}

new_game :: proc() -> Game {
	player_anim := AnimationObj { 	// currently not using
		frame_duration = 0.1,
		tile_count     = 3,
		columns        = 1,
		tile_w         = 64,
		tile_h         = 64,
		tilesheet      = {},
	}

	arena := create_arena(ASSET_DIR + "pretty.json", {{600, 300}, {800, 400}})

	player_configs := [2]PlayerConfig {
		{
			radius = PLAYER_RAD,
			movement_callback = p1_movement,
			tex = rl.LoadTexture(ASSET_DIR + "blue_p.png"),
			triangle_tex = rl.LoadTexture(ASSET_DIR + "triangle_b.png"),
			animation = {},
			pid = 0,
		},
		{
			radius = PLAYER_RAD,
			movement_callback = p2_movement,
			tex = rl.LoadTexture(ASSET_DIR + "red_p.png"),
			triangle_tex = rl.LoadTexture(ASSET_DIR + "triangle_r.png"),
			animation = {},
			pid = 1,
		},
	}

	return create_game(arena, player_configs[:])
}

restart_game :: proc(game: ^Game) {
	free_game(game)
	game^ = new_game()
	game.play_state = .Playing
}

update_game :: proc(game: ^Game, dt: f32) {
	if game.play_state != .Playing {return}
	for &player in game.levels[game.lvl_idx].players {
		update_entity(game.levels[game.lvl_idx].arena.segments, &player, dt)
	}

	resolve_entity_tagging(game, dt)

	update_camera(
		&game.levels[game.lvl_idx].gc,
		game.levels[game.lvl_idx].players[0].center,
		game.levels[game.lvl_idx].players[1].center,
		GAME_WIDTH,
		GAME_HEIGHT,
		dt,
	)

	game.levels[game.lvl_idx].game_time -= dt
	if game.levels[game.lvl_idx].game_time < 0 {
		game.levels[game.lvl_idx].game_time = 0
		game.play_state = .GameOver
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

render_game :: proc(
	game: ^Game,
	target: rl.RenderTexture2D,
	ui_commands: clay.ClayArray(clay.RenderCommand),
) {
	rl.BeginTextureMode(target)
	defer rl.EndTextureMode()
	rl.ClearBackground(rl.WHITE)

	if game.play_state != .MainMenu && game.play_state != .MapSel {
		rl.ClearBackground(SKY_COLOR)
		draw_parallax_layers(game^)

		rl.BeginMode2D(game.levels[game.lvl_idx].gc.cam)
		// draw_segs(game.segments)
		draw_tilemap(game.levels[game.lvl_idx].arena.tilemap)

		for &player in game.levels[game.lvl_idx].players {
			draw_entity(player)
		}
		rl.EndMode2D()
	}

	commands := ui_commands
	renderer.clay_raylib_render(&commands)
}

draw_parallax_layers :: proc(game: Game) {
	for layer in game.levels[game.lvl_idx].arena.bg_layers {
		tex_w := f32(layer.tex.width)
		tex_h := f32(layer.tex.height)

		scale := f32(GAME_HEIGHT) / tex_h
		draw_w := tex_w * scale
		draw_h := tex_h * scale

		lcam := rl.Camera2D {
			offset = {f32(GAME_WIDTH) / 2, f32(GAME_HEIGHT) / 2},
			target = {game.levels[game.lvl_idx].gc.cam.target.x * layer.factor, 0},
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


build_ui :: proc(game: ^Game) {
	switch game.play_state {
	case .MainMenu:
		ui_main_menu(game)
	case .MapSel:
		ui_map_select(game)
	case .Playing:
		ui_hud(game)
	case .Paused:
		ui_hud(game)
		ui_dim(game)
		ui_pause_menu(game)
	case .GameOver:
		ui_hud(game)
		ui_dim(game)
		ui_game_over(game)
	}
}

ui_main_menu :: proc(game: ^Game) {
	if UI(ID("menu_root"))(
	clay.ElementDeclaration {
		layout = clay.LayoutConfig {
			sizing = clay.Sizing{width = clay.SizingGrow(), height = clay.SizingGrow()},
			layoutDirection = .TopToBottom,
			childAlignment = {x = .Center, y = .Top},
		},
		backgroundColor = clay.Color{20, 20, 30, 255},
	},
	) {
		if UI(ID("menu_title_section"))(
		clay.ElementDeclaration {
			layout = clay.LayoutConfig {
				sizing = clay.Sizing{width = clay.SizingGrow(), height = clay.SizingPercent(0.5)},
				childAlignment = {x = .Center, y = .Center},
			},
		},
		) {
			clay.Text(
				"TAG 2.5",
				clay.TextElementConfig {
					fontId = 0,
					fontSize = 96 * 2,
					textColor = clay.Color{255, 255, 255, 255},
				},
			)
		}

		if UI(ID("menu_buttons_section"))(
		clay.ElementDeclaration {
			layout = clay.LayoutConfig {
				sizing = clay.Sizing{width = clay.SizingGrow(), height = clay.SizingPercent(0.25)},
				childAlignment = {x = .Center, y = .Center},
			},
		},
		) {
			if UI(ID("menu_buttons"))(
			clay.ElementDeclaration {
				layout = clay.LayoutConfig {
					layoutDirection = .TopToBottom,
					childAlignment = {x = .Center, y = .Center},
					childGap = 48,
				},
			},
			) {
				if image_button(ID("PlayButton"), &game.assets.play_button_tex, 600, 120) {
					game.play_state = .MapSel
				}
				if image_button(ID("PlaceholderButton"), &game.assets.play_button_tex, 600, 120) {
					// TODO: settings or credits or something
				}
				if image_button(ID("QuitButton"), &game.assets.quit_button_tex, 600, 120) {
					game.suicidal = true
				}
			}
		}

		if UI(ID("menu_bottom_spacer"))(
		clay.ElementDeclaration {
			layout = {
				sizing = clay.Sizing{width = clay.SizingGrow(), height = clay.SizingPercent(0.25)},
			},
		},
		) {}
	}
}

ui_map_select :: proc(game: ^Game) {
	if UI(ID("mapselect_root"))(
	clay.ElementDeclaration {
		layout = clay.LayoutConfig {
			sizing = clay.Sizing{width = clay.SizingGrow(), height = clay.SizingGrow()},
		},
		backgroundColor = clay.Color{20, 20, 30, 255},
	},
	) {
		if UI(ID("mapselect_title_anchor"))(
		clay.ElementDeclaration {
			floating = clay.FloatingElementConfig {
				attachTo = clay.FloatingAttachToElement.Root,
				attachment = clay.FloatingAttachPoints {
					element = clay.FloatingAttachPointType.CenterCenter,
					parent = clay.FloatingAttachPointType.CenterTop,
				},
				offset = {0, GAME_HEIGHT * 0.15},
				zIndex = 1,
			},
		},
		) {
			clay.Text(
				"MAP SELECT",
				clay.TextElementConfig {
					fontId = 0,
					fontSize = 144,
					textColor = clay.Color{255, 255, 255, 255},
				},
			)
		}

		if UI(ID("mapselect_list_anchor"))(
		clay.ElementDeclaration {
			floating = clay.FloatingElementConfig {
				attachTo = clay.FloatingAttachToElement.Root,
				attachment = clay.FloatingAttachPoints {
					element = clay.FloatingAttachPointType.CenterCenter,
					parent = clay.FloatingAttachPointType.CenterTop,
				},
				offset = {0, GAME_HEIGHT * 0.5},
				zIndex = 1,
			},
		},
		) {
			if UI(ID("map_list"))(
			clay.ElementDeclaration {
				layout = clay.LayoutConfig {
					layoutDirection = .LeftToRight,
					childGap = 64,
					sizing = clay.Sizing {
						width = clay.SizingFixed(GAME_WIDTH),
						height = clay.SizingFixed(880),
					},
					childAlignment = {x = .Left, y = .Center},
					padding = clay.Padding{top = 40, bottom = 40, left = 40, right = 40},
				},
				clip = clay.ClipElementConfig {
					horizontal = true,
					childOffset = clay.GetScrollOffset(),
				},
			},
			) {
				for item, i in game.levels {
					hovered := clay.Hovered()

					if UI(clay.ID("MapCard", u32(i)))(
					clay.ElementDeclaration {
						layout = clay.LayoutConfig {
							layoutDirection = .TopToBottom,
							sizing = clay.Sizing {
								width = clay.SizingFixed(760),
								height = clay.SizingFixed(820),
							},
							childAlignment = {x = .Center, y = .Center},
							padding = clay.Padding{top = 36, bottom = 36, left = 36, right = 36},
							childGap = 28,
						},
						backgroundColor = hovered ? clay.Color{80, 80, 100, 255} : clay.Color{45, 45, 58, 255},
						cornerRadius = clay.CornerRadius{12, 12, 12, 12},
					},
					) {
						if clay.Hovered() && rl.IsMouseButtonPressed(.LEFT) {
							game.lvl_idx = i
							game.play_state = .Playing
						}

						if UI(clay.ID("MapThumb", u32(i)))(
						clay.ElementDeclaration {
							layout = clay.LayoutConfig {
								sizing = clay.Sizing {
									width = clay.SizingFixed(680),
									height = clay.SizingFixed(680),
								},
							},
							image = clay.ImageElementConfig{imageData = &game.levels[i].thumb},
							cornerRadius = clay.CornerRadius{10, 10, 10, 10},
						},
						) {}

						clay.Text(
							fmt.tprintf("MAP %d", i),
							clay.TextElementConfig {
								fontId = 0,
								fontSize = 40,
								textColor = clay.Color{255, 255, 255, 255},
							},
						)
					}
				}
			}
		}
	}
}

ui_hud :: proc(game: ^Game) {
	if UI(ID("hudroot"))(clay.ElementDeclaration{}) {}
}

ui_dim :: proc(game: ^Game) {
	if UI(ID("dimoverlay"))(
	clay.ElementDeclaration {
		layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()}},
		floating = {
			attachTo = .Root,
			attachment = {element = .LeftTop, parent = .LeftTop},
			zIndex = 999,
		},
		backgroundColor = {0, 0, 0, 100},
	},
	) {}
}

ui_pause_menu :: proc(game: ^Game) {}

ui_game_over :: proc(game: ^Game) {}


image_button :: proc(id: clay.ElementId, tex: ^rl.Texture2D, width, height: f32) -> bool {
	clicked := false

	if UI(id)(
	clay.ElementDeclaration {
		layout = clay.LayoutConfig {
			sizing = clay.Sizing {
				width = clay.SizingFixed(width),
				height = clay.SizingFixed(height),
			},
		},
		image = clay.ImageElementConfig{imageData = tex},
	},
	) {
		if clay.Hovered() && rl.IsMouseButtonPressed(.LEFT) {
			clicked = true
		}
	}

	return clicked
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
		f32(animation_obj.tile_w),
		f32(animation_obj.tile_h),
	}
}
