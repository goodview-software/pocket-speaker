extends Control
## Conférence en diaporama (paysage) : la salle de classe, un tableau qui affiche la « diapo » en cours
## (titre + phrases en post-it numérotés), une bande de vignettes (le plan) et des boutons ◀ ▶ / DIRECT.
## Le PC découpe la parole en diapos (titre et changement de sujet par Ollama) ; le téléphone reçoit l'état des diapos.

signal slide_changed(sid: int, title: String, ids: Array)
signal keyword_changed(id: int, kw: String)
signal graph_changed(sid: int, payload: String)  # carte des entités d'une diapo (JSON compact) → téléphone

const KPx := preload("res://kit/ui/px.gd")
const GraphScript := preload("res://graphview.gd")
const INTER := preload("res://kit/fonts/Inter-500.woff2")
const POSTIT := ["ffe66d", "ff9ecb", "8fe3ff", "b7f08a"]
const MAX_PER_SLIDE := 6
const C_CHALK := Color("f4f1e6")
const C_YELLOW := Color("ffd45e")
const C_BOARD := Color("14352c")

var master := true  # PC : découpe lui-même ; téléphone : applique ce que le PC envoie
var make_label: Callable  # (texte, couleur hex, taille) -> Control (mots cliquables)
var blocks := {}  # id -> {text, trans}
var slides: Array = []  # {id, title, ids, titled}
var view := -1
var follow := true
var next_sid := 1
var shown_sid := -1

var _board: Control
var _title: Label
var _count: Label
var _grid: GridContainer
var _scroll: ScrollContainer
var _strip: HBoxContainer
var _strip_sc: ScrollContainer
var _btn_live: Button
var _empty: Label
var _col: VBoxContainer  # colonne du grand tableau (réutilisée sur le mur 3D)
var in3d := false
var _col_anchors := {}
var _mini: Control  # mini-tableau des entités (à gauche, au-dessus du bureau)
var _pics: HBoxContainer  # cadres photo de la diapo
var images_on := true
var images := {}  # nom (minuscule) -> Texture2D
var _img_asked := {}
var _img_queue: Array = []
var _img_busy := 0
var lang := "fr"
var expanded := {}  # id -> phrase complète dépliée
var current_name := ""  # entité dont on parle en ce moment (cadre en haut à droite du tableau)
var current_kind := "personne"
var _talk: Control
var _talk_tex: TextureRect
var _talk_ph: ColorRect
var _talk_init: Label
var _talk_name: Label
const STOP_WORDS := ["alors", "aussi", "avec", "avoir", "cette", "comme", "dans", "donc", "elle", "elles", "entre", "être", "mais", "même", "nous", "pour", "plus", "puis", "sans", "sont", "tous", "tout", "très", "vous", "that", "this", "with", "from", "have", "were", "they", "their", "there", "which", "about", "para", "pero", "como", "esta", "este", "tiene", "ellos", "ils", "elle"]
var entity_count := {}  # nom -> nombre de diapos où l'entité apparaît
var _ex_pending: Array = []
var _ex_busy := false
var _ex_timer: Timer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	var col := VBoxContainer.new()
	_col = col
	col.anchor_left = 0.36
	col.anchor_right = 1.0
	col.anchor_top = 0.0
	col.anchor_bottom = 1.0
	col.offset_left = 8
	col.offset_right = -24
	col.offset_top = 22
	col.offset_bottom = -18
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	# --- tableau
	_board = Board.new()
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_board)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 10)
	_board.add_child(bv)
	var head := HBoxContainer.new()
	bv.add_child(head)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_override("font", INTER)
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", C_YELLOW)
	head.add_child(_title)
	_talk = Card.new(Color("e9e1c8"), Color("6b4a2f"), 6)
	_talk.visible = false
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	_talk.add_child(tv)
	var tag := Label.new()
	tag.text = "● EN PAROLE"
	tag.add_theme_font_size_override("font_size", 10)
	tag.add_theme_color_override("font_color", Color("c0392b"))
	tv.add_child(tag)
	var pic := Control.new()
	pic.custom_minimum_size = Vector2(96, 96)
	tv.add_child(pic)
	_talk_ph = ColorRect.new()
	_talk_ph.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.add_child(_talk_ph)
	_talk_init = Label.new()
	_talk_init.set_anchors_preset(Control.PRESET_FULL_RECT)
	_talk_init.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_talk_init.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_talk_init.add_theme_font_size_override("font_size", 44)
	_talk_init.add_theme_color_override("font_color", Color(0, 0, 0, 0.45))
	pic.add_child(_talk_init)
	_talk_tex = TextureRect.new()
	_talk_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_talk_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_talk_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.add_child(_talk_tex)
	_talk_name = Label.new()
	_talk_name.custom_minimum_size = Vector2(96, 0)
	_talk_name.clip_text = true
	_talk_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_talk_name.add_theme_font_size_override("font_size", 13)
	_talk_name.add_theme_color_override("font_color", Color("1b1b1b"))
	tv.add_child(_talk_name)
	head.add_child(_talk)
	_count = Label.new()
	_count.add_theme_font_override("font", INTER)
	_count.add_theme_font_size_override("font_size", 16)
	_count.add_theme_color_override("font_color", Color(C_CHALK, 0.7))
	_count.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(_count)
	var rule := ColorRect.new()
	rule.color = Color(C_CHALK, 0.55)
	rule.custom_minimum_size = Vector2(0, 3)
	bv.add_child(rule)
	_pics = HBoxContainer.new()
	_pics.add_theme_constant_override("separation", 12)
	_pics.custom_minimum_size = Vector2(0, 0)
	bv.add_child(_pics)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bv.add_child(_scroll)
	_ex_timer = Timer.new()
	_ex_timer.one_shot = true
	_ex_timer.wait_time = 2.5
	_ex_timer.timeout.connect(_extract_next)
	add_child(_ex_timer)
	var holder := MarginContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_theme_constant_override("margin_right", 6)
	_scroll.add_child(holder)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	holder.add_child(_grid)
	_empty = Label.new()
	_empty.text = "La conférence va commencer…\nLes phrases entendues se rangent ici, diapo par diapo."
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.set_anchors_preset(Control.PRESET_FULL_RECT)
	_empty.add_theme_font_override("font", INTER)
	_empty.add_theme_font_size_override("font_size", 22)
	_empty.add_theme_color_override("font_color", Color(C_CHALK, 0.55))
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(_empty)
	# --- navigation
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	nav.custom_minimum_size = Vector2(0, 40)
	col.add_child(nav)
	nav.add_child(_nav_btn("◀", func(): _go(view - 1)))
	nav.add_child(_nav_btn("▶", func(): _go(view + 1)))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(sp)
	_btn_live = _nav_btn("● DIRECT", func(): _go(slides.size() - 1))
	nav.add_child(_btn_live)
	# --- plan (vignettes)
	_strip_sc = ScrollContainer.new()
	_strip_sc.custom_minimum_size = Vector2(0, 92)
	_strip_sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_strip_sc)
	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", 10)
	_strip_sc.add_child(_strip)
	_mini = GraphScript.new()
	_mini.sc = 0.62
	_mini.images = images
	_mini.node_clicked.connect(func(n: String, k: String): set_current(n, k))
	add_child(_mini)
	_place_mini()
	_refresh()
	var tick := Timer.new()  # l'horloge murale avance
	tick.wait_time = 5.0
	tick.autostart = true
	tick.timeout.connect(queue_redraw)
	add_child(tick)


