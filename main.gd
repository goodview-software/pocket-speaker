extends Control
## Pocket Speaker : le téléphone devient l'enceinte + le micro du PC (USB ou Wi-Fi).
## PC : adb (installe/lance l'app, `adb forward`) ou Wi-Fi, sorties PulseAudio virtuelles, capture -> TCP.
## Téléphone : écoute sur PORT, joue le son reçu, renvoie son micro.
##
## Trame : [type u8][longueur u16 LE][données]

const PORT := 5105
const BEACON_PORT := PORT + 1  # téléphone -> réseau (UDP) : "POCKET"
const RATE := 48000
const PKG := "fr.goodview.pocketspeaker"
const VERSION := 1  # versionCode de l'APK
const APP_VERSION := "0.1.0"
const T_AUDIO := 1  # PC -> téléphone : PCM s16 stéréo 48 kHz
const T_MIC := 2  # téléphone -> PC : PCM s16 mono
const T_HELLO := 3  # téléphone -> PC : u32 fréquence micro + nom du téléphone
const T_NAME := 4  # PC -> téléphone : [variante de mascotte u8] + nom du PC
const T_CTRL := 5  # [son u8, micro u8, volume 0-100 u8] (dans les deux sens)
const T_PING := 7
const T_PONG := 8
const SINK := "pocket_out"
const MIC_SINK := "pocket_mic_sink"
const MIC_SRC := "pocket_mic_sink.monitor"
const CHUNK := RATE / 50  # 20 ms

const C_BG := Color("0e1116")
const C_CARD := Color("171b22")
const C_TEXT := Color("e8ecf1")
const C_DIM := Color("8892a0")
const C_OK := Color("4de1b4")
const C_WAIT := Color("ffb454")
const C_IDLE := Color("5b6573")

enum { ST_IDLE, ST_WAIT, ST_LINKED }


# ------------------------------------------------------------------ Widgets dessinés

class Orb extends Control:
	const SHEET := preload("res://mascot/goody.png")
	const ANIMS := {"idle": [0, 4], "happy": [1, 4], "wait": [2, 4], "off": [3, 4], "sad": [4, 4]}
	const FPS := {"idle": 3.0, "happy": 6.0, "wait": 3.0, "off": 1.5, "sad": 2.0}
	var color := Color("5b6573")
	var variant := 0
	var level := 0.0
	var pulse := 0.0
	var t := 0.0
	var anim := "off":
		set(v):
			if v != anim:
				anim = v
				t = 0.0

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(d: float) -> void:
		pulse = fposmod(pulse + d, TAU)
		t += d * FPS[anim] * (1.0 + level * 1.5)
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.26
		for i in 4:
			var rr := r + 8.0 * (i + 1) + level * 14.0 + sin(pulse + i) * 2.0
			draw_circle(c, rr, Color(color, 0.11 - i * 0.025))
		draw_circle(c, r, Color(color, 0.16))
		var row: int = ANIMS[anim][0] + variant * 5
		var n: int = ANIMS[anim][1]
		var sc := maxi(1, int(size.y * 0.72 / 32.0))
		var px := 32 * sc
		var bob := 0.0 if anim != "idle" else 0.0
		var pos := (c - Vector2(px, px) / 2.0 + Vector2(0, bob)).round()
		draw_texture_rect_region(SHEET, Rect2(pos, Vector2(px, px)), Rect2((int(t) % n) * 32, row * 32, 32, 32))


class Meter extends Control:
	var value := 0.0
	var shown := 0.0
	var peak := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 14)

	func _process(d: float) -> void:
		shown = move_toward(shown, value, d * (8.0 if value > shown else 2.5))
		peak = maxf(peak - d * 0.4, shown)
		queue_redraw()

	func _draw() -> void:
		var n := 30
		var gap := 3.0
		var w := (size.x - gap * (n - 1)) / n
		var pk := int(peak * n)
		for i in n:
			var f := (i + 1.0) / n
			var col := Color("4de1b4")
			if f > 0.85:
				col = Color("ff6b6b")
			elif f > 0.65:
				col = Color("ffb454")
			var lit := f <= shown or i == pk - 1
			draw_rect(Rect2(i * (w + gap), 0, w, size.y), col if lit else Color(1, 1, 1, 0.07), true)


