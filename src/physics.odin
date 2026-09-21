package tag2p5

import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

p1_movement :: proc(self: ^Player, game: ^Game) -> (dir: f32, jump: bool) {
	dir = 0
	if rl.IsKeyDown(.A) do dir -= 1
	if rl.IsKeyDown(.D) do dir += 1
	return dir, rl.IsKeyDown(.W)
}

p2_movement :: proc(self: ^Player, game: ^Game) -> (dir: f32, jump: bool) {
	dir = 0
	if rl.IsKeyDown(.LEFT) do dir -= 1
	if rl.IsKeyDown(.RIGHT) do dir += 1
	return dir, rl.IsKeyDown(.UP)
}

ai_callback :: proc(self: ^Player, game: ^Game) -> (dir: f32, jump: bool) {
	t := game.levels[game.lvl_idx].game_time

	seed := f32(self.pid) * 1.7
	dir = math.sin(t * 0.6 + seed)
	h := math.sin(t * 13.37 + seed * 91.0) * 43758.5453
	h = h - math.floor(h)

	jump = h < 0.02

	return dir, jump
}

@(private = "file")
project :: #force_inline proc "contextless" (p, a, b: Vector2) -> Vector2 {
	ab := b - a
	t := linalg.dot(p - a, ab) / linalg.dot(ab, ab)
	t = clamp(t, 0, 1)
	return a + ab * t
}

@(private = "file")
resolve_circ_seg :: proc "contextless" (e: ^Player, seg: Segment) -> (hit: bool, normal: Vector2) {
	if !rl.CheckCollisionCircleRec(e.center, e.radius, seg.bound) {
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

update_entity :: proc(game: ^Game, e: ^Player, dt: f32) {
	arena := game.levels[game.lvl_idx].arena.segments
	movement_callback := ai_callback

	if e.pid == 0 {
		movement_callback = p1_movement
	} else if e.pid == 1 {
		movement_callback = p2_movement
	}

	dir, jump := movement_callback(e, game)

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
		pitch := rand.float32_range(0.8, 1.2)
		volume := rand.float32_range(1, 1.1) * 2

		play_sound(game, .Jump, pitch, volume)
		e.vel.y = -JUMP_VEL
		e.grounded = false
		e.coyote_time = 0
	}

	for &spring in game.levels[game.lvl_idx].springs {
		if aabb_circ(e.center, e.radius, spring.collidor) && spring.refresh < 0 {
			e.vel.y = -spring.force

			pitch := rand.float32_range(0.8, 1) * 0.8
			volume := rand.float32_range(1, 1.1) * 2.5

			play_sound(game, .Jump, pitch, volume)

			spring.refresh = SPRING_LFT
		}
		spring.refresh -= dt
	}

	if e.vel.x < 0 {
		e.orientation = -1
	} else if e.vel.x > 0 {
		e.orientation = 1
	}
}

@(private = "file")
aabb :: proc "contextless" (a, b: Aabb) -> bool {
	return rl.CheckCollisionRecs(a, b)
}

@(private = "file")
aabb_pt :: proc "contextless" (p: rl.Vector2, r: Aabb) -> bool {
	return rl.CheckCollisionPointRec(p, r)
}

@(private = "file")
aabb_circ :: proc "contextless" (center: rl.Vector2, radius: f32, r: Aabb) -> bool {
	return rl.CheckCollisionCircleRec(center, radius, r)
}

@(private = "file")
entity_tagging :: proc(e1, e2: ^Player) -> bool {
	diff := e1.center - e2.center
	dist := linalg.length(diff)
	min_dist := e1.radius + e2.radius
	return dist < min_dist
}

resolve_entity_tagging :: proc(game: ^Game, dt: f32) {
	level := &game.levels[game.lvl_idx]
	level.last_tag -= dt
	if level.last_tag > 0 {
		return
	}

	for i in 0 ..< len(level.players) {
		for j in i + 1 ..< len(level.players) {
			if entity_tagging(&level.players[i], &level.players[j]) {
				resolve_tag(&level.players[i], &level.players[j], game)
				return
			}
		}
	}
}

@(private = "file")
resolve_tag :: proc(e1, e2: ^Player, game: ^Game) {
	game.levels[game.lvl_idx].last_tag = TAG_IMMUNITY
	e1.tagged, e2.tagged = e2.tagged, e1.tagged
}
