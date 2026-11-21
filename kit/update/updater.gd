extends Node
## Mise à jour automatique COMMUNE aux apps Goodview (même protocole que Sound Link et le launcher) :
##   <repo>/releases/latest/download/version.json  ->  {"version", "godot", "sha256", "pck"}
## Le .pck téléchargé est chargé au prochain démarrage par update/boot.gd. Pas d'API GitHub : aucune limite de requêtes.
## États : idle · checking · uptodate · available · downloading · ready · newbin · offline · error

signal changed

const TMP := "user://update.tmp"
const PCK := "user://update.pck"
const CFG := "user://update.cfg"

var repo := ""
var version := "0"
var state := "idle"
var info := {}
var ratio := 0.0
var error_msg := ""
var last_check := 0.0
var dismissed := ""  # version déjà refusée pendant cette session
var base_url := ""  # surcharge (tests) : GV_UPDATE_BASE


func setup(p_repo: String, p_version: String, interval := 1800.0, first_check_delay := 2.5) -> void:
	repo = p_repo
	version = p_version
	base_url = OS.get_environment("GV_UPDATE_BASE")
	var t := Timer.new()
	t.wait_time = interval
	t.timeout.connect(check)
	add_child(t)
	t.start()
	if first_check_delay >= 0.0:
		get_tree().create_timer(first_check_delay).timeout.connect(check)


static func newer(a: String, b: String) -> bool:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := pa[i].to_int() if i < pa.size() else 0
		var y := pb[i].to_int() if i < pb.size() else 0
		if x != y:
			return x > y
	return false


func _go(s: String) -> void:
	state = s
	changed.emit()


func _url(file: String) -> String:
	if base_url != "":
		return base_url + "/" + file
	return "https://github.com/%s/releases/latest/download/%s" % [repo, file]


func releases_url() -> String:
	return "https://github.com/%s/releases/latest" % repo


func check() -> void:
	if state in ["checking", "downloading", "ready"] or repo == "":
		return
	_go("checking")
	var req := HTTPRequest.new()
	req.timeout = 10.0
	add_child(req)
	if req.request(_url("version.json"), PackedStringArray(["User-Agent: goodview-app"])) != OK:
		req.queue_free()
		_go("offline")
		return
	var res: Array = await req.request_completed
	req.queue_free()
	last_check = Time.get_unix_time_from_system()
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		_go("offline")
		return
	if res[1] == 404:
		_go("uptodate")
		return
	if res[1] != 200:
		error_msg = "Serveur : erreur %d." % res[1]
		_go("error")
		return
	var d = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if not (d is Dictionary) or not d.has("version") or not newer(str(d["version"]), version):
		_go("uptodate")
		return
	info = d
	var v := Engine.get_version_info()
	var same: bool = str(d.get("godot", "")) == "%d.%d.%d" % [v.major, v.minor, v.patch]
	_go("available" if (same and d.has("pck")) else "newbin")


## Télécharge le .pck (vérifie le sha256) puis passe en « ready » : il sera chargé au prochain démarrage.
func apply() -> void:
	if state != "available" and state != "error":
		return
	if info.is_empty():
		return
	ratio = 0.0
	_go("downloading")
	var req := HTTPRequest.new()
	req.download_file = TMP
	req.max_redirects = 8
	req.timeout = 120.0
	add_child(req)
	var out := [-1, 0]  # modifié EN PLACE par la fonction anonyme (une réaffectation ne serait pas visible ici)
	req.request_completed.connect(func(r: int, c: int, _h: PackedStringArray, _b: PackedByteArray):
		out[0] = r
		out[1] = c)
	var url := str(info["pck"])
	if base_url != "":
		url = base_url + "/" + url.get_file()
	if req.request(url, PackedStringArray(["User-Agent: goodview-app"])) != OK:
		req.queue_free()
		error_msg = "Téléchargement impossible."
		_go("error")
		return
	while out[0] == -1:
		var total := req.get_body_size()
		if total > 0:
			ratio = float(req.get_downloaded_bytes()) / total
			changed.emit()
		await get_tree().process_frame
	req.queue_free()
	if out[0] != HTTPRequest.RESULT_SUCCESS or out[1] != 200 \
			or FileAccess.get_sha256(TMP) != str(info.get("sha256", "")):
		DirAccess.remove_absolute(TMP)
		error_msg = "Échec du téléchargement."
		_go("error")
		return
	DirAccess.rename_absolute(TMP, PCK)
	var c := ConfigFile.new()
	c.set_value("update", "version", str(info["version"]))
	c.save(CFG)
	ratio = 1.0
	_go("ready")


func can_restart() -> bool:
	return OS.has_feature("pc")


func restart() -> void:
	if can_restart():
		OS.set_restart_on_exit(true)
	get_tree().quit()