func _mini_rect() -> Rect2:
	return Rect2(size.x * 0.03, size.y * 0.30, size.x * 0.30, size.y * 0.29)


func _place_mini() -> void:
	if _mini != null and not in3d:
		var r := _mini_rect()
		_mini.position = r.position
		_mini.size = r.size


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place_mini()


func _nav_btn(t: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(58, 38)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(f)
	return b


func _unhandled_key_input(e: InputEvent) -> void:
	if not visible or not (e is InputEventKey) or not e.pressed:
		return
	match e.keycode:
		KEY_LEFT:
			_go(view - 1)
		KEY_RIGHT, KEY_SPACE:
			_go(view + 1)
		KEY_END:
			_go(slides.size() - 1)
		KEY_HOME:
			_go(0)
		_:
			return
	get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ décor

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color("2b3140"))
	for i in range(0, int(h * 0.88), 56):  # lambris
		draw_rect(Rect2(0, i, w, 2), Color("232836"))
	var fy := h * 0.9
	draw_rect(Rect2(0, fy, w, h - fy), Color("6b4a2f"))
	for i in range(0, int(w), 72):
		draw_rect(Rect2(i, fy, 2, h - fy), Color("4e3520"))
	draw_rect(Rect2(0, fy, w, 5), Color("8a6240"))
	draw_rect(Rect2(0, fy - 8, w, 8), Color("3a2a1c"))  # plinthe
	_draw_decor(w, h, fy)


