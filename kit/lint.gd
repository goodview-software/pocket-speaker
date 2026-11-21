extends RefCounted
## Qualité automatique « sans yeux » : parcourt un arbre de nœuds rendu et signale
## débordement horizontal, contrôles chevauchants, cibles tactiles < 44 px, textes tronqués / colonnes trop étroites,
## contraste < 4,5:1, marges hors échelle, tailles de texte hors tokens, polices non-Inter.
## Lint.scan(root, "contexte") -> Array[String] ; await Lint.sweep(host, root, widths, tree, "contexte") pour plusieurs largeurs.
const T := preload("res://kit/tokens.gd")
const Fonts := preload("res://kit/fonts.gd")
const KS := preload("res://kit/ui/ks.gd")
const MIN_CONTRAST := 4.5

static func _visible(n: Control, root: Control) -> bool:
	var c: Node = n
	while c != null and c != root.get_parent():
		if c is CanvasItem and (not (c as CanvasItem).visible or (c as CanvasItem).modulate.a < 0.05):
			return false
		if c.has_meta("k_nolint"):
			return false
		c = c.get_parent()
	return true

static func _is_interactive(n: Node) -> bool:
	if n.has_meta("k_inner") or n.has_meta("k_dense"):
		return false
	if n is Control and (n as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return false
	if n is BaseButton or n is LineEdit or n is TextEdit or n is Slider:
		return true
	return n is Control and n.has_signal("pressed") and n.has_method("k_overflow") or (n is Control and n.has_method("k_overflow") and n.has_signal("changed"))

static func _hscroll_ancestor(n: Node, root: Node) -> bool:
	var p := n.get_parent()
	while p != null and p != root.get_parent():
		if p is ScrollContainer and (p as ScrollContainer).horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			return true
		p = p.get_parent()
	return false

static func _bg_of(n: Control, root: Control) -> Color:
	var layers: Array = []
	var p: Node = n
	while p != null:
		if p is Control:
			if p.has_method("k_bg"):
				layers.append(p.k_bg())
			elif p is PanelContainer or p is Panel:
				var sb := (p as Control).get_theme_stylebox("panel")
				if sb is StyleBoxFlat:
					layers.append((sb as StyleBoxFlat).bg_color)
			elif p is ColorRect:
				layers.append((p as ColorRect).color)
		if layers.size() > 0 and layers.back().a >= 0.99:
			break
		p = p.get_parent()
	var base := T.surface0
	for i in range(layers.size() - 1, -1, -1):
		base = T.over(layers[i], base)
	return base

static func _overlay_of(n: Node) -> Node:
	var p := n
	while p != null:
		if p.has_meta("k_overlay"):
			return p
		p = p.get_parent()
	return null

static func _tag(n: Node, root: Node) -> String:
	var p := str(root.get_path_to(n)).split("/")
	var short := "/".join(p.slice(maxi(0, p.size() - 3)))
	return "%s(%s)" % [n.get_class() if n.get_script() == null else n.get_script().resource_path.get_file().get_basename(), short]

static func scan(root: Control, ctx := "") -> Array:
	var out: Array = []
	var allowed := T.allowed_px()
	var sizes: Array = []
	for k in T.TEXT_SIZES:
		sizes.append(T.TEXT_SIZES[k][0])
	var rr := root.get_global_rect()
	var inter: Array = []
	var bad_overflow := {}
	var seen_txt := {}
	var stack: Array = [root]
	var qi := 0
	while qi < stack.size():
		var n: Node = stack[qi]
		qi += 1
		for c in n.get_children():
			stack.append(c)
		if not (n is Control) or n == root:
			continue
		var c := n as Control
		if not _visible(c, root) or c.has_meta("k_inner"):
			continue
		var r := c.get_global_rect()
		var tag := _tag(c, root)
		# 1. débordement horizontal
		if r.size.x > 0 and (r.end.x > rr.end.x + 1.5 or r.position.x < rr.position.x - 1.5) and not _hscroll_ancestor(c, root):
			var par := c.get_parent()
			if not (par is Control and bad_overflow.has(par)):
				bad_overflow[c] = true
				var why := ""
				if c is Container:
					var worst: Control = null
					for ch in c.get_children():
						if ch is Control and ch.visible and (worst == null or ch.get_combined_minimum_size().x > worst.get_combined_minimum_size().x):
							worst = ch
					var depth := 0
					while worst != null and worst is Container and depth < 8:
						var nxt: Control = null
						for ch2 in worst.get_children():
							if ch2 is Control and ch2.visible and (nxt == null or ch2.get_combined_minimum_size().x > nxt.get_combined_minimum_size().x):
								nxt = ch2
						if nxt == null or nxt.get_combined_minimum_size().x < worst.get_combined_minimum_size().x - 40:
							break
						worst = nxt
						depth += 1
					var hint := ""
					if worst != null:
						var q: Array = [worst]
						while not q.is_empty() and hint == "":
							var n2: Node = q.pop_front()
							if n2 is Label and (n2 as Label).text != "":
								hint = " « %s »" % (n2 as Label).text.left(24)
							elif n2.get("text") is String and str(n2.get("text")) != "":
								hint = " « %s »" % str(n2.get("text")).left(24)
							for c3 in n2.get_children():
								q.append(c3)
					if worst != null:
						why = hint + " [plus large enfant : %s min %.0f]" % [_tag(worst, root), worst.get_combined_minimum_size().x]
				out.append("débordement horizontal %s : x=%.0f..%.0f pour une zone de %.0f%s" % [tag, r.position.x - rr.position.x, r.end.x - rr.position.x, rr.size.x, why])
		# 2/3. interactifs
		if _is_interactive(c):
			inter.append(c)
			if (minf(r.size.x, r.size.y) < T.TOUCH - 0.5) and not (c is HSlider):
				out.append("zone tactile %.0fx%.0f < 44 px %s" % [r.size.x, r.size.y, tag])
		# 4. textes
		if c is Label:
			var l := c as Label
			if l.text.length() >= 3 and l.text.length() <= 40 and l.size.x > 0 and not l.has_meta("k_dup_ok"):
				var key := l.text.strip_edges()
				var has_digit := false
				for ch in key:
					if ch >= "0" and ch <= "9":
						has_digit = true
				if has_digit:
					if seen_txt.has(key):
						out.append("donnée affichée deux fois « %s » %s" % [key, _tag(l, root)])
					seen_txt[key] = true
			if l.text != "" and l.size.x > 0:
				var f := l.get_theme_font("font")
				var fs := l.get_theme_font_size("font_size")
				if not Fonts.is_inter(f):
					out.append("police non-Inter %s" % tag)
				if not fs in sizes:
					out.append("taille de texte %d hors tokens %s" % [fs, tag])
				if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
					var tw := f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
					if "\n" not in l.text and l.size.x + 1.5 < tw and not l.has_meta("k_ellipsis"):
						out.append("texte tronqué « %s » (%.0f < %.0f px) %s" % [l.text.left(24), l.size.x, tw, tag])
				else:
					if l.size.x < fs * 1.2 and l.text.length() > 2:
						out.append("colonne de texte trop étroite (%.0f px) « %s » %s" % [l.size.x, l.text.left(24), tag])
				# contraste
				var fg: Color = l.get_theme_color("font_color")
				var bg := _bg_of(l, root)
				if fg.a < 1.0:
					fg = T.over(fg, bg)
				var ratio := T.contrast(fg, bg)
				if ratio < MIN_CONTRAST:
					out.append("contraste %.1f:1 < 4,5 « %s » %s" % [ratio, l.text.left(24), tag])
		elif c is RichTextLabel or c is LineEdit or c is TextEdit or c is Button:
			var fnt := c.get_theme_font("normal_font" if c is RichTextLabel else "font")
			if not Fonts.is_inter(fnt):
				out.append("police non-Inter %s" % tag)
			if c is Button and (c as Button).text != "":
				out.append("Button natif à remplacer par KButton %s" % tag)
		if c.has_method("k_overflow") and c.k_overflow():
			out.append("texte coupé dans le composant %s (largeur %.0f)" % [tag, r.size.x])
		if c.has_method("k_colors") and not c.get("disabled"):
			for pair in c.k_colors():
				var ratio2 := T.contrast(T.over(pair[0], pair[1]), pair[1])
				if ratio2 < MIN_CONTRAST:
					out.append("contraste %.1f:1 < 4,5 dans %s" % [ratio2, tag])
		# 6. marges hors échelle
		if c is MarginContainer or c is BoxContainer or c is FlowContainer or c is GridContainer:
			for cn in ["margin_left", "margin_top", "margin_right", "margin_bottom", "separation", "h_separation", "v_separation"]:
				if c.has_theme_constant_override(cn):
					var v := c.get_theme_constant(cn)
					if not v in allowed:
						out.append("marge/gouttière %s=%d hors échelle %s" % [cn, v, tag])
		if c is PanelContainer and c.has_theme_stylebox_override("panel"):
			var sb := c.get_theme_stylebox("panel")
			if sb is StyleBoxFlat:
				for m in [sb.content_margin_left, sb.content_margin_top, sb.content_margin_right, sb.content_margin_bottom]:
					if m >= 0 and not int(m) in allowed:
						out.append("marge interne %.0f hors échelle %s" % [m, tag])
						break
	# 2. chevauchements
	for i in inter.size():
		for j in range(i + 1, inter.size()):
			var a: Control = inter[i]
			var b: Control = inter[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			if _overlay_of(a) != _overlay_of(b):
				continue  # un toast / menu flotte volontairement au-dessus du contenu
			var ia := a.get_global_rect().intersection(b.get_global_rect())
			if ia.size.x > 2.0 and ia.size.y > 2.0:
				out.append("chevauchement %s %s / %s %s (%.0fx%.0f)" % [_tag(a, root), str(a.get_global_rect()), _tag(b, root), str(b.get_global_rect()), ia.size.x, ia.size.y])
	var res: Array = []
	for m in out:
		res.append(("[%s] " % ctx if ctx != "" else "") + str(m))
	return res

## Rend host aux largeurs données et scanne root à chaque fois (host : Control ancré librement).
static func sweep(host: Control, root: Control, widths: Array, tree: SceneTree, ctx := "", height := 800) -> Array:
	var out: Array = []
	host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for w in widths:
		host.custom_minimum_size = Vector2.ZERO
		host.size = Vector2(w, height)
		for i in 4:
			await tree.process_frame
		out.append_array(scan(root, "%s @%d" % [ctx, w]))
	return out
