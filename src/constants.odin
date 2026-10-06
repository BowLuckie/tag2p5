package tag2p5

import rl "vendor:raylib"

ASSET_DIR :: "./assets/"
ARENAS_DIR :: "arenas/"
ENTITY_DIR :: "e/"
GAME_DIR :: "game/"
MUSIC_DIR :: "music/"
UI_DIR :: "ui/"

// the arena converts a web of thousands of allocations into a single onwed object
// so here is where we store them so we can free them all at once.
ARENA_BUF_SIZE :: 16 * 1024 * 1024

GAME_WIDTH :: 2880
GAME_HEIGHT :: 1920

MAX_ZOOM :: 400
CAM_PADDING_X :: 210
CAM_PADDING_Y :: 50
CAM_FOLLOW_SPEED :: 8.0
CAM_ZOOM_SPEED :: 6.0

PAD :: 40
MAX_WALKABLE_SLOPE :: 0.7
MOVE_SPEED :: 300
DECAY_RATE :: 9
GRAVITY :: 1700
JUMP_VEL :: 490
GROUND_SNAP_DIST :: 4

COYOTE_TIME :: 0.18
TAG_IMMUNITY :: 1.0
GAME_TIME :: 61
SPRING_LFT :: 0.1

PLAYER_RAD :: 15
HAIRLINE_OVERLAP :: 1
SKY_COLOR :: rl.Color{99, 155, 255, 255}

TITLE_FONT_ID :: 0
SCROLL_SPEED :: 7
