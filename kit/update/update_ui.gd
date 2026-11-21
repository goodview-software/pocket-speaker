extends CanvasLayer
## Carte de mise à jour en PIXEL ART (dessinée par le code, grille de 3 px, coins en escalier, biseau) commune aux apps.
## Usage : var ui := preload("res://kit/update/update_ui.gd").new(); add_child(ui); ui.setup("org/repo", VERSION)
## Bouton principal VERT « METTRE À JOUR » (confirmer) ; barre de progression en segments ; « REDÉMARRER » en vert quand c'est prêt.

const Updater := preload("res://kit/update/updater.gd")
const U := 3  # taille d'un « pixel » à l'écran
const OUT := Color("0b1410")
const PANEL := Color("17211c")
const HI := Color("2b3d34")
const LO := Color("0f1713")
const GREEN := Color("49d96b")
const GREEN_HI := Color("8cf5a4")
const GREEN_LO := Color("2a9a47")
const RED := Color("ff6b6b")
const GRAY := Color("3a463f")
const TEXT := Color("e8f2ec")
const DIM := Color("8fa398")

var updater: Updater
var card: Control
var font: Font
var _t := 0.0
var _btns: Array = []  # [Rect2 (local), id]
var _hover := ""


func setup(repo: String, version: String, interval := 1800.0, first_delay := 2.5) -> void:
	layer = 100
	updater = Updater.new()
	add_child(updater)
	updater.setup(repo, version, interval, first_delay)
	updater.changed.connect(_on_changed)
	font = ThemeDB.fallback_font
	if ResourceLoader.exists("res://kit/fonts/PixelifySans.ttf"):
		var f = load("res://kit/fonts/PixelifySans.ttf")
		if f is Font:
			font = f
	card = Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.visible = false
	card.draw.connect(_draw_card)
	card.gui_input.connect(_input)
	card.mouse_exited.connect(func():
		_hover = ""
		card.queue_redraw())
	add_child(card)
	get_viewport().size_changed.connect(_layout)
	set_process(true)


func _visible_state() -> bool:
	match updater.state:
		"available", "newbin":
			return updater.dismissed != str(updater.info.get("version", ""))
		"downloading", "ready", "error":
			return true
	return false


func _on_changed() -> void:
	card.visible = _visible_state()
	_layout()
	card.queue_redraw()


func _layout() -> void:
	if card == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var w := snappedf(minf(396.0, vp.x - 24.0), U)
	var h := float(U * 46)
	if updater.state == "downloading":
		h = float(U * 40)
	card.size = Vector2(w, h)
	card.position = Vector2(snappedf(vp.x - w - 12.0, U), snappedf(vp.y - h - 12.0, U))


func _process(delta: float) -> void:
	if card.visible:
		_t += delta
		card.queue_redraw()


# ------------------------------------------------------------------ dessin pixel art

func _box(r: Rect2, fill: Color, outline: Color, hi: Color, lo: Color) -> void:
	var u := float(U)
	card.draw_rect(Rect2(r.position.x + u, r.position.y, r.size.x - 2 * u, r.size.y), outline)
	card.draw_rect(Rect2(r.position.x, r.position.y + u, r.size.x, r.size.y - 2 * u), outline)
	var f := Rect2(r.position + Vector2(u, u), r.size - Vector2(2 * u, 2 * u))
	card.draw_rect(Rect2(f.position.x + u, f.position.y, f.size.x - 2 * u, f.size.y), fill)
	card.draw_rect(Rect2(f.position.x, f.position.y + u, f.size.x, f.size.y - 2 * u), fill)
	card.draw_rect(Rect2(f.position.x + u, f.position.y, f.size.x - 2 * u, u), hi)  # biseau clair (haut)
	card.draw_rect(Rect2(f.position.x + u, f.position.y + f.size.y - u, f.size.x - 2 * u, u), lo)  # ombre (bas)


