package main

import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

GAME_WIDTH :: 1200
GAME_HEIGHT :: 800

MOVE_ACCEL :: 2000
MAX_SPEED :: 300
FRICTION :: 1400
JUMP_VEL :: -500
GRAVITY :: 1600

Segment :: struct {
	a, b: rl.Vector2,
}

arena_segments :: []Segment {
	{a = {0, 400}, b = {200, 400}}, // flat floor
	{a = {200, 400}, b = {350, 250}}, // slope up
	{a = {350, 250}, b = {600, 250}}, // flat platform
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
	center: rl.Vector2,
	vel:    rl.Vector2,
	radius: f32,
}

get_move_dir :: proc() -> f32 {
	dir: f32 = 0
	if rl.IsKeyDown(.LEFT) do dir -= 1
	if rl.IsKeyDown(.RIGHT) do dir += 1
	return dir
}

update_entity :: proc(e: ^Entity, dt: f32) {
	dir := get_move_dir()
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

	for seg in arena_segments {
		resolve_circ_seg(e, seg)
	}
}

draw_entity :: proc(e: Entity) {
	rl.DrawCircleV(e.center, e.radius, rl.BLUE)
}

draw_seg :: proc(seg: Segment) {
	rl.DrawLineEx(seg.a, seg.b, 4, rl.BLACK)
}

draw_segs :: proc(segs: []Segment) {
	for seg in segs {
		draw_seg(seg)
	}
}

p1 := Entity {
	center = {300, 100},
	vel    = 0,
	radius = 30,
}

main :: proc() {
	rl.InitWindow(GAME_WIDTH, GAME_HEIGHT, "raylib!")

	target := rl.LoadRenderTexture(GAME_WIDTH, GAME_HEIGHT)

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()
		update_entity(&p1, dt)

		rl.BeginTextureMode(target)
		rl.ClearBackground(rl.WHITE)
		draw_segs(arena_segments)
		draw_entity(p1)
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