class Ico:
	static func box(ci: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(int(rad))
		sb.anti_aliasing_size = 1.0
		ci.draw_style_box(sb, r)

	static func draw_kind(ci: CanvasItem, kind: String, c: Vector2, k: float, col: Color) -> void:
		match kind:
			"speaker", "speaker_low":
				var body := PackedVector2Array([Vector2(-18, -9), Vector2(-6, -9), Vector2(8, -21),
						Vector2(8, 21), Vector2(-6, 9), Vector2(-18, 9)])
				for i in body.size():
					body[i] = c + Vector2(-4, 0) * k + body[i] * k
				ci.draw_colored_polygon(body, col)
				if kind == "speaker":
					ci.draw_arc(c + Vector2(6, 0) * k, 12.0 * k, -0.9, 0.9, 16, col, 3.0 * k, true)
					ci.draw_arc(c + Vector2(6, 0) * k, 23.0 * k, -0.9, 0.9, 20, Color(col, 0.6), 3.0 * k, true)
			"mic":
				box(ci, Rect2(c + Vector2(-8, -22) * k, Vector2(16, 28) * k), 8.0 * k, col)
				ci.draw_arc(c + Vector2(0, -2) * k, 15.0 * k, 0.0, PI, 24, col, 3.0 * k, true)
				ci.draw_line(c + Vector2(0, 13) * k, c + Vector2(0, 22) * k, col, 3.0 * k, true)
				ci.draw_line(c + Vector2(-8, 22) * k, c + Vector2(8, 22) * k, col, 3.0 * k, true)
			"usb":
				ci.draw_line(c + Vector2(-22, 0) * k, c + Vector2(20, 0) * k, col, 3.0 * k, true)
				ci.draw_circle(c + Vector2(-24, 0) * k, 5.5 * k, col)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(18, -7) * k, c + Vector2(30, 0) * k,
						c + Vector2(18, 7) * k]), col)
				ci.draw_polyline(PackedVector2Array([c + Vector2(-8, 0) * k, c + Vector2(0, -13) * k,
						c + Vector2(10, -13) * k]), col, 3.0 * k, true)
				ci.draw_rect(Rect2(c + Vector2(10, -17) * k, Vector2(8, 8) * k), col)
				ci.draw_polyline(PackedVector2Array([c + Vector2(2, 0) * k, c + Vector2(10, 12) * k]), col, 3.0 * k, true)
				ci.draw_circle(c + Vector2(12, 12) * k, 4.5 * k, col)
			"wifi":
				ci.draw_circle(c + Vector2(0, 16) * k, 3.5 * k, col)
				for r in [12.0, 22.0, 32.0]:
					ci.draw_arc(c + Vector2(0, 16) * k, r * k, -2.36, -0.78, 20, col, 3.0 * k, true)
			"auto":
				var st := PackedVector2Array([Vector2(0, -22), Vector2(5, -5), Vector2(22, 0), Vector2(5, 5),
						Vector2(0, 22), Vector2(-5, 5), Vector2(-22, 0), Vector2(-5, -5)])
				for i in st.size():
					st[i] = c + st[i] * k
				ci.draw_colored_polygon(st, col)


class Icon extends Control:
	var kind := "speaker"
	var col := Color.WHITE:
		set(v):
			if v != col:
				col = v
				queue_redraw()

	func _init(k := "speaker") -> void:
		kind = k
		custom_minimum_size = Vector2(40, 40)

	func _draw() -> void:
		Ico.draw_kind(self, kind, size / 2.0, minf(size.x, size.y) / 46.0, col)


class Seg extends Control:
	signal picked(id: int)
	var ids: Array = []
	var kinds: Array = []
	var sel := 0
	var hi := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 54)

	func setup(k: Array, i: Array, cur: int) -> void:
		kinds = k
		ids = i
		sel = maxi(0, ids.find(cur))
		hi = sel

	func _process(d: float) -> void:
		hi = move_toward(hi, sel, d * 14.0)
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not ids.is_empty():
			sel = clampi(int(e.position.x / (size.x / ids.size())), 0, ids.size() - 1)
			picked.emit(ids[sel])
			accept_event()

	func _draw() -> void:
		if ids.is_empty():
			return
		Ico.box(self, Rect2(Vector2.ZERO, size), size.y / 2.0, Color("232a34"))
		var w := size.x / ids.size()
		Ico.box(self, Rect2(Vector2(hi * w + 4, 4), Vector2(w - 8, size.y - 8)), (size.y - 8) / 2.0, Color("4de1b4", 0.22))
		for i in ids.size():
			var on := i == sel
			Ico.draw_kind(self, kinds[i], Vector2((i + 0.5) * w, size.y / 2.0), 0.55,
					Color("4de1b4") if on else Color("8892a0"))


class Toggle extends Control:
	signal toggled(on: bool)
	var on := false
	var t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(58, 34)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func set_on(v: bool) -> void:  # sans émettre de signal
		on = v

	func _process(d: float) -> void:
		t = move_toward(t, 1.0 if on else 0.0, d * 9.0)
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			on = not on
			toggled.emit(on)
			accept_event()

	func _draw() -> void:
		var h := size.y
		var bg := Color("2a313c").lerp(Color("4de1b4"), t)
		draw_rect(Rect2(h / 2, 0, size.x - h, h), bg, true)
		draw_circle(Vector2(h / 2, h / 2), h / 2, bg)
		draw_circle(Vector2(size.x - h / 2, h / 2), h / 2, bg)
		draw_circle(Vector2(lerpf(h / 2, size.x - h / 2, t) + 0.0, h / 2 + 1.0), h / 2 - 3, Color(0, 0, 0, 0.25))
		draw_circle(Vector2(lerpf(h / 2, size.x - h / 2, t), h / 2), h / 2 - 4, Color.WHITE)


