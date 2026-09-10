package tag2p5

import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

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

// TODO: improve ai
ai_callback :: proc() -> (dir: f32, jump: bool) {
	dir = f32(rand.uint32_max(5)) - 2
	jump_c := rand.uint32_max(1000)
	jump = jump_c > 998
	return
}

project :: #force_inline proc "contextless" (p, a, b: Vector2) -> Vector2 {
	ab := b - a
	t := linalg.dot(p - a, ab) / linalg.dot(ab, ab)
	t = clamp(t, 0, 1)
	return a + ab * t
}

resolve_circ_seg :: proc "contextless" (e: ^Entity, seg: Segment) -> (hit: bool, normal: Vector2) {
	if !rl.CheckCollisionCircleRec(e.center, e.radius, seg.aabb) {
		return false, {}
	}

	closest := project(e.center, seg.a, seg.b)
	diff := e.center - closest

	dist_sq := diff.x * diff.x + diff.y * diff.y
	radius_sq := e.radius * e.radius

	if dist_sq >= radius_sq || dist_sq <= 0 {
		return false, {}
	}

	dist := math.sqrt(dist_sq)
	inv_dist := 1.0 / dist
	n := diff * inv_dist
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

update_entity :: proc(arena: []Segment, e: ^Entity, dt: f32) {
	update_animation(e, dt)

	dir, jump := e.movement_callback()

	target_x := dir * MOVE_SPEED
	t := clamp(DECAY_RATE * dt, 0, 1)
	e.vel.x = linalg.lerp(e.vel.x, target_x, t)

	if !e.grounded {
		e.vel.y += GRAVITY * dt
	}

	max_step_dist := e.radius * 0.5
	total_move := linalg.length(e.vel * dt)
	num_steps := max(int(math.ceil(total_move / max_step_dist)), 1)
	step_dt := dt / f32(num_steps)

	e.grounded = false
	for i in 0 ..< num_steps {
		e.center += e.vel * step_dt

		for seg in arena {
			hit, normal := resolve_circ_seg(e, seg)
			if hit && normal.y < -MAX_WALKABLE_SLOPE {
				e.grounded = true
				e.vel.y = 0
			}
		}
	}

	if e.grounded {
		e.coyote_time = COYOTE_TIME
	}

	e.rotation += math.to_degrees((e.vel.x * dt) / e.radius)
	e.coyote_time -= dt

	if jump && e.coyote_time > 0 {
		e.vel.y = -JUMP_VEL
		e.grounded = false
		e.coyote_time = 0
	}
}

aabb :: proc(a, b: Aabb) -> bool {
	return rl.CheckCollisionRecs(a, b)
}

aabb_pt :: proc(p: rl.Vector2, r: Aabb) -> bool {
	return rl.CheckCollisionPointRec(p, r)
}

aabb_circ :: proc(center: rl.Vector2, radius: f32, r: Aabb) -> bool {
	return rl.CheckCollisionCircleRec(center, radius, r)
}


entity_tagging :: proc(e1, e2: ^Entity) -> bool {
	diff := e1.center - e2.center
	dist := linalg.length(diff)
	min_dist := e1.radius + e2.radius
	return dist < min_dist
}

// NOTE: last man standing mode?
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