## Décor à gauche, sous la mascotte : horloge (heure réelle), affiche, bureau du professeur avec pomme, livres, tasse et plante.
func _draw_decor(w: float, h: float, fy: float) -> void:
	if w < 700.0:
		return
	var lw := w * 0.34
	# horloge murale
	var cc := Vector2(lw * 0.9, h * 0.095)
	draw_circle(cc, 24, Color("3a2a1c"))
	draw_circle(cc, 21, Color("f4f1e6"))
	for i in 12:
		var a := TAU * i / 12.0
		draw_rect(Rect2(cc + Vector2(cos(a), sin(a)) * 17 - Vector2(1.5, 1.5), Vector2(3, 3)), Color("3a2a1c"))
	var t := Time.get_time_dict_from_system()
	var am := TAU * (float(t["minute"]) / 60.0) - PI / 2.0
	var ah := TAU * ((float(t["hour"] % 12) + float(t["minute"]) / 60.0) / 12.0) - PI / 2.0
	draw_line(cc, cc + Vector2(cos(am), sin(am)) * 16, Color("1b1b1b"), 2.0)
	draw_line(cc, cc + Vector2(cos(ah), sin(ah)) * 10, Color("1b1b1b"), 3.0)
	# mini-tableau des entités (la carte réunit toute la conférence)
	var mr := _mini_rect().grow(12)
	draw_rect(Rect2(mr.position + Vector2(6, 6), mr.size), Color(0, 0, 0, 0.35))
	KPx.panel(self, mr, C_BOARD, Color("a9743f"), false, 2)
	draw_rect(Rect2(mr.position.x + 8, mr.end.y - 3, mr.size.x - 16, 6), Color("c9b79a"))
	var cap := "Tableau des entités"
	draw_string(INTER, mr.position + Vector2(16, 24), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(C_CHALK, 0.6))
	# bureau
	var dy := fy - 96.0
	var dx := lw * 0.06
	var dw := lw * 0.62
	draw_rect(Rect2(dx + 6, dy + 14, dw, 12), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(dx, dy, dw, 14), Color("a9743f"))
	draw_rect(Rect2(dx, dy, dw, 3), Color("c8955c"))
	draw_rect(Rect2(dx + 8, dy + 14, 10, 82), Color("7a5430"))
	draw_rect(Rect2(dx + dw - 18, dy + 14, 10, 82), Color("7a5430"))
	draw_rect(Rect2(dx + 18, dy + 14, dw - 36, 22), Color("8a6240"))
	draw_rect(Rect2(dx + dw * 0.5 - 6, dy + 22, 12, 4), Color("e9d9a8"))
	# livres
	var bx := dx + 20
	for i in 3:
		var bc: Color = [Color("c0504d"), Color("4f81bd"), Color("9bbb59")][i]
		draw_rect(Rect2(bx, dy - 14 - i * 12, 52, 12), bc)
		draw_rect(Rect2(bx, dy - 14 - i * 12, 52, 3), bc.lightened(0.25))
	# pomme
	var ap := Vector2(dx + 100, dy - 8)
	draw_rect(Rect2(ap + Vector2(0, 2), Vector2(16, 12)), Color("d9363e"))
	draw_rect(Rect2(ap + Vector2(2, 0), Vector2(12, 2)), Color("d9363e"))
	draw_rect(Rect2(ap + Vector2(7, -4), Vector2(2, 4)), Color("6b4a2f"))
	draw_rect(Rect2(ap + Vector2(9, -4), Vector2(5, 3)), Color("59a14f"))
	# tasse
	var mp := Vector2(dx + 138, dy - 14)
	draw_rect(Rect2(mp, Vector2(18, 14)), Color("f4f1e6"))
	draw_rect(Rect2(mp + Vector2(18, 3), Vector2(5, 8)), Color("f4f1e6"))
	draw_rect(Rect2(mp + Vector2(3, 2), Vector2(12, 3)), Color("6b4a2f"))
	# plante
	var pp := Vector2(dx + dw - 52, dy - 16)
	draw_rect(Rect2(pp + Vector2(0, 8), Vector2(28, 8)), Color("c0623a"))
	draw_rect(Rect2(pp + Vector2(2, 16), Vector2(24, 2)), Color("a04f2c"))
	for i in 3:
		draw_rect(Rect2(pp + Vector2(4 + i * 9, -6 - (i % 2) * 8), Vector2(6, 16)), Color("59a14f"))
		draw_rect(Rect2(pp + Vector2(4 + i * 9, -6 - (i % 2) * 8), Vector2(6, 4)), Color("7cc46f"))


## Tableau : cadre en bois, fond vert, rebord à craie.
class Board extends MarginContainer:
	func _init() -> void:
		for k in ["left", "right", "top", "bottom"]:
			add_theme_constant_override("margin_" + k, 26 if k != "bottom" else 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(8, 8), r.size), Color(0, 0, 0, 0.35))
		KPx.panel(self, r, Color("14352c"), Color("a9743f"), false, 2)
		draw_rect(Rect2(r.position.x + 10, r.end.y - 4, r.size.x - 20, 8), Color("c9b79a"))
		draw_rect(Rect2(r.position.x + 40, r.end.y - 10, 24, 6), Color("f2f2f2"))
		draw_rect(Rect2(r.position.x + 74, r.end.y - 9, 14, 5), Color("ffd45e"))


## Carte pixel (post-it ou vignette).
class Card extends MarginContainer:
	var fill := Color.WHITE
	var edge := Color.BLACK

	func _init(f: Color, e: Color, pad := 10) -> void:
		fill = f
		edge = e
		for k in ["left", "right", "top", "bottom"]:
			add_theme_constant_override("margin_" + k, pad)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		KPx.panel(self, Rect2(Vector2.ZERO, size), fill, edge, true, 1)


# ------------------------------------------------------------------ données

