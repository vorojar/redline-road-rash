extends SceneTree
var race: Node3D
var frames = 0
func _initialize() -> void: call_deferred("setup")
func setup() -> void:
	race = load("res://game/race.gd").new()
	race.test_mode = true
	root.add_child(race)
	race.set_physics_process(false)
	race.mode = "garage"
	race.hud.enter_garage()
func _process(_dt: float) -> bool:
	if not is_instance_valid(race): return false
	frames += 1
	if frames in [15,75,135]:
		race.hud.preview_bike(int((frames-15)/60))
	if frames in [45,105,165]: capture.call_deferred(int((frames-45)/60))
	if frames==180:
		race.sound.stop_all()
		race.queue_free()
		race = null
		finish.call_deferred()
	return false
func capture(index: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://outputs/garage-%d.png" % index)
func finish() -> void:
	await create_timer(.25).timeout
	quit()
