package tag2p5

import rl "vendor:raylib"

Vector2 :: rl.Vector2

Segment :: struct {
	a, b:  Vector2,
	bound: rl.Rectangle,
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
	tex:               rl.Texture2D,
	rotation:          f32,
	pid:              uint,
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
	tilesheet:      rl.Texture2D,
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
	tex:    rl.Texture2D,
	factor: f32,
}

Button :: struct {
	rect:     rl.Rectangle,
	glyph:    rl.Texture2D,
	states:   bit_set[PlayState],
	on_click: proc(game: ^Game),
}

PlayerConfig :: struct {
	center:            Vector2,
	radius:            f32,
	animation:         AnimationObj,
	tex:               rl.Texture2D,
	pid:              uint,
	movement_callback: proc() -> (dir: f32, jump: bool),
}