func clear() -> void:
	entity_count.clear()
	if _mini != null:
		_mini.set_graph([], [])
	_ex_pending.clear()
	blocks.clear()
	slides.clear()
	view = -1
	follow = true
	shown_sid = -1
	_refresh()


func set_trans(id: int, t: String) -> void:
	if blocks.has(id):
		blocks[id]["trans"] = t
		_render(false)


func add_sentence(id: int, text: String) -> void:
	blocks[id] = {"text": text, "trans": "", "kw": _heuristic_kw(text)}
	note_text(text)
	if not master:
		return
	_ask_kw(id, text)
	var sl: Dictionary = slides.back() if not slides.is_empty() else {}
	if sl.is_empty() or sl["ids"].size() >= MAX_PER_SLIDE:
		sl = _new_slide([id], _first_words(text), false)
		if slides.size() > 1:
			slide_changed.emit(slides[-2]["id"], slides[-2]["title"], slides[-2]["ids"].duplicate())
	else:
		sl["ids"].append(id)
		var n: int = sl["ids"].size()
		if n == 2 and not sl["titled"]:
			_ask_title(sl)
		elif n >= 3 and text.split(" ", false).size() >= 4:
			_ask_topic(sl, id, text)
	slide_changed.emit(sl["id"], sl["title"], sl["ids"].duplicate())
	_schedule_extract(sl["id"])
	_refresh()


## Téléphone : état d'une diapo envoyé par le PC.
func apply_slide(sid: int, title: String, ids: Array) -> void:
	var sl := _find(sid)
	if sl.is_empty():
		sl = {"id": sid, "title": title, "ids": ids, "titled": true}
		slides.append(sl)
		slides.sort_custom(func(a, b): return a["id"] < b["id"])
	else:
		sl["title"] = title
		sl["ids"] = ids
	_refresh()


func _find(sid: int) -> Dictionary:
	for s in slides:
		if s["id"] == sid:
			return s
	return {}


func _new_slide(ids: Array, title: String, titled: bool) -> Dictionary:
	var sl := {"id": next_sid, "title": title, "ids": ids, "titled": titled}
	next_sid += 1
	slides.append(sl)
	return sl


func _first_words(t: String) -> String:
	var w := t.split(" ", false)
	return " ".join(w.slice(0, 4)) + ("…" if w.size() > 4 else "")


func _passage(sl: Dictionary) -> String:
	var out: Array = []
	for i in sl["ids"]:
		if blocks.has(i):
			out.append(blocks[i]["text"])
	return " ".join(out)


# ------------------------------------------------------------------ Ollama (titres et changements de sujet)

func _llm(prompt: String, cb: Callable, model_name := "", as_json := false, tokens := 30) -> void:
	var model := model_name if model_name != "" else (OS.get_environment("POCKET_CHAT_MODEL") if OS.get_environment("POCKET_CHAT_MODEL") != "" else "gemma3:4b")
	var http := HTTPRequest.new()
	http.timeout = 60 if as_json else 30
	add_child(http)
	http.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		var ans := ""
		if code == 200:
			var j: Variant = JSON.parse_string(body.get_string_from_utf8())
			if j is Dictionary:
				ans = str(j.get("response", "")).strip_edges()
		cb.call(ans))
	if http.request("http://127.0.0.1:11434/api/generate", ["Content-Type: application/json"], HTTPClient.METHOD_POST,
			JSON.stringify({"model": model, "prompt": prompt, "stream": false, "keep_alive": "30m", "think": false,
			"format": "json" if as_json else "", "options": {"temperature": 0, "num_predict": tokens}})) != OK:
		http.queue_free()


func _clean_title(t: String) -> String:
	t = t.split("\n")[0].strip_edges().trim_prefix("«").trim_suffix("»").trim_prefix("\"").trim_suffix("\"").trim_suffix(".")
	return t.left(46)


func _ask_title(sl: Dictionary) -> void:
	var sid: int = sl["id"]
	_llm("Donne un titre très court (3 à 5 mots, sans guillemets, sans point, dans la langue du texte) pour ce passage d'une conférence :\n\n" + _passage(sl).left(600), func(ans: String):
		var s := _find(sid)
		var t := _clean_title(ans)
		if s.is_empty() or t == "":
			return
		s["title"] = t
		s["titled"] = true
		slide_changed.emit(sid, t, s["ids"].duplicate())
		_refresh())


func _ask_topic(sl: Dictionary, id: int, text: String) -> void:
	var sid: int = sl["id"]
	_llm("Titre de la partie en cours d'une conférence : « %s ».\nNouvelle phrase : « %s »\nCette phrase ouvre-t-elle clairement un NOUVEAU sujet ? Réponds exactement SAME si non, ou NEW: suivi d'un titre très court (3 à 5 mots) du nouveau sujet." % [sl["title"], text], func(ans: String):
		if not ans.to_upper().begins_with("NEW"):
			return
		var s := _find(sid)
		if s.is_empty():
			return
		var idx: int = s["ids"].find(id)
		if idx < 1:
			return
		var title := _clean_title(ans.substr(3).trim_prefix(":"))
		var moved: Array = s["ids"].slice(idx)
		s["ids"] = s["ids"].slice(0, idx)
		var ns := _new_slide(moved, title if title != "" else _first_words(text), title != "")
		slide_changed.emit(sid, s["title"], s["ids"].duplicate())
		slide_changed.emit(ns["id"], ns["title"], ns["ids"].duplicate())
		_refresh())