# ------------------------------------------------------------------ État

var is_phone := OS.has_feature("android") or OS.get_environment("POCKET_PHONE") == "1"
var test_mode := OS.get_environment("POCKET_TEST") == "1"
var peer: StreamPeerTCP
var rxbuf := PackedByteArray()
var linked := false
var state := ST_IDLE
var want_sound := true
var want_mic := false
var vol := 1.0
var lvl_out := 0.0
var lvl_mic := 0.0
var rtt_ms := -1
var link_mode := 0  # 0 auto · 1 Wi-Fi · 2 USB
var peer_name := ""
var mic_rate := 48000
var linked_t := 0.0
var mascot := 0  # variante de Goody choisie dans le Goodview Launcher (profil partagé)
var mascot_t := 0.0

# UI
var orb: Orb
var status: Label
var sub: Label
var chip: Label
var chip_sb: StyleBoxFlat
var ico_sound: Icon
var ico_mic: Icon
var meter_out: Meter
var meter_mic: Meter
var tog_sound: Toggle
var tog_mic: Toggle
var vol_slider: HSlider
var content: VBoxContainer

# PC
var adb_bin := "adb"
var th_adb: Thread
var mtx := Mutex.new()
var quit := false
var adb_state := "none"
var adb_msg := ""
var cap_pid := -1
var cap_io: FileAccess
var th_cap: Thread
var cap_queue: Array = []
var mic_pid := -1
var mic_io: FileAccess
var prev_sink := ""
var prev_src := ""
var modules := PackedStringArray()
var lan := PacketPeerUDP.new()
var lan_ip := ""
var lan_t := 0
var try_t := 0.0
var wait_t := 0.0
var hello_t := 0.0
var name_sent := false
var ping_t := 0.0

# Téléphone
var server: TCPServer
var player: AudioStreamPlayer
var pb: AudioStreamGeneratorPlayback
var cap: AudioEffectCapture
var mic_player: AudioStreamPlayer
var beacon := PacketPeerUDP.new()
var beacon_t := 0.0


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	_load_pref()
	_build_ui()
	if is_phone:
		_phone_init()
	else:
		_pc_init()
	_set_status(ST_IDLE, "Prêt", "")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_shutdown()
		get_tree().quit()


## Mascotte choisie dans le Goodview Launcher : ~/.config/goodview/profile.json
func _read_shared_profile() -> void:
	var p := OS.get_environment("HOME") + "/.config/goodview/profile.json"
	if not FileAccess.file_exists(p):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	if d is Dictionary:
		var m := clampi(int(d.get("mascot", 0)), 0, 7)
		if m != mascot:
			mascot = m
			_send_name()


func _send_name() -> void:
	if not is_phone and peer != null and name_sent:
		_send(T_NAME, PackedByteArray([mascot]) + _pc_name().to_utf8_buffer())


func _process(delta: float) -> void:
	if not is_phone:
		mascot_t -= delta
		if mascot_t <= 0.0:
			mascot_t = 2.0
			_read_shared_profile()
	if is_phone:
		_phone_process(delta)
	else:
		_pc_process(delta)
	_ui_tick(delta)


func _shutdown() -> void:
	quit = true
	if not is_phone:
		_pc_teardown()
		if th_adb != null:
			th_adb.wait_to_finish()
			th_adb = null


func _load_pref() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://pref.cfg") == OK:
		link_mode = int(cf.get_value("net", "mode", 0))
		vol = float(cf.get_value("audio", "vol", 1.0))


func _save_pref() -> void:
	var cf := ConfigFile.new()
	cf.set_value("net", "mode", link_mode)
	cf.set_value("audio", "vol", vol)
	cf.save("user://pref.cfg")


# ------------------------------------------------------------------ Interface

