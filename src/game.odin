package tag2p5

import clay "clay-odin"
import "core:c"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:os"
import "core:strconv"
import "core:strings"
import "renderer"
import rl "vendor:raylib"

new_game :: proc(lvl_idx: int) -> Game {
	levels := make([dynamic]Level)
	arenas_dir := rl.LoadDirectoryFiles(ASSET_DIR + "arenas")
	for path in arenas_dir.paths[:arenas_dir.count] {
		parts := strings.split(string(path), "/")
		dirname := parts[len(parts) - 1]
		append(&levels, create_level(dirname))
		delete(parts)
	}
	return create_game(levels[:], lvl_idx)
}

restart_game :: proc(game: ^Game, idx: int) {
	lvl_idx := idx
	free_game(game)
	game^ = new_game(lvl_idx)
	game.play_state = .Playing
}

update_game :: proc(game: ^Game, dt: f32) {
	if game.play_state != .Playing {return}
	for &player in game.levels[game.lvl_idx].players {
		update_entity(game, &player, dt)
	}

	resolve_entity_tagging(game, dt)

	lvl := &game.levels[game.lvl_idx]
	arena_w := f32(lvl.arena.tilemap.width) * f32(lvl.arena.tilemap.tile_width)
	arena_h := f32(lvl.arena.tilemap.height) * f32(lvl.arena.tilemap.tile_height)
	update_camera(&lvl.gc, lvl.players, GAME_WIDTH, GAME_HEIGHT, dt, arena_w, arena_h)

	game.levels[game.lvl_idx].game_time -= dt
	if game.levels[game.lvl_idx].game_time < 0.8 {
		game.levels[game.lvl_idx].game_time = 0
		game.play_state = .GameOver
	}
}

update_camera :: proc(
	gc: ^rl.Camera2D,
	players: []Player,
	screen_w, screen_h, dt: f32,
	arena_w, arena_h: f32,
) {
	if len(players) == 0 do return

	min_x := players[0].center.x
	max_x := players[0].center.x
	min_y := players[0].center.y
	max_y := players[0].center.y

	for i in 1 ..< len(players) {
		p := players[i].center
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)
	}

	min_x -= CAM_PADDING_X
	max_x += CAM_PADDING_X
	min_y -= CAM_PADDING_Y
	max_y += CAM_PADDING_Y

	bounds_w := max_x - min_x
	bounds_h := max_y - min_y

	zoom_x := screen_w / bounds_w
	zoom_y := screen_h / bounds_h
	gc.zoom = clamp(min(zoom_x, zoom_y), 0, MAX_ZOOM)

	half_view_w := (screen_w / 2) / gc.zoom
	half_view_h := (screen_h / 2) / gc.zoom

	desired := Vector2{min_x + bounds_w / 2, min_y + bounds_h / 2}
	t_pos := clamp(CAM_FOLLOW_SPEED * dt, 0, 1)
	gc.target = linalg.lerp(gc.target, desired, t_pos)

	for player in players {
		if player.center.x - half_view_w > gc.target.x {
			gc.target.x = player.center.x - half_view_w
		}
		if player.center.x + half_view_w < gc.target.x {
			gc.target.x = player.center.x + half_view_w
		}
		if player.center.y - half_view_h > gc.target.y {
			gc.target.y = player.center.y - half_view_h
		}
		if player.center.y + half_view_h < gc.target.y {
			gc.target.y = player.center.y + half_view_h
		}
	}

	// Side walls: hard bound on both edges.
	if arena_w <= 2 * half_view_w {
		gc.target.x = arena_w / 2
	} else {
		gc.target.x = clamp(gc.target.x, half_view_w, arena_w - half_view_w)
	}

	// Floor: hard bound on the bottom only. No lower clamp on target.y,
	// so the camera is free to pan above the arena top when needed to
	// keep a player in view.
	gc.target.y = min(gc.target.y, arena_h - half_view_h)

	gc.offset = {screen_w / 2, screen_h / 2}
}

