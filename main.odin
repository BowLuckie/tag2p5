package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

GAME_WIDTH :: 1200
GAME_HEIGHT :: 800

MIN_ZOOM :: 0.1
MAX_ZOOM :: CAM_PADDING
CAM_PADDING :: 300
CAM_FOLLOW_SPEED :: 8.0
CAM_ZOOM_SPEED :: 6.0

MAX_WALKABLE_SLOPE :: 0.7
MOVE_SPEED :: 430
DECAY_RATE :: 10
GRAVITY :: 2000
JUMP_VEL :: 600
GROUND_SNAP_DIST :: 4
COYOTE_TIME :: 0.1

TAG_IMMUNITY :: 1
GAME_TIME :: 1

Vector2 :: rl.Vector2

Segment :: struct {
	a, b: Vector2,
}

Entity :: struct {
	center:            Vector2,
	vel:               Vector2,
	radius:            f32,
	color:             rl.Color,
	grounded:          bool,
	coyote_time:       f32,
	tagged:            bool,
	movement_callback: proc() -> (dir: f32, jump: bool),
}

p1_movement :: proc() -> (dir: f32, jump: bool) {
	dir = 0
	if rl.IsKeyDown(.A) do dir -= 1
	if rl.IsKeyDown(.D) do dir += 1
	return dir, rl.IsKeyDown(.W)
}

p2_movement :: proc() -> (dir: f32, jump: bool) {
	dir = 0
	if rl.IsKeyDown(.LEFT) do dir -= 1
	if rl.IsKeyDown(.RIGHT) do dir += 1
	return dir, rl.IsKeyDown(.UP)
}

ai_callback :: proc() -> (dir: f32, jump: bool) {
	dir = f32(rand.uint32_max(5)) - 2
	jump_c := rand.uint32_max(1000)
	jump = jump_c > 998
	return
}

project :: proc(p, a, b: Vector2) -> Vector2 {
	ab := b - a
	t := linalg.dot(p - a, ab) / linalg.dot(ab, ab)
	t = clamp(t, 0, 1)
	return a + ab * t
}

resolve_circ_seg :: proc(e: ^Entity, seg: Segment) -> (hit: bool, normal: Vector2) {
	closest := project(e.center, seg.a, seg.b)
	diff := e.center - closest
	dist := linalg.length(diff)

	if dist < e.radius && dist > 0 {
		n := diff / dist
		penetration := e.radius - dist

		if n.y < -MAX_WALKABLE_SLOPE {
			e.center.y += n.y * penetration
			if e.vel.y > 0 {
				e.vel.y = 0
			}
		} else {
			e.center += n * penetration
			vel_into_surface := linalg.dot(e.vel, n)
			if vel_into_surface < 0 {
				e.vel -= n * vel_into_surface
			}
		}
		return true, n
	}
	return false, {}
}

update_entity :: proc(arena: []Segment, e: ^Entity, dt: f32) {
	dir, jump := e.movement_callback()

	target_x := dir * MOVE_SPEED
	t := clamp(DECAY_RATE * dt, 0, 1)
	e.vel.x = linalg.lerp(e.vel.x, target_x, t)

	if !e.grounded {
		e.vel.y += GRAVITY * dt
	}

	e.center += e.vel * dt

	e.grounded = false
	for seg in arena {
		hit, normal := resolve_circ_seg(e, seg)
		if hit && normal.y < -MAX_WALKABLE_SLOPE {
			e.grounded = true
			e.vel.y = 0
		}
	}

	if e.grounded {
		e.coyote_time = COYOTE_TIME
	} else {
		e.coyote_time -= dt
	}

	if jump && e.coyote_time > 0 {
		e.vel.y = -JUMP_VEL
		e.grounded = false
		e.coyote_time = 0
	}
}

draw_entity :: proc(e: Entity) {
	rl.DrawCircleV(e.center, e.radius, e.color)
	if e.tagged {
		gap: f32 = e.radius * 0.3
		tri_height: f32 = e.radius * 0.8
		tri_width: f32 = e.radius

		base_y := e.center.y - e.radius - gap - tri_height
		tip_y := base_y + tri_height

		tip := Vector2{e.center.x, tip_y}
		left := Vector2{e.center.x - tri_width / 2, base_y}
		right := Vector2{e.center.x + tri_width / 2, base_y}

		rl.DrawTriangle(tip, right, left, e.color)
	}
}

draw_seg :: proc(seg: Segment) {
	rl.DrawLineEx(seg.a, seg.b, 4, rl.BLACK)
}

draw_segs :: proc(segs: []Segment) {
	for seg in segs {
		draw_seg(seg)
	}
}

GameCamera :: struct {
	cam:      rl.Camera2D,
	min_zoom: f32,
	max_zoom: f32,
	padding:  f32,
}

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

entity_tagging :: proc(e1, e2: ^Entity) -> bool {
	diff := e1.center - e2.center
	dist := linalg.length(diff)
	min_dist := e1.radius + e2.radius
	return dist < min_dist
}