# ------------------------------------------------------------------ affichage

func _go(i: int) -> void:
	if slides.is_empty():
		return
	view = clampi(i, 0, slides.size() - 1)
	follow = view == slides.size() - 1
	_refresh()


func _refresh() -> void:
	if _board == null:
		return
	if follow or view >= slides.size() or view < 0:
		view = slides.size() - 1
	_count.text = "" if slides.is_empty() else "Diapo %d / %d" % [view + 1, slides.size()]
	_btn_live.modulate = Color(1, 1, 1, 1.0) if follow else Color(1, 0.8, 0.4, 1.0)
	_btn_live.text = "● DIRECT" if follow else "▶ Revenir au direct"
	_empty.visible = slides.is_empty()
	_render(true)
	_build_strip()
	_update_mini()


func _render(anim: bool) -> void:
	if _grid == null:
		return
	for c in _grid.get_children():
		c.queue_free()
	if view < 0 or view >= slides.size():
		_title.text = ""
		_fill_pics({})
		return
	var sl: Dictionary = slides[view]
	_title.text = sl["title"]
	_fill_pics(sl)
	var n: int = sl["ids"].size()
	_grid.columns = clampi(n, 1, 3)
	var k := 0
	for id in sl["ids"]:
		if not blocks.has(id):
			continue
		var b: Dictionary = blocks[id]
		var c := Color(POSTIT[int(id) % POSTIT.size()])
		var card := Card.new(c, c.darkened(0.42), 10)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		card.custom_minimum_size = Vector2(0, 104)
		card.tooltip_text = b["text"]
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(v)
		var num := Label.new()
		num.text = "%d" % (k + 1)
		num.add_theme_font_size_override("font_size", 13)
		num.add_theme_color_override("font_color", Color(0, 0, 0, 0.5))
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(num)
		var kwl := Label.new()
		kwl.text = b["kw"]
		kwl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		kwl.add_theme_font_override("font", INTER)
		kwl.add_theme_font_size_override("font_size", 30 if n <= 3 else 26)
		kwl.add_theme_color_override("font_color", Color("1b1b1b"))
		kwl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(kwl)
		if expanded.get(id, false):  # clic : la phrase complète (mots cliquables pour la définition) et sa traduction
			var full: Control = make_label.call(b["text"], "#1b1b1b", 18)
			v.add_child(full)
			if b["trans"] != "":
				v.add_child(make_label.call(b["trans"], "#1c3d7a", 15))
		var cid: int = id
		card.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				expanded[cid] = not expanded.get(cid, false)
				_render(false))
		_grid.add_child(card)
		k += 1
	if anim and sl["id"] != shown_sid:  # transition de diapo : glissement + fondu
		shown_sid = sl["id"]
		_grid.modulate.a = 0.0
		_title.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_grid, "modulate:a", 1.0, 0.28)
		tw.tween_property(_title, "modulate:a", 1.0, 0.2)
	await get_tree().process_frame
	if is_instance_valid(_scroll) and follow:
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _build_strip() -> void:
	for c in _strip.get_children():
		c.queue_free()
	for i in slides.size():
		var sl: Dictionary = slides[i]
		var cur := i == view
		var card := Card.new(Color("1d4a3d") if cur else Color("163a31"), Color("ffd45e") if cur else Color("a9743f"), 8)
		card.custom_minimum_size = Vector2(168, 76)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var l := Label.new()
		l.text = "%d  %s" % [i + 1, sl["title"]]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(150, 56)
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		card.clip_contents = true
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_override("font", INTER)
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", C_YELLOW if cur else C_CHALK)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(l)
		var idx := i
		card.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_go(idx))
		_strip.add_child(card)
	await get_tree().process_frame
	if is_instance_valid(_strip_sc) and follow:
		_strip_sc.scroll_horizontal = int(_strip_sc.get_h_scroll_bar().max_value)


# ------------------------------------------------------------------ carte des entités (qwen3:8b)

func _schedule_extract(sid: int) -> void:
	if not master:
		return
	if not _ex_pending.has(sid):
		_ex_pending.append(sid)
	_ex_timer.start()  # on attend 2,5 s sans nouvelle phrase


