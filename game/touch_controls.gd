extends RefCounted

# Touch fingers keep ownership until release, so dragging off a button cannot stick it.
var enabled: bool = false
var fingers: Dictionary = {}
var steer: float = 0.0
var cancel_boost: bool = false

func layout(height: float, left_handed: bool = false) -> Dictionary:
	var rects = {
		"steer": Rect2(60,height-180,160,160),
		"attack": Rect2(824,height-140,112,112),
		"brake": Rect2(708,height-116,88,88),
		"boost": Rect2(836,height-246,88,88),
		"guard": Rect2(716,height-226,88,88),
		"grab": Rect2(596,height-112,80,80),
		"pause": Rect2(866,4,56,56)
	}
	if left_handed:
		for action in rects:
			if action != "pause":
				var rect: Rect2 = rects[action]
				rect.position.x = 960-rect.end.x
				rects[action] = rect
	return rects

func held(action: String) -> bool:
	for finger in fingers.values():
		if finger.action == action: return true
	return false

static func contains(rect: Rect2, point: Vector2) -> bool:
	return point.distance_squared_to(rect.get_center())<=pow(rect.size.x*.5,2)

func press(index: int, point: Vector2, rects: Dictionary, can_grab: bool) -> String:
	if fingers.has(index): return ""
	for action in rects:
		if action == "grab" and not can_grab: continue
		if contains(rects[action],point):
			if action == "steer" and held("steer"): return ""
			fingers[index] = {"action":action,"origin":point}
			return action
	return ""

func drag(index: int, point: Vector2) -> void:
	if fingers.has(index) and fingers[index].action == "steer":
		var delta: float = point.x-fingers[index].origin.x
		steer = signf(delta)*clampf((absf(delta)-5)/85,0,1)

func release(index: int, canceled: bool = false) -> void:
	if not fingers.has(index): return
	if fingers[index].action == "steer": steer = 0
	if canceled and fingers[index].action == "boost": cancel_boost = true
	fingers.erase(index)

func clear() -> void:
	fingers.clear()
	steer = 0
	cancel_boost = true

func driving(cruise: bool) -> Dictionary:
	var brake = maxf(Input.get_action_strength("brake"),1.0 if enabled and held("brake") else 0.0)
	var throttle = maxf(Input.get_action_strength("throttle"),1.0 if cruise or enabled else 0.0)
	var keyboard_steer = Input.get_axis("left","right")
	return {
		"throttle": 0.0 if brake>.1 else throttle,
		"brake": brake,
		"steer": clampf(keyboard_steer+(steer if enabled else 0.0),-1,1),
		"boost": Input.is_action_pressed("boost") or (enabled and held("boost")),
		"guard": Input.is_action_pressed("guard") or (enabled and held("guard"))
	}
