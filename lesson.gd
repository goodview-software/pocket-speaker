extends Control
## Conférence en diaporama (paysage) : la salle de classe, un tableau qui affiche la « diapo » en cours
## (titre + phrases en post-it numérotés), une bande de vignettes (le plan) et des boutons ◀ ▶ / DIRECT.
## Le PC découpe la parole en diapos (titre et changement de sujet par Ollama) ; le téléphone reçoit l'état des diapos.

signal slide_changed(sid: int, title: String, ids: Array)
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
var _graph: Control
var _btn_mode: Button
var view_mode := 0  # 0 auto · 1 post-it · 2 carte · 3 tout (toutes les diapos réunies)
const MODES := ["Vue : auto", "Vue : post-it", "Vue : carte", "Vue : tout"]
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
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bv.add_child(_scroll)
	_graph = GraphScript.new()
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph.visible = false
	bv.add_child(_graph)
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
	_btn_mode = _nav_btn(MODES[0], func():
		view_mode = (view_mode + 1) % MODES.size()
		_btn_mode.text = MODES[view_mode]
		_render(false))
	_btn_mode.custom_minimum_size.x = 150
	nav.add_child(_btn_mode)
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
	_refresh()


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
	blocks[id] = {"text": text, "trans": ""}
	if not master:
		return
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


func _render(anim: bool) -> void:
	if _grid == null:
		return
	for c in _grid.get_children():
		c.queue_free()
	if view < 0 or view >= slides.size():
		_title.text = ""
		_graph.visible = false
		_scroll.visible = true
		return
	var sl: Dictionary = slides[view]
	_title.text = sl["title"] if view_mode != 3 else "Toute la conférence"
	var mapped := _show_map(sl)
	_graph.visible = mapped
	_scroll.visible = not mapped
	if mapped:
		return
	var n: int = sl["ids"].size()
	_grid.columns = 1 if n <= 2 else 2
	var k := 0
	var rows := int(ceil(float(n) / _grid.columns))
	var avail := _scroll.size.y if _scroll.size.y > 120.0 else 320.0
	var ch := clampf((avail - 14.0 * (rows - 1)) / maxf(rows, 1), 76.0, 190.0)
	for id in sl["ids"]:
		if not blocks.has(id):
			continue
		var c := Color(POSTIT[int(id) % POSTIT.size()])
		var card := Card.new(c, c.darkened(0.42), 12)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		card.custom_minimum_size = Vector2(0, ch)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		card.add_child(v)
		var num := Label.new()
		num.text = "%d" % (k + 1)
		num.add_theme_font_size_override("font_size", 14)
		num.add_theme_color_override("font_color", Color(0, 0, 0, 0.5))
		v.add_child(num)
		v.add_child(make_label.call(blocks[id]["text"], "#1b1b1b", 28 if n <= 2 else (22 if n <= 4 else 19)))
		if blocks[id]["trans"] != "":
			v.add_child(make_label.call(blocks[id]["trans"], "#1c3d7a", 20 if n <= 2 else 16))
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
	var prompt := "Tu analyses un passage de conférence ou d'histoire. Réponds UNIQUEMENT en JSON de cette forme : {\"affichage\":\"carte\" ou \"post-it\",\"entites\":[{\"nom\":\"...\",\"type\":\"personne|lieu|objet|notion|date\"}],\"liens\":[{\"de\":\"nom\",\"vers\":\"nom\",\"relation\":\"verbe court\"}]}. Règles : inclus TOUJOURS les personnes, lieux, objets, notions et dates importants cités (même s'ils sont peu reliés) ; maximum 8 entités et 10 liens ; noms courts (1 à 3 mots, avec le prénom ou le nom complet d'une personne) et strictement identiques dans les liens et les entités ; un lien va du sujet de la phrase vers son complément (exemple : « Marie épouse Pierre à Paris » donne Marie→Pierre « épouse » et Marie→Paris « vit à »). Mets \"carte\" seulement s'il y a au moins 3 entités reliées entre elles, sinon \"post-it\". Passage :\n" + _passage(sl).left(1500)
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


func _show_map(sl: Dictionary) -> bool:
	var ents: Array = []
	var rels: Array = []
	if view_mode == 3:  # toutes les diapos réunies, doublons fusionnés
		var idx := {}
		for s2 in slides:
			var g2: Dictionary = s2.get("graph", {})
			var local := {}
			for i in g2.get("entities", []).size():
				var e: Dictionary = g2["entities"][i]
				var k: String = e["name"].to_lower()
				if not idx.has(k):
					idx[k] = ents.size()
					ents.append({"name": e["name"], "kind": e["kind"], "count": int(entity_count.get(k, 1))})
				local[i] = idx[k]
			for r in g2.get("relations", []):
				var pair := [local[int(r["a"])], local[int(r["b"])]]
				var dup := false
				for r0 in rels:
					if r0["a"] == pair[0] and r0["b"] == pair[1]:
						dup = true
				if not dup:
					rels.append({"a": pair[0], "b": pair[1], "label": r["label"]})
		if ents.is_empty():
			return false
		_graph.set_graph(ents, rels)
		return true
	var g: Dictionary = sl.get("graph", {})
	var want: bool = view_mode == 2 or (view_mode == 0 and g.get("type", "") == "carte")
	if not want or g.get("entities", []).size() < 2:
		return false
	for e2 in g["entities"]:
		ents.append({"name": e2["name"], "kind": e2["kind"], "count": int(entity_count.get(e2["name"].to_lower(), 1))})
	_graph.set_graph(ents, g["relations"])
	return true