func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 16
	th.set_color("font_color", "Label", C_TEXT)
	for n in ["font_color", "font_hover_color", "font_pressed_color"]:
		th.set_color(n, "OptionButton", C_TEXT)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("232a34") if st != "hover" else Color("2c3541")
		sb.set_corner_radius_all(12)
		sb.set_content_margin_all(12)
		if st == "focus":
			sb.bg_color = Color("232a34")
		th.set_stylebox(st, "OptionButton", sb)
	for cls in ["HSlider", "ScrollContainer", "VScrollBar", "OptionButton", "PopupMenu"]:
		th.set_stylebox("focus", cls, StyleBoxEmpty.new()) if cls != "OptionButton" else null
	var pop := StyleBoxFlat.new()
	pop.bg_color = Color("232a34")
	pop.set_corner_radius_all(12)
	th.set_stylebox("panel", "PopupMenu", pop)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("2a313c")
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = C_OK
	fill.set_corner_radius_all(4)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	th.set_stylebox("slider", "HSlider", track)
	th.set_stylebox("grabber_area", "HSlider", fill)
	th.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var sc := StyleBoxFlat.new()
	sc.bg_color = Color(0, 0, 0, 0)
	sc.content_margin_left = 6
	sc.content_margin_right = 6
	var sg := StyleBoxFlat.new()
	sg.bg_color = Color(1, 1, 1, 0.18)
	sg.set_corner_radius_all(3)
	sg.content_margin_left = 6
	sg.content_margin_right = 6
	th.set_stylebox("scroll", "VScrollBar", sc)
	for n in ["grabber", "grabber_highlight", "grabber_pressed"]:
		th.set_stylebox(n, "VScrollBar", sg)
	th.set_icon("grabber", "HSlider", _knob(Color.WHITE))
	th.set_icon("grabber_highlight", "HSlider", _knob(C_OK))
	th.set_icon("grabber_disabled", "HSlider", _knob(C_DIM))
	return th


