extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var race = load("res://game/race.gd").new()
	race.test_mode = true
	root.add_child(race)
	race.set_process(false)
	race.set_physics_process(false)
	race.mode = "racing"
	race.player.speed = race.player.top_speed
	for r in race.racers: r.s = 20000.0
	for car in race.traffic: car.s = 20000.0
	Input.action_press("throttle")
	Input.action_press("boost")
	for i in range(180): race._physics_process(1.0/60)
	var passed: bool = race.player.speed <= race.player.top_speed+.1
	print("HOLD_ONLY: speed=",race.player.speed," top=",race.player.top_speed)
	if not passed: printerr("FAIL: 持续按住 Shift 不应自动冲刺")
	else: print("[PASS] 持续按住 Shift 不会自动冲刺")
	Input.action_release("throttle")
	Input.action_release("boost")
	race.sound.stop_all()
	race.queue_free()
	await process_frame
	await create_timer(.25).timeout
	quit(0 if passed else 1)
