package tag2p5

import rl "vendor:raylib"

FADE_TIME :: 0.3

Fade_Wait :: enum {
	None,
	Overlay,
	Black,
}

Fade :: struct {
	overlay, overlay_goal: f32,
	black, black_goal:     f32,
	overlay_on:            bool,
	wait:                  Fade_Wait,
	action:                proc(game: ^Game),
}

fade_init :: proc(game: ^Game) {
	game.fade = Fade {
		black = 1,
	}
}

@(private = "file")
approach :: proc(v, goal, step: f32) -> f32 {
	if v < goal do return min(v + step, goal)
	return max(v - step, goal)
}

@(private = "file")
smooth :: proc(t: f32) -> f32 {
	return t * t * (3 - 2 * t)
}

fade_overlay_alpha :: proc(game: ^Game) -> f32 {return smooth(game.fade.overlay)}
fade_black_alpha :: proc(game: ^Game) -> f32 {return smooth(game.fade.black)}


fade_busy :: proc(game: ^Game) -> bool {
	f := &game.fade
	return f.action != nil || f.black > 0 || f.overlay != f.overlay_goal
}


leave_overlay :: proc(game: ^Game, action: proc(game: ^Game)) {
	f := &game.fade
	if f.action != nil do return
	f.overlay_goal = 0
	f.wait = .Overlay
	f.action = action
}


cover_then :: proc(game: ^Game, action: proc(game: ^Game)) {
	f := &game.fade
	if f.action != nil do return
	f.black_goal = 1
	f.wait = .Black
	f.action = action
}


fade_update :: proc(game: ^Game, dt: f32) {
	f := &game.fade


	want := game.play_state == .Paused || game.play_state == .GameOver
	if want != f.overlay_on {
		f.overlay_on = want
		f.overlay = 0
		f.overlay_goal = 1 if want else 0
	}

	step := dt / FADE_TIME
	f.overlay = approach(f.overlay, f.overlay_goal, step)
	f.black = approach(f.black, f.black_goal, step)

	if f.action == nil do return
	switch f.wait {
	case .Overlay:
		if f.overlay <= 0 {
			a := f.action
			f.action = nil
			f.wait = .None
			a(game)
		}
	case .Black:
		if f.black >= 1 {
			a := f.action
			f.action = nil
			f.wait = .None
			a(game)
			f.black_goal = 0
		}
	case .None:
	}
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