func _knob(col: Color) -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.88, 1.0])
	g.colors = PackedColorArray([col, col, Color(col, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t


func _label(text: String, size: int, col: Color, parent: Control) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _card(parent: Control) -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_CARD
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(18)
	sb.anti_aliasing_size = 1.2
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	return v


func _build_ui() -> void:
	theme = _make_theme()
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := 22
	if is_phone:
		top += int(DisplayServer.get_display_safe_area().position.y / maxf(1.0, get_window().content_scale_factor))
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", 22)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	scroll.add_child(margin)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(center)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.custom_minimum_size = Vector2(440, 0)
	center.add_child(content)
	get_viewport().size_changed.connect(_fit_width)
	_fit_width()

	var head := HBoxContainer.new()
	content.add_child(head)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var chip_p := PanelContainer.new()
	chip_sb = StyleBoxFlat.new()
	chip_sb.set_corner_radius_all(14)
	chip_sb.content_margin_left = 12
	chip_sb.content_margin_right = 12
	chip_sb.content_margin_top = 4
	chip_sb.content_margin_bottom = 4
	chip_p.add_theme_stylebox_override("panel", chip_sb)
	head.add_child(chip_p)
	chip = _label("", 14, C_DIM, chip_p)

	orb = Orb.new()
	orb.custom_minimum_size = Vector2(0, 230)
	content.add_child(orb)
	status = _label("", 22, C_TEXT, content)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub = _label("", 14, C_DIM, content)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(0, 40)

	var c1 := _card(content)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 14)
	c1.add_child(r1)
	ico_sound = Icon.new("speaker")
	r1.add_child(ico_sound)
	meter_out = Meter.new()
	meter_out.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter_out.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r1.add_child(meter_out)
	tog_sound = Toggle.new()
	tog_sound.set_on(want_sound)
	tog_sound.toggled.connect(_on_sound)
	tog_sound.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r1.add_child(tog_sound)
	var vh := HBoxContainer.new()
	vh.add_theme_constant_override("separation", 10)
	c1.add_child(vh)
	var il := Icon.new("speaker_low")
	il.custom_minimum_size = Vector2(40, 30)
	il.col = C_DIM
	vh.add_child(il)
	vol_slider = HSlider.new()
	vol_slider.min_value = 0
	vol_slider.max_value = 100
	vol_slider.step = 1
	vol_slider.value = vol * 100.0
	vol_slider.custom_minimum_size = Vector2(0, 30)
	vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vol_slider.value_changed.connect(_on_vol)
	vh.add_child(vol_slider)
	var ih := Icon.new("speaker")
	ih.custom_minimum_size = Vector2(40, 30)
	ih.col = C_DIM
	vh.add_child(ih)

	var c2 := _card(content)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 14)
	c2.add_child(r2)
	ico_mic = Icon.new("mic")
	r2.add_child(ico_mic)
	meter_mic = Meter.new()
	meter_mic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter_mic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r2.add_child(meter_mic)
	tog_mic = Toggle.new()
	tog_mic.set_on(want_mic)
	tog_mic.toggled.connect(_on_mic)
	tog_mic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r2.add_child(tog_mic)

	if not is_phone:
		var seg := Seg.new()
		seg.setup(["auto", "usb", "wifi"], [0, 2, 1], link_mode)
		seg.picked.connect(func(id: int):
			link_mode = id
			_save_pref())
		content.add_child(seg)


func _fit_width() -> void:
	if content != null:
		content.custom_minimum_size.x = clampf(get_viewport_rect().size.x - 36.0, 280.0, 520.0)


func _set_status(st: int, a: String, b: String) -> void:
	state = st
	status.text = a
	sub.text = b if st == ST_IDLE else ""


func _ui_tick(delta: float) -> void:
	lvl_out = maxf(0.0, lvl_out - delta * 1.2)
	lvl_mic = maxf(0.0, lvl_mic - delta * 1.2)
	ico_sound.col = C_TEXT if want_sound else C_DIM
	ico_mic.col = C_TEXT if want_mic else C_DIM
	meter_out.value = lvl_out if want_sound else 0.0
	meter_mic.value = lvl_mic if want_mic else 0.0
	var anim_n := "off"
	if state == ST_LINKED:
		anim_n = "happy" if maxf(lvl_out, lvl_mic) > 0.04 else "idle"
	elif state == ST_WAIT:
		anim_n = "wait"
	orb.anim = anim_n
	orb.variant = mascot
	orb.level = maxf(meter_out.shown, meter_mic.shown) if state == ST_LINKED else 0.0
	var col: Color = [C_IDLE, C_WAIT, C_OK][state]
	orb.color = orb.color.lerp(col, minf(1.0, delta * 8.0))
	if state == ST_LINKED and peer != null:
		var tr := "USB" if peer.get_connected_host() == "127.0.0.1" else "Wi-Fi"
		chip.text = tr + (" · %d ms" % rtt_ms if rtt_ms >= 0 else "")
		chip.add_theme_color_override("font_color", C_OK)
		chip_sb.bg_color = Color(C_OK, 0.14)
	else:
		chip.text = "Hors ligne"
		chip.add_theme_color_override("font_color", C_DIM)
		chip_sb.bg_color = Color(1, 1, 1, 0.06)


func _on_sound(on: bool) -> void:
	want_sound = on
	if not is_phone:
		_pc_route()
	_send_ctrl()


func _on_mic(on: bool) -> void:
	want_mic = on
	if is_phone:
		mic_player.stream_paused = not on
	else:
		_pc_route()
	_send_ctrl()


func _on_vol(v: float) -> void:
	vol = v / 100.0
	if is_phone and player != null:
		player.volume_db = linear_to_db(maxf(vol, 0.0001)) if vol > 0.0 else -80.0
	_save_pref()
	_send_ctrl()


func _apply_ctrl_ui() -> void:
	tog_sound.set_on(want_sound)
	tog_mic.set_on(want_mic)
	vol_slider.set_value_no_signal(vol * 100.0)
	if is_phone:
		player.volume_db = linear_to_db(vol) if vol > 0.0 else -80.0
		mic_player.stream_paused = not want_mic


# ------------------------------------------------------------------ Réseau commun

func _send(t: int, data: PackedByteArray) -> void:
	if peer == null or peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	peer.put_data(PackedByteArray([t, data.size() & 255, data.size() >> 8]) + data)


func _send_ctrl() -> void:
	if linked:
		_send(T_CTRL, PackedByteArray([1 if want_sound else 0, 1 if want_mic else 0, int(vol * 100.0)]))


## Lit les trames reçues ; retourne false si la connexion est perdue.
func _read() -> bool:
	peer.poll()
	var st := peer.get_status()
	if st == StreamPeerTCP.STATUS_CONNECTING:
		wait_t += get_process_delta_time()
		return wait_t < 1.5
	if st != StreamPeerTCP.STATUS_CONNECTED:
		return false
	var n := peer.get_available_bytes()
	if n > 0:
		var r := peer.get_data(n)
		if r[0] == OK:
			rxbuf.append_array(r[1])
	while rxbuf.size() >= 3:
		var ln: int = rxbuf[1] | (rxbuf[2] << 8)
		if rxbuf.size() < 3 + ln:
			break
		var t: int = rxbuf[0]
		var pl := rxbuf.slice(3, 3 + ln)
		rxbuf = rxbuf.slice(3 + ln)
		_on_frame(t, pl)
	return true


func _on_frame(t: int, pl: PackedByteArray) -> void:
	match t:
		T_CTRL:
			if pl.size() >= 3:
				want_sound = pl[0] == 1
				want_mic = pl[1] == 1
				vol = pl[2] / 100.0
				_apply_ctrl_ui()
				if not is_phone:
					_pc_route()
		T_PING:
			_send(T_PONG, pl)
		T_PONG:
			if pl.size() >= 4:
				rtt_ms = int(Time.get_ticks_msec() - pl.decode_u32(0)) & 0xFFFF
		T_AUDIO:
			if is_phone:
				_play(pl)
		T_NAME:
			if pl.size() >= 1:
				mascot = clampi(pl[0], 0, 7)
				peer_name = pl.slice(1).get_string_from_utf8()
		T_HELLO:
			if not is_phone and pl.size() >= 4:
				mic_rate = pl.decode_u32(0)
				peer_name = pl.slice(4).get_string_from_utf8()
				_pc_link()
		T_MIC:
			if not is_phone:
				_pc_mic(pl)


# ------------------------------------------------------------------ Téléphone

func _phone_init() -> void:
	DisplayServer.screen_set_keep_on(true)
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.25
	player = AudioStreamPlayer.new()
	player.stream = gen
	add_child(player)
	player.play()
	pb = player.get_stream_playback()
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, "Mic")
	cap = AudioEffectCapture.new()
	cap.buffer_length = 0.5
	AudioServer.add_bus_effect(idx, cap)
	AudioServer.set_bus_mute(idx, true)
	mic_player = AudioStreamPlayer.new()
	mic_player.stream = AudioStreamMicrophone.new()
	mic_player.bus = "Mic"
	add_child(mic_player)
	get_tree().on_request_permissions_result.connect(func(_p, ok: bool): if ok: mic_player.play())
	if "android.permission.RECORD_AUDIO" in OS.get_granted_permissions() or not OS.has_feature("android"):
		mic_player.play()
	else:
		OS.request_permissions()
	mic_player.stream_paused = not want_mic
	server = TCPServer.new()
	server.listen(PORT)
	beacon.set_broadcast_enabled(true)
	beacon.set_dest_address("255.255.255.255", BEACON_PORT)
	_on_vol(vol * 100.0)


