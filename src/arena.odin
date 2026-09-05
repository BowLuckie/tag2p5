package main

import rl "vendor:raylib"

arena_collide := []Segment {
	// outer walls (2400 x 1400 playable area)
	{a = {0, 1450}, b = {2400, 1450}}, // floor
	{a = {2400, 0}, b = {2400, 50}}, // right wall
	{a = {0, 0}, b = {0, 1450}}, // left wall

	// === bottom tier (ground level, y ~1150-1350) ===
	// left side - rolling hills
	{a = {80, 1350}, b = {250, 1250}}, // slope up
	{a = {250, 1250}, b = {450, 1250}}, // flat ledge
	{a = {450, 1250}, b = {600, 1350}}, // slope down
	// center-left elevated
	{a = {650, 1300}, b = {800, 1200}}, // slope up
	{a = {800, 1200}, b = {1050, 1200}}, // flat
	// center-right
	{a = {1150, 1200}, b = {1350, 1200}}, // flat
	{a = {1350, 1200}, b = {1500, 1300}}, // slope down
	// right side - stepped terrain
	{a = {1600, 1300}, b = {1750, 1200}}, // slope up
	{a = {1750, 1200}, b = {2000, 1200}}, // flat
	{a = {2000, 1200}, b = {2200, 1350}}, // slope down

	// === lower-mid tier (y ~850-1100) ===
	// left floating platforms
	{a = {150, 1050}, b = {350, 1050}}, // flat
	{a = {350, 1050}, b = {400, 950}}, // slope up
	{a = {400, 950}, b = {600, 950}}, // flat
	// center chain
	{a = {700, 1000}, b = {900, 1000}}, // flat
	{a = {900, 1000}, b = {1050, 900}}, // slope up
	{a = {1050, 900}, b = {1300, 900}}, // flat
	{a = {1300, 900}, b = {1450, 1000}}, // slope down
	{a = {1450, 1000}, b = {1600, 1000}}, // flat
	// right floating platforms
	{a = {1750, 1050}, b = {1950, 1050}}, // flat
	{a = {1950, 1050}, b = {2000, 950}}, // slope up
	{a = {2000, 950}, b = {2200, 950}}, // flat

	// === upper-mid tier (y ~550-800) ===
	// left side
	{a = {100, 700}, b = {300, 700}}, // flat
	{a = {300, 700}, b = {350, 650}}, // slope up
	{a = {350, 650}, b = {550, 650}}, // flat
	// center island
	{a = {650, 750}, b = {800, 680}}, // slope up
	{a = {800, 680}, b = {1000, 680}}, // flat
	{a = {1000, 680}, b = {1150, 750}}, // slope down
	// center-right
	{a = {1250, 700}, b = {1450, 700}}, // flat
	{a = {1450, 700}, b = {1500, 650}}, // slope up
	{a = {1500, 650}, b = {1700, 650}}, // flat
	// right side
	{a = {1850, 700}, b = {2050, 700}}, // flat
	{a = {2100, 750}, b = {2300, 750}}, // flat

	// === top tier (near ceiling, y ~150-450) ===
	// left side
	{a = {150, 400}, b = {350, 400}}, // flat
	{a = {350, 400}, b = {400, 350}}, // slope up
	{a = {400, 350}, b = {600, 350}}, // flat
	// center
	{a = {700, 350}, b = {900, 350}}, // flat
	{a = {950, 250}, b = {1200, 250}}, // flat (highest point)
	{a = {1200, 250}, b = {1350, 350}}, // slope down
	{a = {1350, 350}, b = {1500, 350}}, // flat
	// right side
	{a = {1650, 400}, b = {1850, 400}}, // flat
	{a = {1850, 400}, b = {1900, 350}}, // slope up
	{a = {1900, 350}, b = {2100, 350}}, // flat
	{a = {2100, 350}, b = {2250, 400}}, // slope down
}

draw_seg :: proc(seg: Segment) {
	draw_ground_fill(seg, rl.BLACK, PLAT_THICKNESS)
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
