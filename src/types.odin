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

GameState :: enum {
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
	play_state: GameState,
	bg_layers:  []ParallaxLayer,
	scenes:     map[GameState]Scene,
}

ParallaxLayer :: struct {
	tex:    Texture2D,
	factor: f32,
}

Button :: struct {
	rect:     rl.Rectangle,
	glyph:    Texture2D,
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

TiledMap :: struct {
	width:      int,
	height:     int,
	tilewidth:  int,
	tileheight: int,
	layers:     []TiledLayers,
	tilesets:   []TiledTileset,
	infinite:   bool,
}

TiledLayers :: struct {
	data:   []u32,
	width:  int,
	height: int,
	name:   string,
}

TiledTileset :: struct {
	firstgid:   int,
	columns:    int,
	image:      string,
	tilecount:  int,
	tilewidth:  int,
	tileheight: int,
	tiles:      []TiledTileDef,
}

TiledTileDef :: struct {
	id:         int,
	properties: []TiledProperty,
}

TiledProperty :: struct {
	value: []TiledPropListItem, // []f64
}

TiledPropListItem :: struct {
	value: f64,
}

TileCollideData :: struct {
	id:     u32,
	points: []f64,
}

Tilemap :: struct {
	tiles:         []u32,
	width, height: int,
	tile_width:    int,
	tile_height:   int,
	tileset_tex:   Texture2D,
	first_gid:     int,
	columns:       int,
	collide_data:  map[u32][]f64,
}

Label :: struct {
	text:       cstring,
	font_size:  uint,
	posx, posy: i32,
	color:      rl.Color,
}

Scene :: struct {
	scene:   GameState,
	buttons: []Button,
	labels:  []Label,
}
