extends Control
## Carte des entités et de leurs liens, en pixel art : chaque entité est un post-it avec une icône (personne, lieu,
## objet, notion, date), les liens sont des flèches étiquetées. La disposition est calculée (forces) et reste stable.

const KPx := preload("res://kit/ui/px.gd")
const INTER := preload("res://kit/fonts/Inter-500.woff2")
const C_CHALK := Color("f4f1e6")
const KIND_COL := {"personne": "ffd45e", "lieu": "8fe3ff", "objet": "b7f08a", "notion": "ff9ecb", "date": "ffb454", "sujet": "9ad0f5"}
const ICONS := {
	"personne": ["..###..", ".#####.", "..###..", ".#####.", "#######", "#.###.#", "..#.#.."],
	"lieu": [".#####.", "#######", "###.###", "#######", ".#####.", "..###..", "...#..."],
	"objet": ["#######", "#.....#", "#.###.#", "#.###.#", "#.###.#", "#.....#", "#######"],
	"notion": ["..###..", ".#####.", "#######", "#######", ".#####.", "..###..", "..#.#.."],
	"date": ["#######", "#######", "#.#.#.#", "#######", "#.#.#.#", "#######", "#######"],
	"sujet": [".#####.", "#######", "#######", "#######", ".#####.", "..##...", "..#...."],
}

