package tag2p5

import rl "vendor:raylib"

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
	color:             rl.Color,
	movement_callback: proc() -> (dir: f32, jump: bool),
}
