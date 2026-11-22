extends Node
## Bulle flottante Android (plugin « PocketOverlay », voir android/build/src/main/java/fr/goodview/overlay).
## Sans effet hors Android / sans le plugin (PC, export non-gradle).
## Utilisation : var ov := KOverlay.new(); add_child(ov) ; ov.state_fn = func(): return {...} ; ov.action.connect(...)
## state_fn renvoie { ok: bool, text: String, buttons: bool, sound: bool, mic: bool }.

signal action(name: String)  ## « sound » ou « mic » demandé depuis la bulle

var state_fn: Callable
var _pl: Object = null
var _last := {}
var _t := 0.0


func _ready() -> void:
	if OS.has_feature("android") and Engine.has_singleton("PocketOverlay"):
		_pl = Engine.get_singleton("PocketOverlay")
		_pl.set_enabled(true)
		if OS.get_name() == "Android" and not "android.permission.POST_NOTIFICATIONS" in OS.get_granted_permissions():
			OS.request_permission("android.permission.POST_NOTIFICATIONS")
	set_process(_pl != null)


func available() -> bool:
	return _pl != null


func has_permission() -> bool:
	return _pl != null and _pl.has_permission()


func request_permission() -> void:
	if _pl != null:
		_pl.request_permission()


func _process(delta: float) -> void:
	var a: String = _pl.take_action()
	if a != "":
		action.emit(a)
	_t += delta
	if _t < 0.5 or not state_fn.is_valid():
		return
	_t = 0.0
	var s: Dictionary = state_fn.call()
	if s != _last:
		_last = s
		_pl.set_state(bool(s.get("ok", false)), str(s.get("text", "")), bool(s.get("buttons", false)), bool(s.get("sound", true)), bool(s.get("mic", false)))
