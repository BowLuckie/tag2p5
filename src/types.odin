package tag2p5

import clay "clay-odin"
import "core:mem"
import rl "vendor:raylib"

Vector2 :: rl.Vector2
Texture2D :: rl.Texture2D
Aabb :: rl.Rectangle

ID :: clay.ID
UI :: clay.UI

GameMode :: enum {
	Normal,
}

GameState :: enum {
	MainMenu,
	MapSel,
	Playing,
	Paused,
	GameOver,
}

Fonts :: enum {
	TheOneFont = 0, // there is a good chance this stays like this forever
}

SoundEffect :: enum {
	Jump,
}

Segment :: struct {
	a, b:  Vector2,
	bound: Aabb,
}

Game :: struct {
	// currently this always sits at `.Normal` maybe one day i will add more gamemodes
	mode:                GameMode,

	// should the game close its self at the end of this frame
	suicidal:            bool,

	// similarly to `suicidal` this indacates what `level_idx` to restart to at the end of this frame
	pending_restart_idx: int,

	// a list of all the levels discovered by `create_game()`
	levels:              []Level,

	// an index into `levels` that points to the level that is being played
	lvl_idx:             int,

	// the texture the game is drawn to
	target:              rl.RenderTexture2D,

	// the current screen that is focused, eg `.Paused` `.MainMenu`
	play_state:          GameState,

	// memory storage feilds
	clay_memory:         []u8,
	uiel_idx:            int,
	assets:              GuiAssets,
	font:                [Fonts]rl.Font,
	sounds:              map[SoundEffect]rl.Sound,
}

Level :: struct {
	// the game camera. objects are places in absolute positions and the camera does
	// the rest of the work
	gc:        rl.Camera2D,
	// information about the way this level looks and its collision
	arena:     Arena,
	// players are arena specifc, becuase they might have diffrent spawns
	players:   []Player,
	springs:   []Spring,
	// counts down from `TAG_IMMUNITY` to 0
	last_tag:  f32,
	// counts down from `GAME_TIME` to 0
	game_time: f32,
	thumb:     Texture2D,
	title:     string,
}

Arena :: struct {
	// contains information about the Tiled json
	tilemap:   Tilemap,
	// rendered in LIFO order
	bg_layers: []ParallaxLayer,
	segments:  []Segment,
	arena_buf: []u8,
	memarena:  mem.Arena,
}

GuiAssets :: struct {
	play_button_tex:    Texture2D,
	quit_button_tex:    Texture2D,
	pause_button_tex:   Texture2D,
	restart_button_tex: Texture2D,
	menu_button_tex:    Texture2D,
	cursor_tex:         Texture2D,
	menu_bg_tex:        Texture2D,
}


Player :: struct {
	center:       Vector2,
	vel:          Vector2,
	radius:       f32,
	grounded:     bool,
	// counts down from `COYOTE_TIME` to 0
	coyote_time:  f32,
	// tagging info is stored in the players, not the game
	tagged:       bool,
	animation:    AnimationObj,
	tex:          Texture2D,
	triangle_tex: Texture2D,
	rotation:     f32,
	// the unique id of this player, used to determine sprite and movement
	pid:          uint,
	// orientation is now persistant
	orientation:  f32,
}

Spring :: struct {
	pos:       Vector2,
	refresh:   f32,
	animation: AnimationObj,
	collidor:  rl.Rectangle,
	force:     f32,
}

// currently not used in game
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


ParallaxLayer :: struct {
	tex:    Texture2D,
	factor: f32,
}

// the struct that the json get marsheled into
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

Ospawns :: struct {
	players: []Vector2,
	springs: []Vector2,
}

MusicPlayer :: struct {
	music:  rl.Music,
	volume: f32,
}
