package main

import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

GAME_WIDTH :: 1200
GAME_HEIGHT :: 800

MOVE_ACCEL :: 3000
MAX_SPEED :: 500
FRICTION :: 0
JUMP_VEL :: 550
GRAVITY :: 1600


Segment :: struct {
	a, b: rl.Vector2,
}

arena_segments :: []Segment {
	//  outer walls enclosed room
	{a = {0, 750}, b = {1200, 750}}, // floor
	{a = {1200, 750}, b = {1200, 50}}, // right wall
	{a = {1200, 50}, b = {0, 50}}, // ceiling
	{a = {0, 50}, b = {0, 750}}, // left wall

	// --- interior terrain (random flats & slopes) ---
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

project :: proc(p, a, b: rl.Vector2) -> rl.Vector2 {
	ab := b - a
	t := linalg.dot(p - a, ab) / linalg.dot(ab, ab)
	t = clamp(t, 0, 1)
	return a + ab * t
}

// if hit is false normal will be {}
resolve_circ_seg :: proc(e: ^Entity, seg: Segment) -> (hit: bool, normal: rl.Vector2) {
	closest := project(e.center, seg.a, seg.b)
	diff := e.center - closest
	dist := linalg.length(diff)

	if dist < e.radius && dist > 0 {
		normal := diff / dist
		penetration := e.radius - dist
		e.center += normal * penetration

		vel_along_norm := linalg.dot(e.vel, normal)
		if vel_along_norm < 0 {
			e.vel -= normal * vel_along_norm
		}

		return true, normal
	}

	return false, {}
}

Entity :: struct {
	center:            rl.Vector2,
	vel:               rl.Vector2,
	radius:            f32,
	color:             rl.Color,
	movement_callback: proc() -> f32,
}

p1_movement :: proc() -> f32 {
	dir: f32 = 0
	if rl.IsKeyDown(.A) do dir -= 1
	if rl.IsKeyDown(.D) do dir += 1
	return dir
}

p2_movement :: proc() -> f32 {
	dir: f32 = 0
	if rl.IsKeyDown(.LEFT) do dir -= 1
	if rl.IsKeyDown(.RIGHT) do dir += 1
	return dir
}

update_entity :: proc(e: ^Entity, dt: f32) {
	dir := e.movement_callback()
	e.vel.y += GRAVITY * dt

	if dir != 0 {
		e.vel.x += dir * MOVE_ACCEL * dt
	}
	e.vel.x = clamp(e.vel.x, -MAX_SPEED, MAX_SPEED)

	if e.vel.x > 0 {
		e.vel.x -= FRICTION * dt
		e.vel.x = max(e.vel.x, 0)
	} else if e.vel.x < 0 {
		e.vel.x += FRICTION * dt
		e.vel.x = min(e.vel.x, 0)
	}


	e.center += e.vel * dt

	if rl.IsKeyPressed(.UP) {
		e.vel.y = -JUMP_VEL
	}

	for seg in arena_segments {
		resolve_circ_seg(e, seg)
	}
}

draw_entity :: proc(e: Entity) {
	rl.DrawCircleV(e.center, e.radius, e.color)
}

draw_seg :: proc(seg: Segment) {
	rl.DrawLineEx(seg.a, seg.b, 4, rl.BLACK)
}

draw_segs :: proc(segs: []Segment) {
	for seg in segs {
		draw_seg(seg)
	}
}


main :: proc() {
	p1 := Entity {
		center            = {300, 100},
		vel               = 0,
		radius            = 30,
		color             = rl.BLUE,
		movement_callback = p1_movement,
	}

	p2 := Entity {
		center            = {100, 300},
		vel               = 0,
		radius            = 30,
		color             = rl.RED,
		movement_callback = p2_movement,
	}

	fmt.printf(
		"w: %d h: %d move_accel: %d max_speed: %d  FRICTION: %d JUMP_VEL: %d GRAVITY: %d",
		GAME_WIDTH,
		GAME_HEIGHT,
		MOVE_ACCEL,
		MAX_SPEED,
		FRICTION,
		JUMP_VEL,
		GRAVITY,
	)

	rl.InitWindow(GAME_WIDTH, GAME_HEIGHT, "raylib!")

	target := rl.LoadRenderTexture(GAME_WIDTH, GAME_HEIGHT)

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()
		update_entity(&p1, dt)
		update_entity(&p2, dt)

		rl.BeginTextureMode(target)
		rl.ClearBackground(rl.WHITE)
		draw_segs(arena_segments)
		draw_entity(p1)
		draw_entity(p2)
		rl.EndTextureMode()

		screen_w := f32(rl.GetScreenWidth())
		screen_h := f32(rl.GetScreenHeight())
		scale := min(screen_w / GAME_WIDTH, screen_h / GAME_HEIGHT)

		dest := rl.Rectangle {
			(screen_w - GAME_WIDTH * scale) / 2,
			(screen_h - GAME_HEIGHT * scale) / 2,
			GAME_WIDTH * scale,
			GAME_HEIGHT * scale,
		}
		src := rl.Rectangle{0, 0, GAME_WIDTH, -GAME_HEIGHT} // negative height flips render texture

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		rl.DrawTexturePro(target.texture, src, dest, {0, 0}, 0, rl.WHITE)
		rl.EndDrawing()
	}

	rl.UnloadRenderTexture(target)
	rl.CloseWindow()
}
