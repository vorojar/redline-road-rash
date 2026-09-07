extends RefCounted

const CATALOG = preload("res://data/catalog.json")
var catalog: Dictionary = CATALOG.data
var path: String = "user://career_v2.json"
var credits: int = 0
var owned: Array = ["ratchet"]
var selected: String = "ratchet"
var unlocked: Array = ["pine"]
var records: Dictionary = {}
var settings: Dictionary = {"volume": 0.7, "music": 0.65, "shake": 0.6, "difficulty": 1, "assist": false, "large_hud": false, "bindings": {}, "control_mode": 0, "touch_left_handed": false, "render_quality": 1}
var load_error: String = ""

func load_profile() -> void:
	if not FileAccess.file_exists(path):
		return
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		load_error = "存档格式无效，本次不会覆盖原存档。"
		return
	var parsed = parser.data
	if not parsed is Dictionary or parsed.get("version") != 2 or not parsed.get("owned") is Array or not parsed.get("records") is Dictionary:
		load_error = "存档格式无效，本次不会覆盖原存档。"
		return
	if not parsed.get("unlocked", ["pine"]) is Array or not parsed.get("settings", {}) is Dictionary:
		load_error = "存档设置字段损坏，本次不会覆盖原存档。"
		return
	if not parsed.get("credits") is float and not parsed.get("credits") is int:
		load_error = "存档金额字段损坏，本次不会覆盖原存档。"
		return
	credits = maxi(0, int(parsed.credits))
	owned = parsed.owned.filter(func(id): return id in ["ratchet", "revenant", "phantom"])
	if "ratchet" not in owned:
		owned.append("ratchet")
	selected = str(parsed.get("selected", "ratchet"))
	if selected not in owned:
		selected = "ratchet"
	unlocked = parsed.get("unlocked", ["pine"])
	records = parsed.records
	if records.has("coast") and records.coast is Dictionary and typeof(records.coast.get("best_place")) in [TYPE_INT,TYPE_FLOAT] and records.coast.best_place>=1 and records.coast.best_place<=3 and "interstate" not in unlocked:
		unlocked.append("interstate")
	var saved_settings = parsed.get("settings", {})
	if saved_settings is Dictionary:
		for key in settings:
			if key in saved_settings:
				if typeof(settings[key]) == TYPE_INT and (saved_settings[key] is float or saved_settings[key] is int):
					settings[key] = int(saved_settings[key])
				elif typeof(saved_settings[key]) == typeof(settings[key]):
					settings[key] = saved_settings[key]
	settings.volume = clampf(settings.volume, 0, 1)
	settings.music = clampf(settings.music, 0, 1)
	settings.shake = clampf(settings.shake, 0, 1)
	settings.control_mode = clampi(int(settings.control_mode), 0, 2)
	settings.render_quality = clampi(int(settings.render_quality), 0, 2)
	settings.difficulty = clampi(int(settings.difficulty), 0, 2)

func save_profile() -> bool:
	if not load_error.is_empty():
		return false
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version":2,"credits":credits,"owned":owned,"selected":selected,"unlocked":unlocked,"records":records,"settings":settings}, "\t"))
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK

func bike(id: String = "") -> Dictionary:
	for entry in catalog.bikes:
		if entry.id == (selected if id.is_empty() else id):
			return entry
	return {}

func buy(id: String) -> bool:
	var entry = bike(id)
	if entry.is_empty() or id in owned or credits < int(entry.price):
		return false
	credits -= int(entry.price)
	owned.append(id)
	selected = id
	return true

func settle(track_id: String, place: int, seconds: float, kos: int, environment_kos: int) -> int:
	var track: Dictionary = {}
	for entry in catalog.tracks:
		if entry.id == track_id:
			track = entry
	if track.is_empty() or place < 1 or place > 6:
		return 0
	var reward = int(track.prize[place - 1]) + kos * 75 + environment_kos * 50
	credits += reward
	var previous: Dictionary = records.get(track_id, {"best_time": 99999.0,"best_place":6,"races":0})
	previous.best_time = minf(previous.best_time, seconds)
	previous.best_place = mini(int(previous.best_place), place)
	previous.races += 1
	records[track_id] = previous
	if track_id == "pine" and place <= 3 and "coast" not in unlocked:
		unlocked.append("coast")
	if track_id == "coast" and place <= 3 and "interstate" not in unlocked:
		unlocked.append("interstate")
	return reward