resolve_entity_tagging :: proc(game: ^Game, dt: f32) {
	game.last_tag -= dt
	if game.last_tag > 0 {
		return
	}

	for i in 0 ..< len(game.players) {
		for j in i + 1 ..< len(game.players) {
			if entity_tagging(&game.players[i], &game.players[j]) {
				resolve_tag(&game.players[i], &game.players[j], game)
				return
			}
		}
	}
}

resolve_tag :: proc(e1, e2: ^Entity, game: ^Game) {
	game.last_tag = TAG_IMMUNITY
	e1.tagged, e2.tagged = e2.tagged, e1.tagged
}

GameMode :: enum {
	Normal,
}

PlayState :: enum {
	MainMenu,
	Playing,
	Paused,
	GameOver,
}

Game :: struct {
	gc:            GameCamera,
	players:       []Entity,
	arena_collide: []Segment,
	last_tag:      f32,
	mode:          GameMode,
	game_time:     f32,
	play_state:    PlayState,
	buttons:       []Button,
}

free_game :: proc(game: ^Game) {
	delete(game.players)
	for btn in game.buttons {
		rl.UnloadTexture(btn.glyph)
	}
	delete(game.buttons)
}

Button :: struct {
	rect:     rl.Rectangle,
	glyph:    rl.Texture2D,
	states:   bit_set[PlayState],
	on_click: proc(game: ^Game),
}

is_button_clicked :: proc(button: Button, mouse_pos: Vector2) -> bool {
	return rl.CheckCollisionPointRec(mouse_pos, button.rect)
}

arena_collide := []Segment {
	{a = {0, 750}, b = {1200, 750}}, // floor
	{a = {1200, 750}, b = {1200, 50}}, // right wall
	{a = {1200, 50}, b = {0, 50}}, // ceiling
	{a = {0, 50}, b = {0, 750}}, // left wall
	{a = {100, 650}, b = {280, 650}}, // flat ledge, bottom-left
	{a = {280, 650}, b = {420, 560}}, // slope up
	{a = {420, 560}, b = {560, 560}}, // flat platform
	{a = {650, 700}, b = {800, 620}}, // slope up from floor area
	{a = {800, 620}, b = {950, 620}}, // flat platform
	{a = {300, 400}, b = {450, 320}}, // mid-height slope
	{a = {450, 320}, b = {620, 320}}, // flat platform
	{a = {620, 320}, b = {780, 400}}, // slope back down
	{a = {850, 350}, b = {1000, 350}}, // floating flat platform, upper right
	{a = {150, 250}, b = {320, 180}}, // slope near ceiling
	{a = {320, 180}, b = {480, 180}}, // flat near ceiling
	{a = {700, 200}, b = {900, 150}}, // slope up-right near ceiling
	{a = {900, 150}, b = {1050, 150}}, // flat near ceiling
}


create_test_game :: proc() -> Game {
	restart_tex := rl.LoadTexture("./static/restart.png")
	play_tex := rl.LoadTexture("./static/play.png")
	pause_tex := rl.LoadTexture("./static/pause.png")

	p1 := Entity {
		center            = {300, 100},
		vel               = 0,
		radius            = 30,
		color             = rl.BLUE,
		movement_callback = p1_movement,
		tagged            = true,
	}

	p2 := Entity {
		center            = {100, 300},
		vel               = 0,
		radius            = 30,
		color             = rl.RED,
		movement_callback = ai_callback,
		tagged            = false,
	}

	players := make([]Entity, 2)
	players[0] = p1
	players[1] = p2

	gc := GameCamera {
		cam = rl.Camera2D{zoom = 1, offset = {GAME_WIDTH / 2, GAME_HEIGHT / 2}},
		min_zoom = MIN_ZOOM,
		max_zoom = MAX_ZOOM,
		padding = CAM_PADDING,
	}


	game := Game {
		gc            = gc,
		players       = players,
		arena_collide = arena_collide,
		last_tag      = 0,
		game_time     = GAME_TIME,
		play_state    = .MainMenu,
	}

	buttons := make([]Button, 4, context.allocator)
	buttons[0] = {
		rect = {GAME_WIDTH / 2 - 200, GAME_HEIGHT * .6, 400, 120},
		glyph = play_tex,
		states = {.MainMenu},
		on_click = proc(game: ^Game) {game.play_state = .Playing},
	}

	buttons[1] = {
		rect     = {GAME_WIDTH / 2 - 200, GAME_HEIGHT * .6, 400, 120},
		glyph    = restart_tex,
		states   = {.GameOver},
		on_click = restart_game,
	}

	buttons[2] = {
		rect = {GAME_WIDTH / 2, GAME_HEIGHT * 0.9, 64, 64},
		glyph = pause_tex,
		states = {.Playing},
		on_click = proc(game: ^Game) {game.play_state = .Paused},
	}

	buttons[3] = {
		rect = {GAME_WIDTH / 2 - 200, GAME_HEIGHT * .6, 400, 120},
		glyph = play_tex,
		states = {.Paused},
		on_click = proc(game: ^Game) {game.play_state = .Playing},
	}


	game.buttons = buttons

	return game
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
		update_entity(game.arena_collide, &player, dt)
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
	draw_segs(game.arena_collide)

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

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(GAME_WIDTH, GAME_HEIGHT, "raylib!")
	game := create_test_game()

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
