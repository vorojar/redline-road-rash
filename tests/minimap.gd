extends SceneTree
const Race = preload("res://game/race.gd")
var checks = 0
var failures = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if value: print("[PASS] " + label)
	else:
		failures += 1
		printerr("FAIL: " + label)
func _initialize(): call_deferred("run")
func run():
	var race = Race.new()
	race.test_mode = true
	root.add_child(race)
	race.set_process(false)
	race.set_physics_process(false)
	race.player.distance = 100
	var positions = [160.0,85.0,69.0,359.0,100.0]
	for i in range(race.racers.size()):
		race.racers[i].s = positions[i]
		race.racers[i].lane = 0
	var markers = race.hud.mini_map_riders(Vector2.ZERO)
	check(markers.size()==3,"小地图仅显示范围内三个 AI，排除远处骑手和普通车辆")
	check(is_equal_approx(markers[0].y,20) and is_equal_approx(markers[1].y,45),"小地图前方 AI 在上方、后方 AI 在下方，纵向距离按比例映射")
	check(markers[2]==race.hud.mini_map_position(Vector2.ZERO,100),"同赛程 AI 与玩家使用同一条路线投影")
	race.racers[0].s = 70
	race.racers[1].s = 358
	check(race.hud.mini_map_riders(Vector2.ZERO).size()==3,"小地图前后边界上的 AI 仍显示")
	race.sound.stop_all()
	race.queue_free()
	await process_frame
	print("MINIMAP_RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
