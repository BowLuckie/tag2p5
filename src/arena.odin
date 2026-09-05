#+feature dynamic-literals
package tag2p5

import rl "vendor:raylib"

draw_seg :: proc(seg: Segment) {
	rl.DrawLineEx(seg.a, seg.b, 5, rl.RED)
}

draw_ground_fill :: proc(seg: Segment, color: rl.Color, depth: f32) {
	p1 := seg.a
	p2 := seg.b
	p3 := rl.Vector2{seg.b.x, seg.b.y + depth}
	p4 := rl.Vector2{seg.a.x, seg.a.y + depth}

	rl.DrawTriangle(p1, p4, p2, color)
	rl.DrawTriangle(p2, p4, p3, color)
}

draw_segs :: proc(segs: []Segment) {
	for seg in segs {
		draw_seg(seg)
	}
}
