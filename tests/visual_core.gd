extends SceneTree
const Race = preload("res://game/race.gd")
var race: Node3D
var ticks = 0
func _initialize() -> void: call_deferred("setup")
func setup() -> void:
	race = Race.new()
	race.test_mode = true
	root.add_child(race)
	race.set_physics_process(false)
	race.set_process(false)
	race.mode = "racing"
	race.player.distance = 320
	race.player.lane = 2
	race.player.speed = 34
	race.player.weapon = 2
	for r in race.racers: r.s = 330.0+r.style*5
	race.player_mesh.position = race.route.point(320,2)
	race.player_mesh.rotation.y = race.route.yaw(320)
func _physics_process(dt: float) -> bool:
	if not is_instance_valid(race): return false
	ticks += 1
	if ticks<180:
		race.player.distance += 34*dt
		race.player_mesh.ground_move(race.route.point(race.player.distance,2),race.route.yaw(race.player.distance),dt)
		race.player.guarding = ticks>=60 and ticks<120
		race.player.attack_time = .44 if ticks==121 else maxf(0,race.player.attack_time-dt)
		race.player.attack_kind = 2
	else:
		if ticks==180: race.player.crash()
		if ticks>180:
			race.player.drive(dt,0,0,0,false)
			if is_instance_valid(race.player_mesh.crash_rig):
				var loc = race.crash_location(race.player_mesh.crash_rig.bike_body.global_position)
				race.player.distance = loc.x
				race.player.lane = loc.y
			race.player_mesh.ground_move(race.route.point(race.player.distance,race.player.lane),race.route.yaw(race.player.distance),dt)
	race.elapsed += dt
	race.update_visuals(dt)
	race.hud.queue_redraw()
	if ticks in [30,90,130,195,250,315,330,390,435,470,500,520,540,570]: capture.call_deferred(ticks)
	if ticks==600:
		race.sound.stop_all()
		race.queue_free()
		race = null
		finish.call_deferred()
	return false
func capture(frame: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://outputs/core-%03d.png" % frame)
func finish() -> void:
	await create_timer(.25).timeout
	quit()
