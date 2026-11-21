extends RefCounted
## Primitives de dessin PIXEL ART (coins en escalier, biseau, ombre dure, sprites en chaînes) pour tous les composants/apps.
const Tokens := preload("res://kit/tokens.gd")
const U := 2  # taille d'un « pixel » de bordure

## Panneau pixel : bordure sombre 2 px, coins coupés en escalier, biseau clair en haut/gauche, sombre en bas/droite, ombre dure optionnelle.
static func panel(ci: CanvasItem, r: Rect2, fill: Color, edge := Color(0, 0, 0, 0), shadow := true, notch := 1) -> void:
	r = Rect2(r.position.round(), r.size.round())
	if edge.a == 0.0:
		edge = fill.darkened(0.6)
	var n := notch * U
	if shadow:
		_stair(ci, Rect2(r.position + Vector2(U * 2, U * 2), r.size), Color(0, 0, 0, 0.45), n)
	_stair(ci, r, edge, n)
	var i := r.grow(-U)
	_stair(ci, i, fill, maxi(n - U, 0))
	var j := i.grow(-U)
	if j.size.x > 4 and j.size.y > 4:
		ci.draw_rect(Rect2(j.position.x + n - U, j.position.y, j.size.x - 2 * (n - U), U), fill.lightened(0.18))
		ci.draw_rect(Rect2(j.position.x, j.position.y + n - U, U, j.size.y - 2 * (n - U)), fill.lightened(0.12))
		ci.draw_rect(Rect2(j.position.x + n - U, j.end.y - U, j.size.x - 2 * (n - U), U), fill.darkened(0.25))
		ci.draw_rect(Rect2(j.end.x - U, j.position.y + n - U, U, j.size.y - 2 * (n - U)), fill.darkened(0.2))

## Rectangle plein dont les 4 coins sont coupés en escalier (m paliers de U px).
static func _stair(ci: CanvasItem, r: Rect2, c: Color, n: float) -> void:
	var m := int(n / U)
	if m <= 0 or r.size.x < n * 2 + U or r.size.y < n * 2 + U:
		ci.draw_rect(r, c)
		return
	for i in m:
		var inset := float((m - i) * U)
		ci.draw_rect(Rect2(r.position.x + inset, r.position.y + i * U, r.size.x - 2 * inset, U), c)
		ci.draw_rect(Rect2(r.position.x + inset, r.end.y - (i + 1) * U, r.size.x - 2 * inset, U), c)
	ci.draw_rect(Rect2(r.position.x, r.position.y + m * U, r.size.x, r.size.y - 2 * m * U), c)

## Trait pixel (horizontal/vertical) d'épaisseur U.
static func hline(ci: CanvasItem, x: float, y: float, w: float, c: Color) -> void:
	ci.draw_rect(Rect2(x, y, w, U), c)

## Dessine un sprite défini par des chaînes ('.' = vide, lettre = couleur de la palette).
static func sprite(ci: CanvasItem, rows: Array, pos: Vector2, unit: float, pal: Dictionary) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch != "." and ch != " " and pal.has(ch):
				ci.draw_rect(Rect2(pos + Vector2(x, y) * unit, Vector2(unit, unit)), pal[ch])

static func sprite_size(rows: Array, unit: float) -> Vector2:
	return Vector2((rows[0] as String).length() * unit, rows.size() * unit)

const ARROW_UP := [
	"...##...",
	"..####..",
	".######.",
	"########",
	"...##...",
	"...##...",
	"...##...",
	"...##...",
]
const ARROW_UP_ROUND := [
	"....##....",
	"...####...",
	"..######..",
	".########.",
	"....##....",
	"....##....",
	"....##....",
	"....##....",
]
const STOP := [
	"######",
	"######",
	"######",
	"######",
	"######",
	"######",
]