func _text(s: String, pos: Vector2, size: int, col: Color, w := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	card.draw_string(font, pos, s, align, w, size, col)


func _check(c: Vector2, col: Color) -> void:  # coche en escalier
	var u := float(U)
	for p in [Vector2(-3, 0), Vector2(-2, 1), Vector2(-1, 2), Vector2(0, 1), Vector2(1, 0), Vector2(2, -1), Vector2(3, -2)]:
		card.draw_rect(Rect2(c + p * u - Vector2(u, u) * 0.5, Vector2(u, u)), col)


func _button(r: Rect2, id: String, label: String, green: bool, with_check := false) -> void:
	_btns.append([r, id])
	var pressed := _hover == id and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var rr := r
	if pressed:
		rr.position.y += U  # le bouton s'enfonce d'un pixel
	var fill := GREEN if green else GRAY
	var hi := GREEN_HI if green else HI
	var lo := GREEN_LO if green else LO
	if _hover == id and not pressed:
		fill = fill.lightened(0.08)
	_box(rr, fill, OUT, hi, lo)
	var tc := OUT if green else TEXT
	var cy := rr.position.y + rr.size.y / 2.0 + 6.0
	if with_check:
		_check(Vector2(rr.position.x + U * 7, rr.position.y + rr.size.y / 2.0), tc)
		_text(label, Vector2(rr.position.x + U * 12, cy), 15, tc)
	else:
		_text(label, Vector2(rr.position.x, cy), 15, tc, rr.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_card() -> void:
	_btns.clear()
	var s := card.size
	var st := updater.state
	var bad := st == "error"
	_box(Rect2(Vector2.ZERO, s), PANEL, OUT, HI, LO)
	if bad:
		card.draw_rect(Rect2(U, U * 2, U, s.y - U * 4), RED)
	else:
		card.draw_rect(Rect2(U, U * 2, U, s.y - U * 4), GREEN)  # liseré vert
	var pad := float(U * 5)
	var ver := str(updater.info.get("version", ""))
	var blink := int(_t * 2.0) % 2 == 0
	match st:
		"available":
			_text("MISE À JOUR", Vector2(pad, U * 10), 18, GREEN_HI)
			_text("v%s  >  v%s" % [updater.version, ver], Vector2(pad, U * 17), 15, TEXT)
			var bw := float(U * 22)
			_button(Rect2(pad, s.y - U * 17, s.x - pad * 2 - bw - U * 3, U * 12), "go", "METTRE À JOUR", true, true)
			_button(Rect2(s.x - pad - bw, s.y - U * 17, bw, U * 12), "later", "PLUS TARD", false)
		"newbin":
			_text("NOUVELLE VERSION", Vector2(pad, U * 10), 18, GREEN_HI)
			_text("v%s : télécharge le nouveau programme." % ver, Vector2(pad, U * 17), 14, TEXT)
			var bw2 := float(U * 22)
			_button(Rect2(pad, s.y - U * 17, s.x - pad * 2 - bw2 - U * 3, U * 12), "open", "TÉLÉCHARGER", true, true)
			_button(Rect2(s.x - pad - bw2, s.y - U * 17, bw2, U * 12), "later", "PLUS TARD", false)
		"downloading":
			_text("TÉLÉCHARGEMENT" + ("." if blink else " "), Vector2(pad, U * 10), 18, GREEN_HI)
			var bar := Rect2(pad, U * 17, s.x - pad * 2, U * 10)
			_box(bar, LO, OUT, LO, LO)
			var n := int((bar.size.x - U * 6) / (U * 4))
			var on := int(round(updater.ratio * n))
			for i in n:
				var seg := Rect2(bar.position.x + U * 3 + i * U * 4, bar.position.y + U * 3, U * 3, U * 4)
				card.draw_rect(seg, GREEN if i < on else Color(1, 1, 1, 0.06))
			_text("%d %%" % int(updater.ratio * 100.0), Vector2(pad, s.y - U * 4), 14, DIM)
		"ready":
			_text("PRÊT !", Vector2(pad, U * 10), 18, GREEN_HI)
			_check(Vector2(s.x - pad - U * 4, U * 8), GREEN)
			if updater.can_restart():
				_text("v%s est installée. Redémarre pour l'utiliser." % ver, Vector2(pad, U * 17), 14, TEXT)
				_button(Rect2(pad, s.y - U * 17, s.x - pad * 2, U * 12), "restart", "REDÉMARRER", true, true)
			else:
				_text("v%s est installée : ferme puis rouvre l'app." % ver, Vector2(pad, U * 17), 14, TEXT)
				_button(Rect2(pad, s.y - U * 17, s.x - pad * 2, U * 12), "close", "OK", true, true)
		"error":
			_text("OUPS", Vector2(pad, U * 10), 18, RED)
			_text(updater.error_msg, Vector2(pad, U * 17), 14, TEXT)
			var bw3 := float(U * 22)
			_button(Rect2(pad, s.y - U * 17, s.x - pad * 2 - bw3 - U * 3, U * 12), "retry", "RÉESSAYER", false)
			_button(Rect2(s.x - pad - bw3, s.y - U * 17, bw3, U * 12), "later", "FERMER", false)


# ------------------------------------------------------------------ clics

func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var h := ""
		for b in _btns:
			if (b[0] as Rect2).has_point(e.position):
				h = b[1]
		if h != _hover:
			_hover = h
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		for b in _btns:
			if (b[0] as Rect2).has_point(e.position):
				_act(b[1])
				return


func _act(id: String) -> void:
	match id:
		"go":
			updater.apply()
		"restart":
			updater.restart()
		"open":
			OS.shell_open(updater.releases_url())
		"retry":
			if updater.info.is_empty():
				updater.state = "idle"
				updater.check()
			else:
				updater.apply()
		"later", "close":
			updater.dismissed = str(updater.info.get("version", ""))
			card.visible = false
			if updater.state in ["error", "ready"]:
				updater.state = "idle"