func _extract_next() -> void:
	if _ex_busy or _ex_pending.is_empty():
		return
	var sid: int = _ex_pending.pop_front()
	var sl := _find(sid)
	if sl.is_empty() or sl["ids"].size() < 2:
		_extract_next()
		return
	_ex_busy = true
	var model := OS.get_environment("POCKET_GRAPH_MODEL") if OS.get_environment("POCKET_GRAPH_MODEL") != "" else "qwen3:8b"
	var prompt := "Tu analyses un passage de conférence ou d'histoire. Réponds UNIQUEMENT en JSON de cette forme : {\"affichage\":\"carte\" ou \"post-it\",\"entites\":[{\"nom\":\"...\",\"type\":\"personne|lieu|objet|notion|date\"}],\"liens\":[{\"de\":\"nom\",\"vers\":\"nom\",\"relation\":\"verbe court\"}]}. Règles : ne garde QUE des entités nommées ou des notions importantes (personnes, lieux, organisations, œuvres, événements, objets précis, dates précises) ; ignore les mots courants, les nombres, les adverbes, les verbes et les interjections ; inclus toujours les personnes et lieux cités ; maximum 8 entités et 10 liens ; noms courts (1 à 3 mots, avec le prénom ou le nom complet d'une personne) et strictement identiques dans les liens et les entités ; un lien va du sujet de la phrase vers son complément (exemple : « Marie épouse Pierre à Paris » donne Marie→Pierre « épouse » et Marie→Paris « vit à »). Mets \"carte\" seulement s'il y a au moins 3 entités reliées entre elles, sinon \"post-it\". Passage :\n" + _passage(sl).left(1500)
	_llm(prompt, func(ans: String):
		_ex_busy = false
		_apply_extract(sid, ans)
		_extract_next(), model, true, 450)


func _apply_extract(sid: int, ans: String) -> void:
	var sl := _find(sid)
	var j: Variant = JSON.parse_string(ans)
	if sl.is_empty() or not (j is Dictionary):
		return
	var ents: Array = []
	var idx := {}
	for e in j.get("entites", []):
		if not (e is Dictionary):
			continue
		var nm := str(e.get("nom", "")).strip_edges().left(28)
		var kd := str(e.get("type", "notion")).to_lower()
		if nm == "" or idx.has(nm.to_lower()) or ents.size() >= 8:
			continue
		idx[nm.to_lower()] = ents.size()
		ents.append({"name": nm, "kind": kd if kd in ["personne", "lieu", "objet", "notion", "date"] else "notion"})
	var rels: Array = []
	for r in j.get("liens", []):
		if not (r is Dictionary):
			continue
		var a: String = str(r.get("de", "")).strip_edges().to_lower()
		var b: String = str(r.get("vers", "")).strip_edges().to_lower()
		if idx.has(a) and idx.has(b) and a != b and rels.size() < 10:
			rels.append({"a": idx[a], "b": idx[b], "label": str(r.get("relation", "")).strip_edges().left(22)})
	var g := {"type": "carte" if str(j.get("affichage", "")) == "carte" and ents.size() >= 3 and not rels.is_empty() else "post-it", "entities": ents, "relations": rels}
	_set_graph(sl, g)
	graph_changed.emit(sid, JSON.stringify(g))


func _set_graph(sl: Dictionary, g: Dictionary) -> void:
	for e in sl.get("graph", {}).get("entities", []):  # on retire l'ancien décompte de cette diapo
		var k: String = e["name"].to_lower()
		entity_count[k] = maxi(0, int(entity_count.get(k, 1)) - 1)
	sl["graph"] = g
	for e in g["entities"]:
		var k2: String = e["name"].to_lower()
		entity_count[k2] = int(entity_count.get(k2, 0)) + 1
	_refresh()


## Téléphone : carte d'une diapo envoyée par le PC.
func apply_graph(sid: int, payload: String) -> void:
	var sl := _find(sid)
	var j: Variant = JSON.parse_string(payload)
	if sl.is_empty() or not (j is Dictionary):
		return
	_set_graph(sl, j)


# ------------------------------------------------------------------ mini-tableau (toute la conférence) et photos

