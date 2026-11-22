extends Control
## Carte des entités et de leurs liens, en pixel art : chaque entité est un post-it avec une icône (personne, lieu,
## objet, notion, date), les liens sont des flèches étiquetées. La disposition est calculée (forces) et reste stable.

const KPx := preload("res://kit/ui/px.gd")
const INTER := preload("res://kit/fonts/Inter-500.woff2")
const C_CHALK := Color("f4f1e6")
const KIND_COL := {"personne": "ffd45e", "lieu": "8fe3ff", "objet": "b7f08a", "notion": "ff9ecb", "date": "ffb454"}
const ICONS := {
	"personne": ["..###..", ".#####.", "..###..", ".#####.", "#######", "#.###.#", "..#.#.."],
	"lieu": [".#####.", "#######", "###.###", "#######", ".#####.", "..###..", "...#..."],
	"objet": ["#######", "#.....#", "#.###.#", "#.###.#", "#.###.#", "#.....#", "#######"],
	"notion": ["..###..", ".#####.", "#######", "#######", ".#####.", "..###..", "..#.#.."],
	"date": ["#######", "#######", "#.#.#.#", "#######", "#.#.#.#", "#######", "#######"],
}

var entities: Array = []  # {name, kind, count}
var relations: Array = []  # {a, b, label}
var _pos: Array = []  # positions normalisées [0..1]


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func set_graph(ents: Array, rels: Array) -> void:
	entities = ents
	relations = rels
	_layout()
	queue_redraw()


func _layout() -> void:
	var n := entities.size()
	_pos = []
	if n == 0:
		return
	for i in n:
		var a := TAU * i / n
		_pos.append(Vector2(0.5, 0.5) + Vector2(cos(a) * 0.38, sin(a) * 0.34))
	if n == 1:
		_pos[0] = Vector2(0.5, 0.5)
		return
	var k := 0.42 / sqrt(float(n))
	for _it in 140:
		var disp: Array = []
		disp.resize(n)
		disp.fill(Vector2.ZERO)
		for i in n:
			for j in range(i + 1, n):
				var d: Vector2 = _pos[i] - _pos[j]
				var l := maxf(d.length(), 0.01)
				var f := d / l * (k * k / l)
				disp[i] += f
				disp[j] -= f
		for r in relations:
			var d2: Vector2 = _pos[r["a"]] - _pos[r["b"]]
			var l2 := maxf(d2.length(), 0.01)
			var f2 := d2 / l2 * (l2 * l2 / k)
			disp[r["a"]] -= f2
			disp[r["b"]] += f2
		for i in n:
			var dl: float = maxf(disp[i].length(), 0.001)
			_pos[i] += disp[i] / dl * minf(dl, 0.03)
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for p in _pos:
		lo = lo.min(p)
		hi = hi.max(p)
	var span := (hi - lo).max(Vector2(0.001, 0.001))
	for i in n:
		_pos[i] = Vector2(0.1, 0.12) + (_pos[i] - lo) / span * Vector2(0.8, 0.76)


func _node_rect(i: int, area: Rect2) -> Rect2:
	var e: Dictionary = entities[i]
	var tw := INTER.get_string_size(e["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var sz := Vector2(minf(tw + 62.0, 260.0), 46.0)
	var c: Vector2 = area.position + _pos[i] * area.size
	return Rect2(c - sz / 2.0, sz)


func _edge_point(r: Rect2, toward: Vector2) -> Vector2:
	var c := r.get_center()
	var d := toward - c
	if d.length() < 0.01:
		return c
	var t := minf(r.size.x / 2.0 / maxf(absf(d.x), 0.001), r.size.y / 2.0 / maxf(absf(d.y), 0.001))
	return c + d * t


func _draw() -> void:
	if entities.is_empty():
		return
	var area := Rect2(Vector2(70, 34), size - Vector2(140, 68))
	var rects: Array = []
	for i in entities.size():
		rects.append(_node_rect(i, area))
	# liens
	for r in relations:
		var ra: Rect2 = rects[r["a"]]
		var rb: Rect2 = rects[r["b"]]
		var p0 := _edge_point(ra, rb.get_center())
		var p1 := _edge_point(rb, ra.get_center())
		draw_line(p0, p1, Color(C_CHALK, 0.85), 3.0)
		var dir := (p1 - p0).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([p1, p1 - dir * 14 + nrm * 7, p1 - dir * 14 - nrm * 7]), C_CHALK)
		var lbl: String = r["label"]
		if lbl != "":
			var lw := INTER.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			var m := (p0 + p1) / 2.0
			draw_rect(Rect2(m - Vector2(lw / 2.0 + 6, 11), Vector2(lw + 12, 22)), Color("14352c"))
			draw_string(INTER, m + Vector2(-lw / 2.0, 5), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffd45e"))
	# entités
	for i in entities.size():
		var e: Dictionary = entities[i]
		var col := Color(KIND_COL.get(e["kind"], "f4f1e6"))
		var rc: Rect2 = rects[i]
		draw_rect(Rect2(rc.position + Vector2(5, 5), rc.size), Color(0, 0, 0, 0.35))
		KPx.panel(self, rc, col, col.darkened(0.45), false, 1)
		KPx.sprite(self, ICONS.get(e["kind"], ICONS["notion"]), rc.position + Vector2(10, 11), 3.0, {"#": col.darkened(0.55)})
		draw_string(INTER, rc.position + Vector2(40, 29), e["name"], HORIZONTAL_ALIGNMENT_LEFT, rc.size.x - 46, 18, Color("1b1b1b"))
		if int(e.get("count", 1)) > 1:  # revient dans plusieurs diapos
			var b := "×%d" % int(e["count"])
			draw_rect(Rect2(rc.end.x - 26, rc.position.y - 9, 30, 18), Color("14352c"))
			draw_string(INTER, Vector2(rc.end.x - 22, rc.position.y + 5), b, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffd45e"))