func _phone_name() -> String:
	var m := OS.get_model_name()
	return m if m != "" and m != "GenericDevice" else "Téléphone"


func _phone_process(delta: float) -> void:
	if server.is_connection_available():
		var np := server.take_connection()
		if peer != null:
			peer.disconnect_from_host()
		peer = np
		rxbuf.clear()
		linked = false
	if peer != null:
		peer.poll()
		var st := peer.get_status()
		if st == StreamPeerTCP.STATUS_CONNECTED:
			if not linked:
				linked = true
				var h := PackedByteArray()
				h.resize(4)
				h.encode_u32(0, int(AudioServer.get_mix_rate()))
				_send(T_HELLO, h + _phone_name().to_utf8_buffer())
				_send_ctrl()
				_set_status(ST_LINKED, "Connecté", "Le son de ton PC sort sur ce téléphone.")
			_read()
			_phone_pump_mic()
		elif st != StreamPeerTCP.STATUS_CONNECTING:
			peer = null
			linked = false
			rtt_ms = -1
	if not linked:
		_set_status(ST_WAIT, "En attente du PC", "Lance Pocket Speaker sur le PC\n(USB branché ou même Wi-Fi).")
		beacon_t -= delta
		if beacon_t <= 0.0:
			beacon_t = 1.0
			beacon.put_packet("POCKET".to_utf8_buffer())


func _play(pl: PackedByteArray) -> void:
	var n := pl.size() / 4
	var pk := 0
	for i in range(0, pl.size() - 1, 32):
		pk = maxi(pk, absi(pl.decode_s16(i)))
	lvl_out = maxf(lvl_out, pk / 32768.0)
	if not want_sound:
		return
	var buffered := int(RATE * 0.25) - pb.get_frames_available()
	if buffered > int(RATE * 0.15) or pb.get_frames_available() < n:
		return  # trop de retard : on jette ce bloc pour rester en direct
	var arr := PackedVector2Array()
	arr.resize(n)
	for i in n:
		arr[i] = Vector2(pl.decode_s16(i * 4), pl.decode_s16(i * 4 + 2)) / 32768.0
	pb.push_buffer(arr)


func _phone_pump_mic() -> void:
	var n := cap.get_frames_available()
	if n <= 0:
		return
	var fr := cap.get_buffer(n)
	if not want_mic:
		return
	var out := PackedByteArray()
	out.resize(fr.size() * 2)
	var pk := 0.0
	for i in fr.size():
		var s := (fr[i].x + fr[i].y) * 0.5
		pk = maxf(pk, absf(s))
		out.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	lvl_mic = maxf(lvl_mic, pk)
	var o := 0
	while o < out.size():
		var e := mini(out.size(), o + 32000)
		_send(T_MIC, out.slice(o, e))
		o = e


# ------------------------------------------------------------------ PC

func _pc_name() -> String:
	var h := OS.get_environment("HOSTNAME")
	if h == "":
		h = FileAccess.get_file_as_string("/etc/hostname").strip_edges()
	return h if h != "" else "PC"


func _pa(args: PackedStringArray) -> String:
	var out: Array = []
	OS.execute("pactl", args, out, true)
	return "".join(out).strip_edges()


