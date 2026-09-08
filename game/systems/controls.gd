extends RefCounted

const KEYS = {"throttle":KEY_W,"brake":KEY_S,"left":KEY_A,"right":KEY_D,"punch":KEY_J,"kick":KEY_K,"club":KEY_L,"guard":KEY_U,"dodge":KEY_I,"grab":KEY_O,"boost":KEY_SHIFT,"cruise":KEY_C,"primary_attack":KEY_SPACE,"pause":KEY_ESCAPE,"restart":KEY_R}
const LABELS = {"throttle":"油门","brake":"刹车","left":"左转","right":"右转","punch":"拳击","kick":"踢击","club":"武器攻击","guard":"格挡","dodge":"闪避","grab":"夺械","boost":"蓄力冲刺","cruise":"定速油门"}

const FIXED_KEYS = [KEY_SPACE,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]

static func binding_key(action: String, bindings: Dictionary) -> int:
	var key = int(bindings.get(action, KEYS[action]))
	return KEYS[action] if key in FIXED_KEYS else key

static func setup(bindings: Dictionary) -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.15)
		InputMap.action_erase_events(action)
		var key = InputEventKey.new()
		key.physical_keycode = binding_key(action, bindings)
		InputMap.action_add_event(action, key)
	for item in [["throttle",KEY_UP],["brake",KEY_DOWN],["left",KEY_LEFT],["right",KEY_RIGHT]]:
		var key = InputEventKey.new()
		key.physical_keycode = item[1]
		InputMap.action_add_event(item[0], key)
	for item in [["guard",JOY_BUTTON_B],["dodge",JOY_BUTTON_LEFT_STICK],["grab",JOY_BUTTON_RIGHT_STICK],["punch",JOY_BUTTON_X],["kick",JOY_BUTTON_A],["club",JOY_BUTTON_Y],["boost",JOY_BUTTON_RIGHT_SHOULDER],["pause",JOY_BUTTON_START],["cruise",JOY_BUTTON_LEFT_SHOULDER]]:
		var button = InputEventJoypadButton.new()
		button.button_index = item[1]
		InputMap.action_add_event(item[0], button)
	for item in [["throttle",JOY_AXIS_TRIGGER_RIGHT,1.0],["brake",JOY_AXIS_TRIGGER_LEFT,1.0],["left",JOY_AXIS_LEFT_X,-1.0],["right",JOY_AXIS_LEFT_X,1.0]]:
		var axis = InputEventJoypadMotion.new()
		axis.axis = item[1]
		axis.axis_value = item[2]
		InputMap.action_add_event(item[0], axis)

static func key_label(action: String, bindings: Dictionary) -> String:
	return OS.get_keycode_string(binding_key(action, bindings))
