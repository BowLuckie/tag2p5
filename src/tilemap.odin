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
	tiles:        []u32,
	width:        int,
	height:       int,
	tile_width:   int,
	tile_height:  int,
	tileset_path: string,
	tileset_tex:  rl.Texture2D,
	first_gid:    int,
	columns:      int,
	collide_data: map[u32][]f64,
}

load_tilemap :: proc(path: string) -> (tilemap: Tilemap, err: os.Error) {
	jasonb, e := os.read_entire_file(path, context.allocator)
	if e != nil {return {}, e}

	tmap: TiledMap
	json.unmarshal_string(string(jasonb), &tmap)
	assert(!tmap.infinite)

	layer := tmap.layers[0]


	img_path := fmt.ctprint("./static/", tmap.tilesets[0].image, sep = "")
	tileset_tex := rl.LoadTexture(img_path)

	collide_data := make(map[u32][]f64)

	for ttdef in tmap.tilesets[0].tiles {
		id := u32(ttdef.id)
		points: [dynamic]f64
		for tprop in ttdef.properties {
			for tlist_item in tprop.value {
				append(&points, tlist_item.value)
			}
		}
		collide_data[id] = points[:]
	}


	tilemap = Tilemap {
		tiles        = layer.data,
		width        = layer.width,
		height       = layer.height,
		tile_width   = tmap.tilewidth,
		tile_height  = tmap.tileheight,
		tileset_path = tmap.tilesets[0].image,
		tileset_tex  = tileset_tex,
		first_gid    = tmap.tilesets[0].firstgid,
		columns      = tmap.tilesets[0].columns,
		collide_data = collide_data,
	}

	return tilemap, nil
}

get_gid_and_flags :: proc(raw: u32) -> (gid: u32, flip_h, flip_v, flip_d: bool) {
	flip_h = (raw & FLIPPED_HORIZONTALLY) != 0
	flip_v = (raw & FLIPPED_VERTICALLY) != 0
	flip_d = (raw & FLIPPED_DIAGONALLY) != 0
	gid = raw & ~u32(FLIPPED_HORIZONTALLY | FLIPPED_VERTICALLY | FLIPPED_DIAGONALLY)
	return
}

generate_segments :: proc(tilemap: Tilemap) -> []Segment {
	segments := make([dynamic]Segment)
	for y := 0; y < tilemap.height; y += 1 {
		for x := 0; x < tilemap.width; x += 1 {
			index := (y * tilemap.width) + x

			raw := tilemap.tiles[index]
			gid, flip_h, flip_v, flip_d := get_gid_and_flags(raw)
			segs := segs_from_collide(
				gid,
				flip_h,
				flip_v,
				flip_d,
				Vector2{f32(x), f32(y)},
				tilemap,
			)

			append(&segments, ..segs)
		}
	}

	return segments[:]
}

segs_from_collide :: proc(
	gid: u32,
	h, v, d: bool,
	top_left: Vector2,
	tilemap: Tilemap,
) -> []Segment {
	trueid := int(gid) - tilemap.first_gid
	if trueid < 0 do return {}

	points_upair := tilemap.collide_data[u32(trueid)]
	points := squash_pairs(points_upair)

	for &point in points {
		point.x *= f32(tilemap.tile_width)
		point.y *= f32(tilemap.tile_height)
		point.x += top_left.x * f32(tilemap.tile_width)
		point.y += top_left.y * f32(tilemap.tile_height)
	}

	segments: [dynamic]Segment

	for pt, i in points {
		if i >= len(points) - 1 do break

		seg := Segment{pt, points[i + 1]}

		append(&segments, seg)
	}

	return segments[:]
}

squash_pairs :: proc(upaired: []f64) -> []Vector2 {
	assert(len(upaired) % 2 == 0, "malformed collision data pairings")
	result := make([]Vector2, len(upaired) / 2)
	for i in 0 ..< len(result) {
		result[i] = Vector2{f32(upaired[i * 2]), f32(upaired[i * 2 + 1])}
	}
	return result
}

draw_tilemap :: proc(tilemap: Tilemap) {
	for y := 0; y < tilemap.height; y += 1 {
		for x := 0; x < tilemap.width; x += 1 {
			index := (y * tilemap.width) + x

			raw := tilemap.tiles[index]
			gid, flip_h, flip_v, flip_d := get_gid_and_flags(raw)

			draw_tile(gid, flip_h, flip_v, flip_d, Vector2{f32(x), f32(y)}, tilemap)
		}
	}
}

draw_tile :: proc(gid: u32, h, v, d: bool, top_left: Vector2, tilemap: Tilemap) {
	if gid == 0 {return}
	src := get_src_rect(tilemap, gid)
	dest := rl.Rectangle {
		top_left.x * f32(tilemap.tile_width),
		top_left.y * f32(tilemap.tile_height),
		f32(tilemap.tile_width),
		f32(tilemap.tile_height),
	}

	rl.DrawTexturePro(tilemap.tileset_tex, src, dest, {0, 0}, 0, rl.WHITE)
}

get_src_rect :: proc(tmap: Tilemap, gid: u32) -> rl.Rectangle {
	local_id := int(gid) - tmap.first_gid
	if local_id < 0 {return {}}
	col := local_id % tmap.columns
	row := local_id / tmap.columns
	return rl.Rectangle {
		x = f32(col * tmap.tile_width),
		y = f32(row * tmap.tile_height),
		width = f32(tmap.tile_width),
		height = f32(tmap.tile_height),
	}
}
