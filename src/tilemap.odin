package tag2p5

import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import rl "vendor:raylib"

FLIPPED_HORIZONTALLY :: 0x80000000
FLIPPED_VERTICALLY :: 0x40000000
FLIPPED_DIAGONALLY :: 0x20000000

load_tilemap :: proc(
	path: string,
	dirname: string,
	allocator: mem.Allocator,
) -> (
	tilemap: Tilemap,
	err: os.Error,
) {
	jasonb, e := os.read_entire_file(path, allocator)
	if e != nil {return {}, e}

	tmap: TiledMap
	old_alloc := context.allocator
	context.allocator = allocator
	json.unmarshal_string(string(jasonb), &tmap)
	context.allocator = old_alloc
	assert(!tmap.infinite)

	layer := tmap.layers[0]

	img_path := fmt.ctprintf("%sarenas/%s/%s", ASSET_DIR, dirname, tmap.tilesets[0].image)
	tileset_tex := rl.LoadTexture(img_path)

	collide_data := make(map[u32][]f64, allocator)

	context.allocator = allocator
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
	context.allocator = old_alloc

	tilemap = Tilemap {
		tiles        = layer.data,
		width        = layer.width,
		height       = layer.height,
		tile_width   = tmap.tilewidth,
		tile_height  = tmap.tileheight,
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

generate_segments :: proc(tilemap: Tilemap, allocator: mem.Allocator) -> []Segment {
	segments := make([dynamic]Segment, allocator)
	for y := 0; y < tilemap.height; y += 1 {
		for x := 0; x < tilemap.width; x += 1 {
			index := (y * tilemap.width) + x

			raw := tilemap.tiles[index]
			gid, flip_h, flip_v, flip_d := get_gid_and_flags(raw)
			segs := segs_from_cdat(
				gid,
				flip_h,
				flip_v,
				flip_d,
				Vector2{f32(x), f32(y)},
				tilemap,
				allocator,
			)

			append(&segments, ..segs)
		}
	}

	return segments[:]
}

segs_from_cdat :: proc(
	gid: u32,
	h, v, d: bool,
	world_tl: Vector2,
	tilemap: Tilemap,
	allocator: mem.Allocator,
) -> []Segment {
	trueid := int(gid) - tilemap.first_gid
	if trueid < 0 do return {}

	points_upair := tilemap.collide_data[u32(trueid)]
	points := squash_pairs(points_upair, allocator)

	for &point in points {
		point -= 0.5
		if h {
			point.x *= -1
		}

		if v {
			point.y *= -1
		}

		if d {
			point.x, point.y = point.y, point.x
		}
		point += 0.5

		point.x *= f32(tilemap.tile_width)
		point.y *= f32(tilemap.tile_height)
		point.x += world_tl.x * f32(tilemap.tile_width)
		point.y += world_tl.y * f32(tilemap.tile_height)
	}

	segments := make([dynamic]Segment, allocator)

	for pt, i in points {
		if i >= len(points) - 1 do break

		seg := make_segment(pt, points[i + 1], 40)

		append(&segments, seg)
	}

	return segments[:]
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
		f32(tilemap.tile_width) + HAIRLINE_OVERLAP,
		f32(tilemap.tile_height) + HAIRLINE_OVERLAP,
	}

	if d {
		src.width, src.height = -src.height, -src.width
	}
	if h do src.width = -src.width
	if v do src.height = -src.height

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

make_segment :: proc(a, b: rl.Vector2, pad: f32) -> Segment {
	min_x := min(a.x, b.x) - pad
	max_x := max(a.x, b.x) + pad
	min_y := min(a.y, b.y) - pad
	max_y := max(a.y, b.y) + pad
	return Segment{a = a, b = b, bound = {min_x, min_y, max_x - min_x, max_y - min_y}}
}