free_game :: proc(game: ^Game) {
	if len(game.levels) == 0 {return}

	for &lvl in game.levels {
		free_arena(&lvl.arena)

		for p in lvl.players {
			rl.UnloadTexture(p.tex)
			rl.UnloadTexture(p.triangle_tex)
		}
		delete(lvl.players)
	}

	delete(game.levels)
	rl.UnloadRenderTexture(game.target)
}

@(private = "file")
create_level :: proc(dirname: string) -> Level {
	arena_conf_path := fmt.aprintf("%sarenas/%s/%s.txt", ASSET_DIR, dirname, dirname)
	arena_buf := make([]u8, ARENA_BUF_SIZE)
	a: mem.Arena
	mem.arena_init(&a, arena_buf)
	alloc := mem.arena_allocator(&a)

	arena: Arena = {}

	old_alloc := context.allocator
	context.allocator = alloc

	arena_conf, err := os.read_entire_file(arena_conf_path, alloc)
	if err != nil {fmt.panicf("failed to load arena config! %v %v", arena_conf_path, err)}

	lines, errstr := strings.split_lines(string(arena_conf))
	if errstr != nil {fmt.panicf("allocator error! %v", errstr)}

	layers := make([dynamic]ParallaxLayer, alloc)
	pspawns := make([dynamic]Vector2, alloc)
	thumb: rl.Texture2D
	title: string

	filler_tex := rl.LoadTexture(ASSET_DIR + "filler.png")

	for line in lines {
		words := strings.fields(line)
		if len(words) == 0 {
			continue
		}
		term := strings.split(words[0], ":")[0]
		switch term {
		case "name":
			title = strings.join(words[1:], " ")

		case "layer":
			assert(len(words) == 3)
			val32, ok32 := strconv.parse_f32(words[2])
			if !ok32 {
				fmt.panicf("failed to parse float factor for layer %s", words[1])
			}
			append(
				&layers,
				ParallaxLayer {
					tex = rl.LoadTexture(
						fmt.ctprintf("%sarenas/%s/%s", ASSET_DIR, dirname, words[1]),
					),
					factor = val32,
				},
			)

		case "tilemap":
			assert(len(words) == 2)
			tmap, errt := load_tilemap(
				fmt.aprintf("%sarenas/%s/%s", ASSET_DIR, dirname, words[1]),
				dirname,
				alloc,
			)
			if errt != nil {
				fmt.panicf("an error occured loading the tilemap %w", errt)
			}
			arena.tilemap = tmap
			arena.segments = generate_segments(tmap, alloc)

		case "player":
			assert(len(words) == 3)
			xf32, okx32 := strconv.parse_f32(words[1])
			yf32, oky32 := strconv.parse_f32(words[2])
			if !okx32 || !oky32 {
				fmt.panicf("failed to parse pspawns")
			}
			vec := Vector2{xf32, yf32}
			append(&pspawns, vec)

		case "thumb":
			assert(len(words) == 2)
			thumbpth := fmt.ctprintf("%sarenas/%s/%s", ASSET_DIR, dirname, words[1])
			thumb = rl.LoadTexture(thumbpth)

		case:
			fmt.panicf("unknown arena config key: %s", term)
		}
	}

	append(&layers, ParallaxLayer{tex = filler_tex, factor = 0})

	context.allocator = old_alloc

	arena.bg_layers = layers[:]
	arena.arena_buf = arena_buf
	arena.memarena = a

	cam := rl.Camera2D {
		zoom   = 1,
		offset = {GAME_WIDTH / 2, GAME_HEIGHT / 2},
	}

	players := make([]Player, len(pspawns))
	for player_spawn, i in pspawns {
		pid := i
		ptex := rl.LoadTexture(fmt.ctprintf("%splayer_%d.png", ASSET_DIR, pid))
		ttex := rl.LoadTexture(fmt.ctprintf("%striangle_%d.png", ASSET_DIR, pid))

		players[i] = Player {
			center       = player_spawn,
			vel          = {0, 0},
			radius       = PLAYER_RAD,
			tagged       = i == 0,
			animation    = {},
			tex          = ptex,
			pid          = uint(pid),
			triangle_tex = ttex,
			rotation     = 0,
			grounded     = false,
		}
	}

	delete(arena_conf_path)

	return Level {
		gc = cam,
		arena = arena,
		players = players[:],
		last_tag = 0,
		game_time = GAME_TIME,
		thumb = thumb,
		title = title,
	}
}