var entities: Array = []  # {name, kind, count}
var relations: Array = []  # {a, b, label}
var _pos: Array = []  # positions normalisées [0..1]
var sc := 1.0  # échelle (mini-tableau : 0.62)
var images: Dictionary = {}  # nom (minuscule) -> Texture2D (photo Wikipédia)
signal node_clicked(name: String, kind: String)
var manual := {}  # nom (minuscule) -> position normalisée posée à la main (glisser-déposer)
var selected := ""
var framed := false  # dessine son propre tableau vert (affichage sur un mur 3D)
var pan := Vector2.ZERO
var zoom := 1.0
var _rects: Array = []
var _drag := -1
var _pan_drag := false
var _moved := false


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE
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
	for it in 140:
		var cool := 0.05 * (1.0 - float(it) / 140.0) + 0.002  # refroidissement : la disposition se stabilise
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
			_pos[i] += disp[i] / dl * minf(dl, cool)
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
	var tw := INTER.get_string_size(e["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * sc)).x
	var sz := Vector2(minf(tw + 62.0 * sc, 260.0 * sc), 46.0 * sc)
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
	if framed:
		KPx.panel(self, Rect2(Vector2.ZERO, size), Color("14352c"), Color("a9743f"), false, 2)
	if entities.is_empty():
		return
	draw_set_transform(pan, 0.0, Vector2(zoom, zoom))
	var area := _area()
	var rects: Array = []
	for i in entities.size():
		var rc0 := _node_rect(i, area)
		var mk: String = entities[i]["name"].to_lower()
		if manual.has(mk):
			rc0.position = area.position + manual[mk] * area.size - rc0.size / 2.0
		rects.append(rc0)
	_separate(rects, Rect2(Vector2.ZERO, size).grow(-8))
	_rects = rects
	# liens
	for r in relations:
		var ra: Rect2 = rects[r["a"]]
		var rb: Rect2 = rects[r["b"]]
		var p0 := _edge_point(ra, rb.get_center())
		var p1 := _edge_point(rb, ra.get_center())
		if r.get("topic", false):  # rattachement à un sujet : trait fin pointillé, sans flèche
			var steps := int(p0.distance_to(p1) / 12.0)
			for q in range(0, steps, 2):
				draw_line(p0.lerp(p1, float(q) / steps), p0.lerp(p1, float(q + 1) / steps), Color("9ad0f5", 0.6), 2.0)
			continue
		draw_line(p0, p1, Color(C_CHALK, 0.85), maxf(2.0, 3.0 * sc))
		var dir := (p1 - p0).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([p1, p1 - dir * 14 * sc + nrm * 7 * sc, p1 - dir * 14 * sc - nrm * 7 * sc]), C_CHALK)
		var lbl: String = r["label"]
		if lbl != "":
			var lw := INTER.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * sc)).x
			var m := (p0 + p1) / 2.0
			draw_rect(Rect2(m - Vector2(lw / 2.0 + 6, 11 * sc), Vector2(lw + 12, 22 * sc)), Color("14352c"))
			draw_string(INTER, m + Vector2(-lw / 2.0, 5 * sc), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * sc), Color("ffd45e"))
	# entités
	for i in entities.size():
		var e: Dictionary = entities[i]
		var col := Color(KIND_COL.get(e["kind"], "f4f1e6"))
		var rc: Rect2 = rects[i]
		if selected != "" and e["name"].to_lower() == selected:
			draw_rect(rc.grow(4), Color("ffd45e"))
		draw_rect(Rect2(rc.position + Vector2(5, 5), rc.size), Color(0, 0, 0, 0.35))
		KPx.panel(self, rc, col, col.darkened(0.45), false, 1)
		var key: String = e["name"].to_lower()
		if images.has(key) and images[key] != null:  # photo dans un petit cadre
			var ph := rc.size.y - 10.0 * sc
			draw_rect(Rect2(rc.position + Vector2(5, 5) * sc, Vector2(ph, ph)).grow(2), col.darkened(0.55))
			draw_texture_rect(images[key], Rect2(rc.position + Vector2(5, 5) * sc, Vector2(ph, ph)), false)
			draw_string(INTER, rc.position + Vector2(ph + 14 * sc, 29 * sc), e["name"], HORIZONTAL_ALIGNMENT_LEFT, rc.size.x - ph - 18 * sc, int(18 * sc), Color("1b1b1b"))
		else:
			KPx.sprite(self, ICONS.get(e["kind"], ICONS["notion"]), rc.position + Vector2(10, 11) * sc, maxf(2.0, 3.0 * sc), {"#": col.darkened(0.55)})
			draw_string(INTER, rc.position + Vector2(40, 29) * sc, e["name"], HORIZONTAL_ALIGNMENT_LEFT, rc.size.x - 46 * sc, int(18 * sc), Color("1b1b1b"))
		if int(e.get("count", 1)) > 1:  # revient dans plusieurs diapos
			var b := "×%d" % int(e["count"])
			draw_rect(Rect2(rc.end.x - 26, rc.position.y - 9, 30, 18), Color("14352c"))
			draw_string(INTER, Vector2(rc.end.x - 22, rc.position.y + 5), b, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffd45e"))


## Écarte les cases qui se chevauchent (les liens restent lisibles) et les garde dans la zone.
func _separate(rects: Array, bounds: Rect2) -> void:
	for _it in 60:
		var moved := false
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				var a: Rect2 = rects[i].grow(10)
				var b: Rect2 = rects[j]
				if not a.intersects(b):
					continue
				var d: Vector2 = b.get_center() - a.get_center()
				var ox := (a.size.x + b.size.x) / 2.0 - absf(d.x)
				var oy := (a.size.y + b.size.y) / 2.0 - absf(d.y)
				var push := Vector2.ZERO
				if ox < oy:
					push = Vector2(signf(d.x) if d.x != 0.0 else 1.0, 0.0) * (ox / 2.0 + 1.0)
				else:
					push = Vector2(0.0, signf(d.y) if d.y != 0.0 else 1.0) * (oy / 2.0 + 1.0)
				rects[i].position -= push
				rects[j].position += push
				moved = true
		for i in rects.size():
			var r: Rect2 = rects[i]
			r.position = r.position.clamp(bounds.position, bounds.end - r.size)
			rects[i] = r
		if not moved:
			break


func _area() -> Rect2:
	return Rect2(Vector2(70, 34) * sc, size - Vector2(140, 68) * sc)


func _hit(p: Vector2) -> int:
	var w := (p - pan) / zoom
	for i in range(_rects.size() - 1, -1, -1):
		if (_rects[i] as Rect2).has_point(w):
			return i
	return -1


func reset_view() -> void:
	pan = Vector2.ZERO
	zoom = 1.0
	manual.clear()
	queue_redraw()


## Glisser un nœud pour le placer, glisser le fond pour déplacer la vue, molette pour zoomer, double-clic pour tout remettre, clic pour désigner.
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.double_click:
					reset_view()
					return
				_moved = false
				_drag = _hit(mb.position)
				_pan_drag = _drag < 0
			else:
				if _drag >= 0 and not _moved and _drag < entities.size():
					selected = entities[_drag]["name"].to_lower()
					node_clicked.emit(entities[_drag]["name"], entities[_drag]["kind"])
					queue_redraw()
				_drag = -1
				_pan_drag = false
			accept_event()
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var nz := clampf(zoom * (1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 0.6, 2.5)
			var wpt := (mb.position - pan) / zoom
			zoom = nz
			pan = mb.position - wpt * zoom
			queue_redraw()
			accept_event()
	elif e is InputEventMouseMotion and (_drag >= 0 or _pan_drag):
		var mm := e as InputEventMouseMotion
		if mm.relative.length() > 0.5:
			_moved = true
		if _drag >= 0 and _drag < entities.size():
			var area := _area()
			var w := (mm.position - pan) / zoom
			manual[entities[_drag]["name"].to_lower()] = ((w - area.position) / area.size).clamp(Vector2(-0.1, -0.1), Vector2(1.1, 1.1))
		elif _pan_drag:
			pan += mm.relative
		queue_redraw()
		accept_event()
