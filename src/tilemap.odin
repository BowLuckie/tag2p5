package tag2p5

import "core:encoding/json"
import "core:fmt"
import "core:os"
import rl "vendor:raylib"

FLIPPED_HORIZONTALLY :: 0x80000000
FLIPPED_VERTICALLY :: 0x40000000
FLIPPED_DIAGONALLY :: 0x20000000

TiledMap :: struct {
	width:      int,
	height:     int,
	tilewidth:  int,
	tileheight: int,
	layers:     []TiledLayers,
	tilesets:   []TiledTileset,
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
}

Tilemap :: struct {
	tiles:        []u32,
	segments:     [dynamic]Segment,
	width:        int,
	height:       int,
	tilewidth:    int,
	tileheight:   int,
	tileset_path: string,
	tileset_tex:  rl.Texture2D,
}

load_tilemap :: proc(path: string) -> (tilemap: Tilemap, err: os.Error) {
	jasonb, e := os.read_entire_file(path, context.allocator)
	if e != nil {return {}, e}

	tmap: TiledMap
	json.unmarshal_string(string(jasonb), &tmap)

	layer := tmap.layers[0]

	img_path := fmt.ctprint("./static/", tmap.tilesets[0].image, sep = "")
	tileset_tex := rl.LoadTexture(img_path)

	tilemap = Tilemap{
		tiles        = layer.data,
		width        = layer.width,
		height       = layer.height,
		tilewidth    = tmap.tilewidth,
		tileheight   = tmap.tileheight,
		tileset_path = tmap.tilesets[0].image,
		tileset_tex  = tileset_tex,
	}
	tilemap.segments = generate_segments(tilemap)

	return tilemap, nil
}

get_gid_and_flags :: proc(raw: u32) -> (gid: u32, flip_h, flip_v, flip_d: bool) {
	flip_h = (raw & FLIPPED_HORIZONTALLY) != 0
	flip_v = (raw & FLIPPED_VERTICALLY) != 0
	flip_d = (raw & FLIPPED_DIAGONALLY) != 0
	gid = raw & ~u32(FLIPPED_HORIZONTALLY | FLIPPED_VERTICALLY | FLIPPED_DIAGONALLY)
	return
}

generate_segments :: proc(tilemap: Tilemap) -> [dynamic]Segment {
	segments := make([dynamic]Segment)
	for y := 0; y < tilemap.height; y += 1 {
		for x := 0; x < tilemap.width; x += 1 {
			index := (y * tilemap.width) + x

			raw := tilemap.tiles[index]
			switch raw {
			case 0:
				{continue}

			case:
				gid, flip_h, flip_v, flip_d := get_gid_and_flags(raw)
				seg := generate_seg(gid, flip_h, flip_v, flip_d, Vector2{f32(x), f32(y)})

				append(&segments, seg)
			}
		}
	}

	return segments
}

generate_seg :: proc(gid: u32, h, v, d: bool, bottom_left: Vector2) -> Segment {
	assert(gid != 0)
	seg: Segment
	start: Vector2
	end: Vector2
	switch gid {
	// case 1:
	// 	start = bottom_left + Vector2{.2, .9}
	// 	end = bottom_left + Vector2{.9, .9}
	case:
		start = bottom_left
		end = bottom_left + Vector2{.9, 0}
	}

	return Segment{start * 32, end * 32}
}