free_arena :: proc(arena: ^Arena) {
	rl.UnloadTexture(arena.tilemap.tileset_tex)
	for layer in arena.bg_layers {
		rl.UnloadTexture(layer.tex)
	}
	delete(arena.arena_buf)
}

create_game :: proc(levels: []Level, lvl_idx: int, game_time: f32 = GAME_TIME) -> Game {
	restart_tex := rl.LoadTexture(ASSET_DIR + "restart.png")
	play_tex := rl.LoadTexture(ASSET_DIR + "play.png")
	pause_tex := rl.LoadTexture(ASSET_DIR + "pause.png")
	mm_tex := rl.LoadTexture(ASSET_DIR + "menu.png")
	cursor_tex := rl.LoadTexture(ASSET_DIR + "cursor.png")

	assets := GuiAssets {
		play_button_tex    = play_tex,
		quit_button_tex    = mm_tex,
		pause_button_tex   = pause_tex,
		menu_button_tex    = mm_tex,
		restart_button_tex = restart_tex,
		cursor_tex         = cursor_tex,
	}

	game := Game {
		play_state          = .MainMenu,
		levels              = levels,
		assets              = assets,
		target              = rl.LoadRenderTexture(GAME_WIDTH, GAME_HEIGHT),
		lvl_idx             = lvl_idx,
		pending_restart_idx = -1,
	}

	return game
}

@(private = "file")
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


@(private = "file")
draw_entity :: proc(e: Player) {
	sign: f32 = math.sign(e.orientation + 0.002)
	// this is to make sure sign isnt 0, becuase
	// e.orientation is unlikley to ever be -0.002

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
	}
}

@(private = "file")
draw_triangle :: proc(e: Player) {
	rl.DrawTexture(
		e.triangle_tex,
		i32(e.center.x) - (e.triangle_tex.width / 2) + 1,
		i32(e.center.y) - i32(e.radius * 2.2),
		rl.WHITE,
	)
}

@(private = "file")
draw_segs :: proc(segs: []Segment) {
	for seg in segs {
		randomColor := rl.Color {
			u8(rl.GetRandomValue(0, 255)),
			u8(rl.GetRandomValue(0, 255)),
			u8(rl.GetRandomValue(0, 255)),
			255,
		}
		rl.DrawLineEx(seg.a, seg.b, 1, randomColor)
	}
}

render_game :: proc(
	game: ^Game,
	mpos: Vector2,
	target: rl.RenderTexture2D,
	ui_commands: clay.ClayArray(clay.RenderCommand),
) {
	rl.BeginTextureMode(target)
	defer rl.EndTextureMode()
	rl.ClearBackground(rl.WHITE)

	if game.play_state != .MainMenu && game.play_state != .MapSel {
		rl.ClearBackground(SKY_COLOR)
		draw_parallax_layers(game^)

		rl.BeginMode2D(game.levels[game.lvl_idx].gc)
		// draw_segs(game.levels[game.lvl_idx].arena.segments)
		draw_tilemap(game.levels[game.lvl_idx].arena.tilemap)

		for &player in game.levels[game.lvl_idx].players {
			draw_entity(player)
		}
		rl.EndMode2D()
	}

	if game.play_state == .GameOver {
		// TODO: make the loser be drawn on game over
	}

	commands := ui_commands
	renderer.clay_raylib_render(&commands)

	rl.DrawTexturePro(
		game.assets.cursor_tex,
		{0, 0, f32(game.assets.cursor_tex.width), f32(game.assets.cursor_tex.height)},
		{mpos.x, mpos.y, 64, 64},
		{0, 0},
		0,
		rl.WHITE,
	)
}