func _pc_init() -> void:
	var env := OS.get_environment("POCKET_ADB")
	var local := OS.get_executable_path().get_base_dir() + "/adb"
	adb_bin = env if env != "" else (local if FileAccess.file_exists(local) else "adb")
	# restes d'un lancement interrompu
	for line in _pa(["list", "short", "modules"]).split("\n"):
		if line.contains(SINK) or line.contains(MIC_SINK):
			var id := line.split("\t")[0]
			if id.is_valid_int():
				_pa(["unload-module", id])
	lan.bind(BEACON_PORT)
	th_adb = Thread.new()
	th_adb.start(_adb_loop)


func _adb(args: PackedStringArray) -> String:
	var out: Array = []
	if OS.execute(adb_bin, args, out, true) == -1:
		return "<noadb>"
	return "".join(out)


func _apk_path() -> String:
	for p in [OS.get_executable_path().get_base_dir() + "/pocket-speaker.apk",
			ProjectSettings.globalize_path("res://build/pocket-speaker.apk")]:
		if FileAccess.file_exists(p):
			return p
	return ""


## Thread : détecte le téléphone, installe/lance l'app, ouvre le tunnel USB.
func _adb_loop() -> void:
	var seen := ""
	while not quit:
		var out := _adb(["devices"])
		var serial := ""
		var unauth := false
		for line in out.split("\n"):
			var p := line.strip_edges().split("\t")
			if p.size() == 2:
				if p[1] == "device":
					serial = p[0]
				elif p[1] == "unauthorized":
					unauth = true
		mtx.lock()
		if serial == "":
			adb_state = "none"
			if out == "<noadb>":
				adb_msg = "adb introuvable (installe « android-tools-adb »)."
			elif unauth:
				adb_msg = "Autorise ce PC sur le téléphone (« Autoriser le débogage USB »)."
			else:
				adb_msg = "Branche le câble USB et active le débogage USB."
			seen = ""
		mtx.unlock()
		if serial != "":
			if serial != seen:
				seen = serial
				_adb_prepare()
			_adb(["forward", "tcp:%d" % PORT, "tcp:%d" % PORT])
			mtx.lock()
			adb_state = "ready"
			mtx.unlock()
		for i in 20:
			if quit:
				return
			OS.delay_msec(100)


func _adb_prepare() -> void:
	var have := -1
	var mt := RegEx.create_from_string("versionCode=(\\d+)").search(_adb(["shell", "dumpsys", "package", PKG]))
	if mt:
		have = mt.get_string(1).to_int()
	var apk := _apk_path()
	if have < VERSION and apk != "":
		mtx.lock()
		adb_msg = "Installation de l'app sur le téléphone…"
		mtx.unlock()
		_adb(["install", "-r", apk])
	_adb(["shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1"])


func _pc_process(delta: float) -> void:
	if peer != null:
		if not _read():
			_pc_unlink()
			return
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			if not name_sent:
				name_sent = true
				_send(T_NAME, PackedByteArray([mascot]) + _pc_name().to_utf8_buffer())
			if linked:
				linked_t += delta
				_pc_pump_capture()
				ping_t -= delta
				if ping_t <= 0.0:
					ping_t = 2.0
					var b := PackedByteArray()
					b.resize(4)
					b.encode_u32(0, Time.get_ticks_msec())
					_send(T_PING, b)
				if test_mode and linked_t > 3.0:
					print("POCKET_TEST link ok rtt=%d phone=%s mascot=%d" % [rtt_ms, peer_name, mascot])
					_shutdown()
					get_tree().quit()
			else:
				hello_t += delta
				_set_status(ST_WAIT, "Téléphone trouvé", "Ouverture de la liaison…")
				if hello_t > 6.0:
					_pc_unlink()
		return
	mtx.lock()
	var st := adb_state
	var msg := adb_msg
	mtx.unlock()
	while lan.get_available_packet_count() > 0:
		if lan.get_packet().get_string_from_utf8() == "POCKET":
			lan_ip = lan.get_packet_ip()
			lan_t = Time.get_ticks_msec()
	if lan_ip != "" and Time.get_ticks_msec() - lan_t > 4000:
		lan_ip = ""
	var host := ""
	if link_mode != 1 and st == "ready":
		host = "127.0.0.1"
		_set_status(ST_WAIT, "Téléphone détecté", "Démarrage de l'app sur le téléphone…")
	elif link_mode != 2 and lan_ip != "":
		host = lan_ip
		_set_status(ST_WAIT, "Téléphone trouvé sur le Wi-Fi", "Connexion à " + lan_ip + "…")
	elif link_mode == 1:
		_set_status(ST_IDLE, "Cherche le téléphone…", "Ouvre Pocket Speaker sur le téléphone (même Wi-Fi).")
		return
	else:
		_set_status(ST_IDLE, "Branche ton téléphone", msg + "\nOu ouvre l'app sur le téléphone (même Wi-Fi).")
		return
	try_t -= delta
	if try_t <= 0.0:
		try_t = 0.8
		peer = StreamPeerTCP.new()
		rxbuf.clear()
		wait_t = 0.0
		hello_t = 0.0
		name_sent = false
		peer.connect_to_host(host, PORT)