func _update_mini() -> void:
	if _mini == null:
		return
	var ents: Array = []
	var rels: Array = []
	var idx := {}
	for s2 in slides:  # on fusionne toutes les diapos : un nom = un nœud
		var g2: Dictionary = s2.get("graph", {})
		var local := {}
		for i in g2.get("entities", []).size():
			var e: Dictionary = g2["entities"][i]
			var k: String = e["name"].to_lower()
			if not idx.has(k):
				idx[k] = ents.size()
				ents.append({"name": e["name"], "kind": e["kind"], "count": int(entity_count.get(k, 1)), "last": s2["id"]})
			else:
				ents[idx[k]]["last"] = s2["id"]
			local[i] = idx[k]
		for r in g2.get("relations", []):
			if not (local.has(int(r["a"])) and local.has(int(r["b"]))):
				continue
			var pa: int = local[int(r["a"])]
			var pb: int = local[int(r["b"])]
			var dup := false
			for r0 in rels:
				if r0["a"] == pa and r0["b"] == pb:
					dup = true
			if not dup:
				rels.append({"a": pa, "b": pb, "label": r["label"]})
	if ents.size() > 12:  # le mini-tableau garde les plus importantes (souvent citées, récentes)
		var order := range(ents.size())
		order.sort_custom(func(a, b): return [ents[a]["count"], ents[a]["last"]] > [ents[b]["count"], ents[b]["last"]])
		var keep: Array = order.slice(0, 12)
		var remap := {}
		var ents2: Array = []
		for o in keep:
			remap[o] = ents2.size()
			ents2.append(ents[o])
		var rels2: Array = []
		for r in rels:
			if remap.has(r["a"]) and remap.has(r["b"]):
				rels2.append({"a": remap[r["a"]], "b": remap[r["b"]], "label": r["label"]})
		ents = ents2
		rels = rels2
	# sujets : le titre de chaque diapo devient un nœud relié aux entités dont on y parle (vidéo, conversation…)
	var topics := 0
	for si in range(slides.size() - 1, -1, -1):
		var s3: Dictionary = slides[si]
		var g3: Dictionary = s3.get("graph", {})
		var members: Array = []
		for e3 in g3.get("entities", []):
			var k3: String = e3["name"].to_lower()
			for ei in ents.size():
				if ents[ei]["name"].to_lower() == k3:
					members.append(ei)
		if members.size() < 2 or topics >= 4:
			continue
		topics += 1
		var ti := ents.size()
		ents.append({"name": s3["title"], "kind": "sujet", "count": 1, "last": s3["id"]})
		for mi in members:
			rels.append({"a": ti, "b": mi, "label": "", "topic": true})
	_mini.set_graph(ents, rels)
	for e in ents:
		_want_image(e)


func _fill_pics(sl: Dictionary) -> void:
	for c in _pics.get_children():
		c.queue_free()
	if sl.is_empty() or not images_on:
		return
	var shown := 0
	for e in sl.get("graph", {}).get("entities", []):
		var k: String = e["name"].to_lower()
		if shown >= 4 or not images.has(k) or images[k] == null:
			continue
		var card := Card.new(Color("e9e1c8"), Color("6b4a2f"), 6)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		card.add_child(v)
		var tr := TextureRect.new()
		tr.texture = images[k]
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.custom_minimum_size = Vector2(92, 92)
		v.add_child(tr)
		var cap := Label.new()
		cap.text = e["name"]
		cap.custom_minimum_size = Vector2(92, 0)
		cap.clip_text = true
		cap.add_theme_font_size_override("font_size", 12)
		cap.add_theme_color_override("font_color", Color("1b1b1b"))
		v.add_child(cap)
		_pics.add_child(card)
		shown += 1


## Photo Wikipédia (libre de droits) d'une personne, d'un lieu ou d'un objet : seul le nom cité est envoyé, avec l'interrupteur « Images ».
func _want_image(e: Dictionary) -> void:
	var k: String = e["name"].to_lower()
	if not images_on or _img_asked.has(k) or not (e["kind"] in ["personne", "lieu", "objet"]):
		return
	_img_asked[k] = true
	_img_queue.append(e["name"])
	_img_next()


func _img_next() -> void:
	while _img_busy < 2 and not _img_queue.is_empty():
		_img_busy += 1
		_img_fetch(_img_queue.pop_front())


func _img_cache_path(name: String) -> String:
	return "user://img/" + name.to_lower().md5_text() + ".png"


func _img_done(name: String, tex: Texture2D) -> void:
	_img_busy -= 1
	if tex != null:
		images[name.to_lower()] = tex
		_mini.queue_redraw()
		_update_talk()
		_render(false)
	_img_next()


func _img_fetch(name: String) -> void:
	var cp := _img_cache_path(name)
	if FileAccess.file_exists(cp):
		var im := Image.load_from_file(cp)
		_img_done(name, ImageTexture.create_from_image(im) if im != null else null)
		return
	var ua := ["User-Agent: PocketSpeaker/1.0 (conference captions; wikipedia thumbnails)"]
	var host := "https://%s.wikipedia.org" % lang
	var http := HTTPRequest.new()
	http.timeout = 12
	add_child(http)
	http.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		var url := ""
		if code == 200:
			var j: Variant = JSON.parse_string(body.get_string_from_utf8())
			if j is Dictionary and j.has("query"):
				for pg in j["query"].get("pages", {}).values():
					if pg is Dictionary and pg.has("thumbnail"):
						url = str(pg["thumbnail"].get("source", ""))
						break
		if url == "":
			_img_done(name, null)
			return
		var h2 := HTTPRequest.new()
		h2.timeout = 15
		add_child(h2)
		h2.request_completed.connect(func(_r2: int, c2: int, _hh: PackedStringArray, b2: PackedByteArray):
			h2.queue_free()
			var im2 := Image.new()
			var err := ERR_FILE_UNRECOGNIZED
			if c2 == 200 and b2.size() > 8:
				if b2[0] == 0xFF:
					err = im2.load_jpg_from_buffer(b2)
				elif b2[0] == 0x89:
					err = im2.load_png_from_buffer(b2)
				elif b2[0] == 0x52:
					err = im2.load_webp_from_buffer(b2)
			if err != OK:
				_img_done(name, null)
				return
			DirAccess.make_dir_recursive_absolute("user://img")
			im2.save_png(cp)
			_img_done(name, ImageTexture.create_from_image(im2)))
		if h2.request(url, ua) != OK:
			h2.queue_free()
			_img_done(name, null))
	var q := "%s/w/api.php?action=query&generator=search&gsrsearch=%s&gsrlimit=1&prop=pageimages&piprop=thumbnail&pithumbsize=240&format=json" % [host, name.uri_encode()]
	if http.request(q, ua) != OK:
		http.queue_free()
		_img_done(name, null)