@(private = "file")
draw_parallax_layers :: proc(game: Game) {
	for layer in game.levels[game.lvl_idx].arena.bg_layers {
		tex_w := f32(layer.tex.width)
		tex_h := f32(layer.tex.height)

		scale := f32(GAME_HEIGHT) / tex_h
		draw_w := tex_w * scale
		draw_h := tex_h * scale

		lcam := rl.Camera2D {
			offset = {f32(GAME_WIDTH) / 2, f32(GAME_HEIGHT) / 2},
			target = {game.levels[game.lvl_idx].gc.target.x * layer.factor, 0},
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

build_ui :: proc(game: ^Game, dt: f32) -> clay.ClayArray(clay.RenderCommand) {
	clay.BeginLayout()
	// clay.SetDebugModeEnabled(true)
	switch game.play_state {
	case .MainMenu:
		ui_main_menu(game)
	case .MapSel:
		ui_map_select(game)
	case .Playing:
		ui_hud(game)
	case .Paused:
		ui_hud(game)
		ui_pause_menu(game)
	case .GameOver:
		ui_hud(game)
		ui_game_over(game)
	}

	return clay.EndLayout(dt)
}

@(private = "file")
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
				if image_button(ID("PlaceholderButton"), &game.assets.quit_button_tex, 600, 120) {
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

@(private = "file")
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
						backgroundColor = clay.Hovered() ? clay.Color{80, 80, 100, 255} : clay.Color{45, 45, 58, 255},
						cornerRadius = clay.CornerRadius{12, 12, 12, 12},
					},
					) {
						if clay.Hovered() && rl.IsMouseButtonPressed(.LEFT) {
							// restart_game(game)
							// game.lvl_idx = i
							// game.play_state = .Playing
							game.pending_restart_idx = i
							// fmt.println(i)
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
							game.levels[i].title,
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

@(private = "file")
ui_hud :: proc(game: ^Game) {
	if UI(ID("hud_root"))(
	clay.ElementDeclaration {
		layout = clay.LayoutConfig {
			sizing = clay.Sizing{width = clay.SizingGrow(), height = clay.SizingGrow()},
			layoutDirection = .TopToBottom,
			childAlignment = clay.ChildAlignment{x = .Center},
			padding = clay.Padding{top = 24, bottom = 24},
		},
		floating = clay.FloatingElementConfig {
			attachTo = .Root,
			attachment = {element = .LeftTop, parent = .LeftTop},
			zIndex = 777,
		},
	},
	) {
		t := game.levels[game.lvl_idx].game_time
		text_color: clay.Color

		if t < 10 && i32(t) % 2 == 0 {
			text_color = clay.Color{255, 40, 40, 255}
		} else {
			text_color = clay.Color{20, 20, 30, 255}
		}

		if UI(ID("timer"))(
		clay.ElementDeclaration{layout = clay.LayoutConfig{childAlignment = {x = .Center}}},
		) {
			clay.Text(
				fmt.tprintf("%d", i32(t)),
				clay.TextElementConfig{fontId = 0, fontSize = 96, textColor = text_color},
			)
		}

		if UI(ID("hud_mid_spacer"))(
		clay.ElementDeclaration {
			layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()}},
		},
		) {}

		if image_button(ID("pause_button"), &game.assets.pause_button_tex, 96, 96) {
			game.play_state = .Paused
		}
	}
}

@(private = "file")
ui_pause_menu :: proc(game: ^Game) {
	if UI(ID("pause_overlay"))(
	clay.ElementDeclaration {
		layout = clay.LayoutConfig {
			sizing = clay.Sizing{width = clay.SizingGrow(), height = clay.SizingGrow()},
		},
		backgroundColor = clay.Color{0, 0, 0, 160},
		floating = clay.FloatingElementConfig {
			attachTo = .Root,
			attachment = {element = .LeftTop, parent = .LeftTop},
			zIndex = 900,
		},
	},
	) {
		if UI(ID("pause_root"))(
		clay.ElementDeclaration {
			layout = clay.LayoutConfig {
				sizing = clay.Sizing{width = clay.SizingGrow(), height = clay.SizingGrow()},
				layoutDirection = .TopToBottom,
				childAlignment = {x = .Center, y = .Center},
				childGap = 20,
			},
		},
		) {
			clay.Text(
				"PAUSED",
				clay.TextElementConfig {
					fontId = 0,
					fontSize = 144,
					textColor = {255, 255, 255, 255},
				},
			)

			if image_button(
				ID("resume_button"),
				&game.assets.play_button_tex,
				260 * 1.5,
				60 * 1.5,
			) {
				game.play_state = .Playing
			}

			if image_button(
				ID("resstart_button"),
				&game.assets.restart_button_tex,
				260 * 1.5,
				60 * 1.5,
			) {
				restart_game(game, game.lvl_idx)
			}

			if image_button(ID("quit_button"), &game.assets.quit_button_tex, 260 * 1.5, 60 * 1.5) {
				game.play_state = .MainMenu
			}
		}
	}
}

@(private = "file")
ui_game_over :: proc(game: ^Game) {
	if UI(ID("gameover_overlay"))(
	clay.ElementDeclaration {
		layout = clay.LayoutConfig {
			sizing = clay.Sizing{width = clay.SizingGrow(), height = clay.SizingGrow()},
		},
		backgroundColor = clay.Color{0, 0, 0, 160},
		floating = clay.FloatingElementConfig {
			attachTo = .Root,
			attachment = {element = .LeftTop, parent = .LeftTop},
			zIndex = 900,
		},
	},
	) {
		if UI(ID("gameover_root"))(
		clay.ElementDeclaration {
			layout = clay.LayoutConfig {
				sizing = clay.Sizing{width = clay.SizingGrow(), height = clay.SizingGrow()},
				layoutDirection = .TopToBottom,
				childAlignment = {x = .Center, y = .Center},
				childGap = 20,
			},
		},
		) {
			clay.Text(
				"game over!",
				clay.TextElementConfig {
					fontId = 0,
					fontSize = 144,
					textColor = {255, 255, 255, 255},
				},
			)

			if image_button(
				ID("restart_button"),
				&game.assets.restart_button_tex,
				260 * 1.5,
				60 * 1.5,
			) {
				restart_game(game, game.lvl_idx)
			}

			if image_button(
				ID("main_menu_button"),
				&game.assets.menu_button_tex,
				260 * 1.5,
				60 * 1.5,
			) {
				game.play_state = .MainMenu
			}
		}
	}
}

image_button :: proc(id: clay.ElementId, tex: ^Texture2D, width, height: f32) -> bool {
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

update_animation :: proc {
	update_animation_a,
	update_animation_e,
}

update_animation_e :: proc(entity: ^Player, dt: f32) {
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

handle_keypresses :: proc(game: ^Game) {
	if rl.IsKeyPressed(.ESCAPE) {
		on_esc(game)
	} else if rl.IsKeyPressed(.ENTER) {
		on_enter(game)
	}
}

@(private = "file")
on_esc :: proc(game: ^Game) {
	switch game.play_state {
	case .MainMenu:
		game.suicidal = true

	case .MapSel:
		game.play_state = .MainMenu

	case .Playing:
		game.play_state = .Paused

	case .Paused, .GameOver:
		game.play_state = .MainMenu
	}
}

@(private = "file")
on_enter :: proc(game: ^Game) {
	#partial switch game.play_state {
	case .MainMenu:
		game.play_state = .MapSel

	case .Paused:
		game.play_state = .Playing

	case .GameOver:
		restart_game(game, game.lvl_idx)

	case:
		break
	}
}
