package tag2p5

import rl "vendor:raylib"

Vector2 :: rl.Vector2
Texture2D :: rl.Texture2D
Aabb :: rl.Rectangle

Segment :: struct {
	a, b: Vector2,
	aabb: Aabb,
}


// TODO: power ups? abilitys?
Entity :: struct {
	center:            Vector2,
	vel:               Vector2,
	radius:            f32,
	grounded:          bool,
	coyote_time:       f32,
	tagged:            bool,
	animation:         AnimationObj,
	tex:               Texture2D,
	triangle_tex:      Texture2D,
	rotation:          f32,
	pid:               uint,
	movement_callback: proc() -> (dir: f32, jump: bool),
}

AnimationObj :: struct {
	frame:          uint,
	frame_time:     f32,
	frame_duration: f32,
	tile_count:     uint,
	columns:        uint,
	tile_w:         f32,
	tile_h:         f32,
	tilesheet:      Texture2D,
	src_rect:       rl.Rectangle,
}

GameCamera :: struct {
	cam:      rl.Camera2D,
	min_zoom: f32,
	max_zoom: f32,
	padding:  f32,
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
	gc:         GameCamera,
	players:    []Entity,
	tilemap:    Tilemap,
	segments:   []Segment,
	last_tag:   f32,
	mode:       GameMode,
	game_time:  f32,
	play_state: PlayState,
	buttons:    []Button,
	bg_layers:  []ParallaxLayer,
}

ParallaxLayer :: struct {
	tex:    Texture2D,
	factor: f32,
}

Button :: struct {
	rect:     rl.Rectangle,
	glyph:    Texture2D,
	states:   bit_set[PlayState],
	on_click: proc(game: ^Game),
}

PlayerConfig :: struct {
	center:            Vector2,
	radius:            f32,
	animation:         AnimationObj,
	tex:               Texture2D,
	triangle_tex:      Texture2D,
	pid:               uint,
	movement_callback: proc() -> (dir: f32, jump: bool),
}