func _pc_unlink() -> void:
	if linked:
		_pc_teardown()
	linked = false
	if peer != null:
		peer.disconnect_from_host()
	peer = null
	name_sent = false
	rtt_ms = -1
	_set_status(ST_IDLE, "Connexion perdue", "Nouvelle tentative…")


func _pc_link() -> void:
	if linked:
		return
	linked = true
	linked_t = 0.0
	ping_t = 0.0
	prev_src = _pa(["get-default-source"])
	prev_sink = _pa(["get-default-sink"])
	var m1 := _pa(["load-module", "module-null-sink", "sink_name=" + SINK,
			"sink_properties=device.description=Telephone-Pocket"])
	var m2 := _pa(["load-module", "module-null-sink", "sink_name=" + MIC_SINK,
			"sink_properties=device.description=Micro-Telephone"])
	modules = PackedStringArray([m2, m1])
	_pc_route()
	var io := OS.execute_with_pipe("parec", ["-d", SINK + ".monitor", "--format=s16le",
			"--rate=%d" % RATE, "--channels=2", "--latency-msec=20"], false)
	if io.has("pid"):
		cap_pid = io["pid"]
		cap_io = io["stdio"]
		th_cap = Thread.new()
		th_cap.start(_cap_loop)
	var mi := OS.execute_with_pipe("pacat", ["--playback", "--device=" + MIC_SINK,
			"--format=s16le", "--rate=%d" % mic_rate, "--channels=1", "--latency-msec=30"], false)
	if mi.has("pid"):
		mic_pid = mi["pid"]
		mic_io = mi["stdio"]
	_send_ctrl()
	_set_status(ST_LINKED, "Connecté", "Sortie « Telephone-Pocket » et micro « Micro-Telephone » prêts.")


## Envoie le son du PC vers l'enceinte virtuelle (ou le rend au PC si désactivé).
func _pc_route() -> void:
	if not linked or OS.get_environment("POCKET_NOROUTE") == "1":
		return
	var target := SINK if want_sound else prev_sink
	var want_src := MIC_SRC if want_mic else prev_src
	if want_src != "":
		_pa(["set-default-source", want_src])
	if target == "":
		return
	_pa(["set-default-sink", target])
	for line in _pa(["list", "short", "sink-inputs"]).split("\n"):
		var id := line.split("\t")[0]
		if id.is_valid_int():
			_pa(["move-sink-input", id, target])


func _cap_loop() -> void:
	while not quit and cap_pid > 0:
		var b := PackedByteArray()
		while b.size() < CHUNK * 4:
			var part := cap_io.get_buffer(CHUNK * 4 - b.size())
			if part.size() == 0:
				if cap_pid <= 0 or not OS.is_process_running(cap_pid):
					return
				OS.delay_msec(4)
				continue
			b.append_array(part)
		mtx.lock()
		cap_queue.append(b)
		if cap_queue.size() > 8:
			cap_queue.pop_front()
		mtx.unlock()


func _pc_pump_capture() -> void:
	mtx.lock()
	var q := cap_queue
	cap_queue = []
	mtx.unlock()
	for b: PackedByteArray in q:
		var p := 0
		for i in range(0, b.size() - 1, 32):
			p = maxi(p, absi(b.decode_s16(i)))
		lvl_out = maxf(lvl_out, p / 32768.0)
		if want_sound:
			_send(T_AUDIO, b)


func _pc_mic(pl: PackedByteArray) -> void:
	var p := 0
	for i in range(0, pl.size() - 1, 16):
		p = maxi(p, absi(pl.decode_s16(i)))
	lvl_mic = maxf(lvl_mic, p / 32768.0)
	if want_mic and mic_io != null:
		mic_io.store_buffer(pl)


func _pc_teardown() -> void:
	if prev_src != "":
		_pa(["set-default-source", prev_src])
	if prev_sink != "":
		if OS.get_environment("POCKET_NOROUTE") != "1":
			_pa(["set-default-sink", prev_sink])
			for line in _pa(["list", "short", "sink-inputs"]).split("\n"):
				var id := line.split("\t")[0]
				if id.is_valid_int():
					_pa(["move-sink-input", id, prev_sink])
	if cap_pid > 0:
		OS.kill(cap_pid)
		cap_pid = -1
	if th_cap != null:
		th_cap.wait_to_finish()
		th_cap = null
	cap_io = null
	if mic_pid > 0:
		OS.kill(mic_pid)
		mic_pid = -1
	mic_io = null
	for m in modules:
		if m.is_valid_int():
			_pa(["unload-module", m])
	modules = PackedStringArray()
	cap_queue.clear()