# ------------------------------------------------------------------ mots-clés (mini post-it) et « qui parle »

func _heuristic_kw(t: String) -> String:
	var longest := ""
	var proper := ""
	var words := t.split(" ", false)
	for i in words.size():
		var w: String = words[i].strip_edges().trim_suffix(",").trim_suffix(".").trim_suffix("?").trim_suffix("!")
		if w.length() < 4 or w.to_lower() in STOP_WORDS:
			continue
		if i > 0 and proper == "" and w[0] != w[0].to_lower():  # nom propre (majuscule hors début de phrase)
			proper = w
		if w.length() > longest.length():
			longest = w
	var kw := proper if proper != "" else longest
	return kw.capitalize() if kw != "" else _first_words(t)


func _ask_kw(id: int, text: String) -> void:
	_llm("Donne UN mot-clé (1 à 3 mots, sans ponctuation, dans la langue de la phrase) qui résume le sujet de cette phrase. Réponds uniquement par le mot-clé.\n\n" + text.left(300), func(ans: String):
		var kw := _clean_title(ans).left(24)
		if kw == "" or not blocks.has(id):
			return
		blocks[id]["kw"] = kw
		keyword_changed.emit(id, kw)
		_render(false))


func apply_keyword(id: int, kw: String) -> void:
	if blocks.has(id):
		blocks[id]["kw"] = kw
		_render(false)


## Repère l'entité citée le plus récemment dans le texte (voix en direct ou phrase) : c'est « celui dont on parle ».
func note_text(t: String) -> void:
	if t.length() < 3:
		return
	var low := t.to_lower()
	var best := -1
	var bn := ""
	var bk := ""
	for sl in slides:
		for e in sl.get("graph", {}).get("entities", []):
			var pos := low.rfind(String(e["name"]).to_lower())
			if pos > best:
				best = pos
				bn = e["name"]
				bk = e["kind"]
	if best >= 0 and bn != current_name:
		set_current(bn, bk)


func set_current(n: String, kind: String) -> void:
	current_name = n
	current_kind = kind
	_want_image({"name": n, "kind": kind})
	_update_talk()


func _update_talk() -> void:
	if _talk == null:
		return
	_talk.visible = current_name != ""
	if current_name == "":
		return
	_talk_name.text = current_name
	var col := Color(GraphScript.KIND_COL.get(current_kind, "f4f1e6"))
	_talk_ph.color = col
	_talk_init.text = current_name.left(1).to_upper()
	var tex: Variant = images.get(current_name.to_lower(), null)
	_talk_tex.texture = tex
	_talk_tex.visible = tex != null


# ------------------------------------------------------------------ salle 3D : les tableaux deviennent des écrans sur les murs

func attach_3d(vpb: SubViewport, vpg: SubViewport, th: Theme) -> void:
	if in3d:
		return
	in3d = true
	_col_anchors = {"l": _col.anchor_left, "r": _col.anchor_right, "t": _col.anchor_top, "b": _col.anchor_bottom,
		"ol": _col.offset_left, "or": _col.offset_right, "ot": _col.offset_top, "ob": _col.offset_bottom}
	remove_child(_col)
	vpb.add_child(_col)
	_col.theme = th
	_col.set_anchors_preset(Control.PRESET_FULL_RECT)
	_col.offset_left = 18
	_col.offset_right = -18
	_col.offset_top = 14
	_col.offset_bottom = -12
	remove_child(_mini)
	vpg.add_child(_mini)
	_mini.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mini.offset_left = 0
	_mini.offset_right = 0
	_mini.offset_top = 0
	_mini.offset_bottom = 0
	_mini.framed = true
	_mini.queue_redraw()
	_refresh()


func detach_3d() -> void:
	if not in3d:
		return
	in3d = false
	_col.get_parent().remove_child(_col)
	add_child(_col)
	_col.theme = null
	_col.anchor_left = _col_anchors["l"]
	_col.anchor_right = _col_anchors["r"]
	_col.anchor_top = _col_anchors["t"]
	_col.anchor_bottom = _col_anchors["b"]
	_col.offset_left = _col_anchors["ol"]
	_col.offset_right = _col_anchors["or"]
	_col.offset_top = _col_anchors["ot"]
	_col.offset_bottom = _col_anchors["ob"]
	_mini.get_parent().remove_child(_mini)
	add_child(_mini)
	_mini.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_mini.framed = false
	_place_mini()
	queue_redraw()
	_refresh()
