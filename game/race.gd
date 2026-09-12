extends Node3D

const Endurance = preload("res://game/systems/endurance.gd")
const FinishPresentation = preload("res://game/systems/finish_presentation.gd")
const Burst = preload("res://game/systems/burst.gd")
const BikeState = preload("res://game/bike_state.gd")
const Actor = preload("res://game/vehicles/bike_actor.gd")
const Career = preload("res://game/systems/career.gd")
const Controls = preload("res://game/systems/controls.gd")
const Route = preload("res://game/world/route.gd")
const RoadBuilder = preload("res://game/world/road_builder.gd")
const RacerAI = preload("res://game/systems/racer_ai.gd")
const Contacts = preload("res://game/systems/vehicle_contacts.gd")
const Traffic = preload("res://game/systems/traffic.gd")
const Sound = preload("res://game/systems/sound.gd")
const Combat = preload("res://game/systems/combat.gd")
const TouchControls = preload("res://game/touch_controls.gd")
const HUD = preload("res://game/hud.gd")

var endurance = Endurance.new()
var finish_presentation = FinishPresentation.new()
var touch = TouchControls.new()
const RenderQuality = preload("res://game/systems/render_quality.gd")
var sun: DirectionalLight3D
var touch_device: bool = false
var primary_punch: bool = true
var web_suspend_callback
var career = Career.new()
var player = BikeState.new()
var track: Dictionary
var route: Path3D
var world: Node3D
# At most one entry per catalog track. Detached worlds retain their own route.
var world_cache: Dictionary = {}
var loading_progress: float = 0.0
var loading_title: String = ""

var player_mesh: CharacterBody3D
var camera: Camera3D
var hud: Control
var sound: Node
var racers: Array[Dictionary] = []
var traffic: Array[Dictionary] = []
var police: Dictionary
var mode: String = "ready"
var resume_mode: String = "racing"
var elapsed: float = 0.0
var countdown: float = 3.0
var heat: float = 0.0
var nitro: float = 100.0
var burst = Burst.new()
var shake: float = 0.0
var flash: float = 0.0
var hit_stop: float = 0.0
var message: String = ""
var message_time: float = 0.0
var target_index: int = -1
var result: String = ""
var rank: int = 6
var cruise: bool = false
var tutorial: bool = false
var lesson: int = 0
var reward: int = 0
var settled: bool = false
var pending_attack: float = 0.0
var pending_kind: int = 0
var attack_target: int = -1
var throttle_value: float = 0.0
var debug_hud: bool = false
var rng = RandomNumberGenerator.new()
var test_mode: bool = false
var frame_samples: Array[float] = []
var particles: Array[Dictionary] = []
var telemetry: Array = []
var telemetry_clock: float = 0.0

func _exit_tree() -> void:
	for entry in world_cache.values():
		if is_instance_valid(entry.world) and not entry.world.is_inside_tree():
			entry.world.free()

func _ready() -> void:
	rng.seed = 812
	if not test_mode:
		career.load_profile()
	touch_device = DisplayServer.is_touchscreen_available()
	if OS.has_feature("web"):
		touch_device = bool(JavaScriptBridge.eval("window.redlineTouchDevice === true"))
		web_suspend_callback = JavaScriptBridge.create_callback(func(_args): suspend_input())
		JavaScriptBridge.get_interface("window").redlineSuspend = web_suspend_callback
	touch.enabled = touch_device if career.settings.control_mode == 0 else career.settings.control_mode == 1
	Controls.setup(career.settings.bindings)
	track = career.catalog.tracks[0]
	build_environment()
	apply_render_quality()
	route = Route.new()
	add_child(route)
	world = RoadBuilder.new()
	world.mobile_quality = touch_device
	add_child(world)
	route.curve = load("res://data/tracks/pine.tres")
	world.build(route,track)
	remove_child(route)
	world.add_child(route)
	world_cache[track.id] = {"world":world,"route":route}
	player_mesh = Actor.new()
	add_child(player_mesh)
	camera = Camera3D.new()
	camera.far = 700 if touch_device else 1250
	camera.near = .1
	add_child(camera)
	camera.current = true
	sound = Sound.new()
	add_child(sound)
	var layer = CanvasLayer.new()
	add_child(layer)
	hud = HUD.new()
	hud.race = self
	layer.add_child(hud)
	reset_race()
	update_visuals(1)
	if not career.load_error.is_empty():
		notify(career.load_error,10)

func build_environment() -> void:
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var material = ShaderMaterial.new()
	material.shader = load("res://game/world/overcast.gdshader")
	sky.sky_material = material
	env.environment.sky = sky
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("a5bdcf")
	env.environment.ambient_light_energy = .42
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.fog_enabled = true
	env.environment.fog_light_color = Color("b5c6ce")
	# Keep the approach to traffic/roadblocks clear; only distant scenery dissolves.
	env.environment.fog_mode = Environment.FOG_MODE_DEPTH
	env.environment.fog_depth_begin = 180.0
	env.environment.fog_depth_end = 650.0
	env.environment.fog_depth_curve = 1.6
	env.environment.fog_density = 1.0
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34,-48,0)
	sun.light_color = Color("ffe8c7")
	sun.light_energy = 1.12
	add_child(sun)

func apply_render_quality() -> void:
	RenderQuality.apply(get_viewport(),career.settings.render_quality)
	RenderQuality.apply_sun(sun,career.settings.render_quality,touch_device)
	if is_instance_valid(hud) and is_instance_valid(hud.garage_view):
		hud.garage_view.apply_render_quality()

func difficulty() -> Dictionary:
	return career.catalog.difficulties[clampi(int(career.settings.difficulty),0,2)]

func reset_race() -> void:
	touch.clear()
	endurance.configure(track)
	finish_presentation = FinishPresentation.new()
	player_mesh.celebration = 0
	for r in racers:
		r.mesh.queue_free()
	for car in traffic:
		car.mesh.queue_free()
	if not police.is_empty():
		police.mesh.queue_free()
		police.support_mesh.queue_free()
	racers.clear()
	traffic.clear()
	player = BikeState.new()
	player.configure(career.bike())
	sound.configure_engine(career.selected)
	player.assist = career.settings.assist
	player_mesh.clear_crash()
	player_mesh.contact_started=-100.0
	player_mesh.contact_strength=0.0
	player_mesh.set_model(career.bike())
	player_mesh.style_rider(Color("354f68"))
	player_mesh.position = route.point(0,player.lane)
	elapsed = 0
	countdown = 3
	heat = 0
	burst = Burst.new()
	nitro = 100
	cruise = false
	reward = 0
	result = ""
	message = ""
	message_time = 0
	settled = false
	lesson = 0
	pending_attack = 0
	target_index = -1
	telemetry.clear()
	for i in range(5):
		var actor = Actor.new()
		add_child(actor)
		var bike_id = (["ratchet","ratchet","ratchet","revenant","revenant"] if track.id=="pine" else ["ratchet","revenant","revenant","phantom","phantom"])[i]
		actor.set_model(career.bike(bike_id))
		actor.tint([Color("454641"),Color("777069"),Color("8c7c3f"),Color("223a48"),Color("531e1a")][i])
		actor.style_rider([Color("b94132"),Color("e0b84b"),Color("3c83b7"),Color("60a16c"),Color("bc7850")][i],i+1)
		racers.append({"mesh":actor,"name":["AXEL","NOVA","ROOK","JINX","VIPER"][i],"s":4.0+i*5,"lane":-4.5+i*2,"home_lane":-4.5+i*2,"speed":0.0,"hp":100.0,"stability":100.0,"crash":0.0,"cooldown":3.0+i,"finished":false,"finish_time":0.0,"aggression":.3+i*.14,"skill":.4+i*.13,"revenge":0,"last_hit_age":999.0,"stagger":0.0,"windup":0.0,"attack_time":0.0,"ko_credited":false,"weapon":[0,1,0,2,1][i],"guard":0.0,"dodge":0.0,"defense_cd":0.0,"stamina":100.0,"kind":0,"style":i,"crash_speed":0.0,"bike_id":bike_id,"burst":Burst.new(),"duel_time":0.0,"duel_cooldown":0.0,"combat_target":-2,"attack_side":1.0,"grudge_target":-2,"grudge_time":0.0,"retreat_time":0.0,"retreat_cooldown":0.0,"stealing":false})
	for i in range(18):
		var truck = i%6 == 5
		var car = Traffic.vehicle([Color("afb0a5"),Color("65564a"),Color("375058"),Color("8f866a")][i%4],truck)
		add_child(car)
		var traffic_speed = (-18.0 if truck else -20.0) if i%4<2 else (18.0 if truck else 22.0+(i%3)*1.5)
		traffic.append({"mesh":car,"s":160.0+i*85,"lane":[-4.7,-1.6,1.6,4.7][i%4],"speed":traffic_speed,"half_length":3.8 if truck else 2.1,"driver":Traffic.Driver.state(i,[-4.7,-1.6,1.6,4.7][i%4],traffic_speed)})
	var cop = Traffic.vehicle(Color("cdcec3"),false,true)
	add_child(cop)
	var support=Traffic.vehicle(Color("babfc3"),false,true)
	add_child(support)
	police = {"speed":0.0,"phase":"pursuit","yaw":0.0,"side":1.0,"hold":0.0,"support_speed":0.0,"support_phase":"pursuit","support_side":-1.0,"support_hold":0.0,"support_mesh":support,"support_active":false,"support_s":-140.0,"support_lane":-2.0,"support_warning":0.0,"mesh":cop,"s":-90.0,"lane":2.0,"active":false,"warning":0.0,"arrest":0.0,"roadblock":false}
	for hazard in world.hazards:
		hazard.hit = false
		hazard.node.rotation = Vector3.ZERO
	mode = "ready"

func select_track(index: int) -> bool:
	if mode == "loading" or index < 0 or index >= career.catalog.tracks.size():
		return false
	var next: Dictionary = career.catalog.tracks[index]
	if next.id not in career.unlocked:
		notify("海岸断崖进入前三，解锁跨郡耐力赛。" if next.id=="interstate" else "松岭公路进入前三，解锁海岸断崖。",3)
		return false
	if next.id != track.id:
		clear_touch()
		mode = "loading"
		loading_title = next.name
		loading_progress = 0.0
		load_track(next)
	return true

func load_track(next: Dictionary) -> void:
	var gradual: bool = not test_mode
	if gradual:
		await get_tree().process_frame
		await get_tree().process_frame
	var entry: Dictionary
	if world_cache.has(next.id):
		entry = world_cache[next.id]
	else:
		var next_world = RoadBuilder.new()
		next_world.mobile_quality = touch_device
		next_world.visible = false
		add_child(next_world)
		var next_route = Route.new()
		next_world.add_child(next_route)
		next_route.curve = load("res://data/tracks/"+str(next.id)+".tres")
		next_world.build_progress.connect(func(value: float): loading_progress = value)
		await next_world.build(next_route,next,gradual)
		entry = {"world":next_world,"route":next_route}
		world_cache[next.id] = entry
	loading_progress = 1.0
	if gradual: await get_tree().process_frame
	remove_child(world)
	world = entry.world
	route = entry.route
	track = next
	if not world.is_inside_tree(): add_child(world)
	world.visible = true
	reset_race()

func start(practice: bool = false) -> void:
	if mode == "loading": return
	reset_race()
	tutorial = practice
	mode = "countdown"
	sound.click()
	if tutorial:
		for car in traffic:
			car.s += 1200

func menu_action(action: String) -> void:
	if mode == "loading": return
	clear_touch()
	sound.click()
	match action:
		"start": start(false)
		"practice": start(true)
		"garage":
			mode = "garage"
			hud.enter_garage()
		"settings": mode = "settings"
		"home":
			reset_race()
			mode = "ready"
		"resume": mode = resume_mode
		"retry": start(tutorial)
		"quit": get_tree().quit()

func apply_control_mode() -> void:
	clear_touch()
	touch.enabled = touch_device if career.settings.control_mode == 0 else career.settings.control_mode == 1
	hud.waiting_action = ""
	hud.queue_redraw()

func clear_touch() -> void:
	touch.clear()
	burst.charging = false
	burst.charge = 0
	burst.previous_held = false

func suspend_input() -> void:
	clear_touch()
	for action in Controls.KEYS: Input.action_release(action)
	if mode in ["racing","countdown"]:
		resume_mode = mode
		mode = "paused"

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		suspend_input()

func can_grab_target(index: int) -> bool:
	if index<0 or mode!="racing": return false
	var target: Dictionary = racers[index]
	return target.crash<=0 and not target.finished and target.weapon>0 and (target.windup>0 or target.stagger>0) and player.weapon==0 and absf(target.s-player.distance)<=2 and absf(target.lane-player.lane)<=2.2 and player.cooldown<=0 and player.crash_timer<=0 and player.stamina>=20 and player.dodge_time<=0 and not player.guarding and pending_attack<=0

func can_touch_grab() -> bool:
	return can_grab_target(target_index)

func primary_attack(prefer_grab: bool = false) -> bool:
	if mode!="racing": return false
	if prefer_grab and can_grab_target(nearest_target()):
		return Combat.grab(self)
	if attack(2 if player.weapon>0 else (0 if primary_punch else 1)):
		if player.weapon==0: primary_punch = not primary_punch
		return true
	return false

func _input(event: InputEvent) -> void:
	if not touch.enabled: return
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			touch.release(event.index,event.canceled)
		elif mode in ["racing","countdown"] and hud.mobile_landscape():
			var point = hud.mobile_point(event.position)
			var action = touch.press(event.index,point,touch.layout(hud.mobile_height(),career.settings.touch_left_handed),can_touch_grab())
			if action == "pause":
				suspend_input()
			elif action == "attack" and mode=="racing":
				primary_attack()
			elif action == "grab" and mode=="racing": Combat.grab(self)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and touch.fingers.has(event.index):
		touch.drag(event.index,hud.mobile_point(event.position))
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if hud.waiting_action != "":
		if event is InputEventKey and event.pressed and not event.echo:
			hud.rebind(event.physical_keycode)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			debug_hud = not debug_hud
		if event.keycode == KEY_M:
			career.settings.volume = 0.0 if career.settings.volume>0 else .7
		if event.keycode == KEY_ENTER and (mode=="ready" or (mode=="finished" and finish_presentation.buttons_ready())):
			start()
	if event.is_action_pressed("pause"):
		clear_touch()
		if mode in ["racing","paused"]:
			if mode == "racing":
				resume_mode = "racing"
				mode = "paused"
			else: mode = resume_mode
		elif mode in ["settings","garage"]:
			mode = "ready"
	if event.is_action_pressed("restart") and (mode in ["racing","paused"] or (mode=="finished" and finish_presentation.buttons_ready())):
		start(tutorial)
	if event is InputEventJoypadButton and event.pressed and mode == "ready" and event.button_index in [JOY_BUTTON_A,JOY_BUTTON_START]:
		start()
	if mode == "racing":
		if event.is_action_pressed("cruise"):
			cruise = not cruise
		if event.is_action_pressed("primary_attack"): primary_attack(true)
		if event.is_action_pressed("punch"): attack(0)
		if event.is_action_pressed("kick"): attack(1)
		if event.is_action_pressed("club"): attack(2)
		if event.is_action_pressed("dodge"): player.dodge()
		if event.is_action_pressed("grab"): Combat.grab(self)

func _physics_process(dt: float) -> void:
	player_mesh.pause_crash(mode != "racing")
	for r in racers:
		r.mesh.pause_crash(mode != "racing")
	if mode == "countdown":
		countdown -= dt
		if countdown<=0:
			mode = "racing"
			notify("GO！冲出车流。")
	if mode != "racing":
		return
	if hit_stop>0:
		hit_stop -= dt
		return
	if touch.cancel_boost:
		burst.charging = false
		burst.charge = 0
		burst.previous_held = false
		touch.cancel_boost = false
	var driving = touch.driving(cruise)
	if driving.brake>.1: cruise = false
	simulate(dt,driving.throttle,driving.brake,driving.steer,driving.boost)
	player_mesh.ground_move(route.point(player.distance,player.lane),route.yaw(player.distance)+player.heading_offset,dt)

func _process(dt: float) -> void:
	if mode=="finished":
		if finish_presentation.update(dt): sound.celebrate()
		player_mesh.celebration = smoothstep(.9,1.6,finish_presentation.age) if finish_presentation.champion else 0.0
	if mode != "paused":
		update_visuals(dt)
	message_time = maxf(0,message_time-dt)
	shake = maxf(0,shake-dt*2)
	flash = maxf(0,flash-dt*3)
	var pursuit = clampf(1-absf(player.distance-police.s)/100,0,1) if police.active else 0.0
	var audible_speed: float = finish_presentation.speed if mode=="finished" else player.speed
	var audible_throttle: float = Input.get_action_strength("throttle") if mode=="countdown" else throttle_value if mode=="racing" else 0.0
	sound.update(audible_speed,audible_throttle,pursuit,mode == "racing",career.settings.volume,absf(player.lane)>6.5,dt,career.settings.music,absf(player.steering_rate)*player.speed,mode=="countdown" or (mode=="finished" and result=="FINISH" and finish_presentation.age<1.8))
	hud.queue_redraw()
	if mode == "racing":
		frame_samples.append(dt)
		if frame_samples.size()>600:
			frame_samples.pop_front()

func simulate(dt: float, throttle: float, brake: float, steer: float, boost: bool) -> void:
	var contact_start = Contacts.snapshot(self)
	elapsed += dt
	throttle_value = throttle
	player.ground_slope = route.slope(player.distance)
	player.curve_force = route.curvature(player.distance)
	player.defend(dt,touch.driving(cruise).guard)
	var boost_active = burst.update(dt,boost,throttle>.1 and brake<.1 and player.crash_timer<=0)
	player.drive(dt,throttle,brake,steer,boost_active)
	if player.crash_timer>0 and is_instance_valid(player_mesh.crash_rig):
		var location = crash_location(player_mesh.crash_rig.bike_body.global_position)
		player.distance = location.x
		player.lane = location.y
	nitro = burst.meter()
	var illegal = player.lane<0 or player.speed>56
	heat = clampf(heat+(1.7*difficulty().heat if illegal else -.45)*dt,0,100)
	if pending_attack>0:
		pending_attack -= dt
		if pending_attack<=0:
			resolve_attack()
	endurance.update(self,dt)
	RacerAI.update(self,dt)
	Traffic.update(self,dt)
	Contacts.resolve(self,contact_start)
	rank = 1
	for r in racers:
		if r.finished or r.s>player.distance:
			rank += 1
	target_index = nearest_target()
	if tutorial:
		update_lesson()
		player.health = maxf(player.health,35)
		player.durability = maxf(player.durability,35)
	if player.health<=0 or player.durability<=0:
		finish("WRECKED","车辆或车手无法继续比赛")
	elif player.distance>=float(track.length):
		finish("FINISH","第 %d 名完赛" % rank)
	telemetry_clock += dt
	if telemetry_clock>=.25:
		telemetry_clock = 0
		telemetry.append([snappedf(elapsed,.01),snappedf(player.distance,.01),snappedf(player.lane,.01),snappedf(player.speed*3.6,.1),rank,player.knockouts])

func crash_location(point: Vector3) -> Vector2:
	var offset = route.curve.get_closest_offset(route.to_local(point))
	var lane_value = (point-route.point(offset)).dot(Basis(Vector3.UP,route.yaw(offset)).x)
	return Vector2(offset,clampf(lane_value,-7.8,7.8))

func update_lesson() -> void:
	if lesson == 0 and player.speed>20: lesson = 1
	if lesson == 1 and absf(player.lane-2)>1.2: lesson = 2
	if lesson == 2 and player.hits>0: lesson = 3
	if lesson == 3 and burst.activations>0: lesson = 4

func nearest_target(radius: float = 5.0) -> int:
	var best = -1
	var distance = radius
	for i in range(racers.size()):
		var r = racers[i]
		var d = Vector2(r.s-player.distance,r.lane-player.lane).length()
		if d<distance and r.crash<=0 and not r.finished:
			best = i
			distance = d
	return best

func attack(kind: int) -> bool:
	if kind<0 or kind>2 or player.cooldown>0 or player.crash_timer>0 or pending_attack>0 or player.guarding or player.dodge_time>0:
		return false
	if kind == 2 and player.weapon == 0:
		notify("空手 · 对手蓄力或硬直时按 O 夺械")
		return false
	sound.swing(kind)
	pending_kind = kind
	pending_attack = Combat.DELAYS[kind]
	player.cooldown = [.48,.78,.95][kind]
	player.attack_time = Combat.RECOVERY+pending_attack
	player.attack_kind = kind
	attack_target = nearest_target()
	if attack_target>=0:
		player.attack_side = -1 if racers[attack_target].lane<player.lane else 1
	heat = minf(100,heat+3*difficulty().heat)
	return true

func resolve_attack() -> bool:
	if attack_target<0 or player.crash_timer>0:
		return false
	var r = racers[attack_target]
	if r.crash>0 or r.finished or (r.lane-player.lane)*player.attack_side<0 or absf(r.s-player.distance)>2.6 or absf(r.lane-player.lane)>Combat.REACH[pending_kind]:
		return false
	if r.dodge > 0:
		notify(r.name+" 闪过攻击")
		return false
	var power: float = [13,17,Combat.WEAPONS[player.weapon].damage][pending_kind]
	if r.guard > 0 and pending_kind != 1 and r.stamina >= 20:
		r.stamina -= 20
		r.hp -= power*.2
		if r.style==4 and r.weapon==0 and pending_kind==2 and absf(r.lane-player.lane)<2.2:
			r.weapon = player.weapon
			player.weapon = 0
			pending_attack = 0
			player.attack_time = 0
			notify(r.name+" 格挡后夺走了武器！")
		else:
			notify(r.name+" 格挡 · 踢击可破防")
		return true
	if pending_kind == 1:
		r.guard = 0
	power *= 1.4 if player.counter_time > 0 else 1.0
	player.counter_time = 0
	r.hp -= power
	r.stability -= [22,40,32][pending_kind]
	r.lane += player.attack_side*Combat.IMPACTS[pending_kind].push
	r.stagger = Combat.IMPACTS[pending_kind].stagger
	r.mesh.react_to_hit(player.attack_side,pending_kind,elapsed)
	Combat.remember_hit(r,-1)
	r.cooldown = 1.1
	r.windup = 0
	r.last_hit_age = 0
	r.revenge += 1
	r.ko_credited = false
	player.hits += 1
	feedback(false,r.mesh.global_position+Vector3.UP,pending_kind,player.weapon)
	notify(["拳击命中","踢击！推入车流","棍击命中"][pending_kind])
	if r.hp<=0 or r.stability<=0 or absf(r.lane)>7.8:
		knock_out(attack_target,false,true)
	return true

func knock_out(index: int, environment: bool, direct: bool = false) -> void:
	var r = racers[index]
	if r.crash>0:
		return
	r.crash = BikeState.CRASH_DURATION
	r.crash_speed = r.speed
	r.weapon = 0
	r.speed = 0
	r.windup = 0
	if (environment or direct) and not r.ko_credited:
		r.ko_credited = true
		player.credit_ko(environment)
		notify(("环境击倒 " if environment else "击倒 ")+r.name+"   %d 连击" % player.combo)
		sound.hit(true)

func feedback(crash: bool, position: Vector3, kind: int = 0, weapon: int = 0, intensity: float = 1.0) -> void:
	var impact: Dictionary = Combat.IMPACTS[kind]
	shake = maxf(shake,(.75 if crash else impact.shake)*intensity)
	flash = maxf(flash,(.28 if crash else impact.flash)*intensity)
	hit_stop = maxf(hit_stop,(.06 if crash else impact.stop)*intensity)
	sound.hit(crash,kind,weapon,intensity)
	for i in range(10):
		var mesh = MeshInstance3D.new()
		var shape = SphereMesh.new()
		shape.radius = .024
		shape.height = .048
		mesh.mesh = shape
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color("e7b34f")
		mesh.material_override = m
		add_child(mesh)
		mesh.global_position = position
		particles.append({"mesh":mesh,"velocity":Vector3(rng.randf_range(-3,3),rng.randf_range(1,4),rng.randf_range(-3,3)),"life":.45})

func finish(title: String, subtitle: String) -> void:
	if mode == "finished":
		return
	mode = "finished"
	result = title
	message = subtitle
	clear_touch()
	pending_attack = 0
	player.attack_time = 0
	player.guarding = false
	finish_presentation.begin(title,rank==1 and not tutorial,player.distance,player.speed)
	if not settled:
		settled = true
		if title == "FINISH" and not tutorial:
			reward = career.settle(track.id,rank,elapsed,player.knockouts,player.environment_kos)
			if not test_mode and not career.save_profile():
				message += " · 存档失败"
		if not test_mode:
			var replay = FileAccess.open("user://last_race.json",FileAccess.WRITE)
			if replay:
				replay.store_string(JSON.stringify({"track":track.id,"result":title,"time":elapsed,"rank":rank,"samples":telemetry}))

func notify(value: String, duration: float = 2.4) -> void:
	message = value
	message_time = duration

func update_visuals(dt: float) -> void:
	var visual_distance: float = finish_presentation.distance if mode=="finished" and finish_presentation.active else player.distance
	camera.cull_mask = 0 if mode=="garage" else 1048575
	if mode in ["ready","garage","settings","finished","countdown"]:
		player_mesh.position = route.point(visual_distance,player.lane)
		player_mesh.rotation.y = route.yaw(visual_distance)+player.heading_offset
	player_mesh.ride_speed = finish_presentation.speed if mode=="finished" else player.speed
	player_mesh.damage_visuals.update(player.durability/player.max_durability,mode=="racing" and player.crash_timer<=0)
	player_mesh.set_combat(player.weapon,player.guarding,player.dodge_time,0)
	player_mesh.crash_velocity = route.tangent(player.distance)*player.crash_speed*maxf(0,cos(player.heading_offset))*.35+Basis(Vector3.UP,route.yaw(player.distance)).x*player.crash_lateral
	player_mesh.pose(elapsed,player.lean,route.slope(player.distance),player.crash_timer,player.attack_time,player.attack_side,player.attack_kind,flash,visual_distance)
	for r in racers:
		r.mesh.position = route.point(r.s,r.lane)
		r.mesh.rotation.y = route.yaw(r.s)
		r.mesh.ride_speed = r.speed
		r.mesh.set_combat(r.weapon,r.guard>0,r.dodge,r.windup)
		r.mesh.crash_velocity = route.tangent(r.s)*r.crash_speed*.35+ r.mesh.global_basis.x*signf(r.lane-player.lane)*2
		r.mesh.pose(elapsed,clampf(atan(route.curvature(r.s)*r.speed*r.speed/9.8)*.65,-.65,.65),route.slope(r.s),r.crash,r.attack_time,r.attack_side,r.kind,r.stagger,r.s)
	for car in traffic:
		car.mesh.position = route.point(car.s,car.lane)
		var direction: float = car.driver.direction if car.has("driver") else (-1.0 if car.speed<0 else 1.0)
		car.mesh.rotation = Vector3(route.slope(car.s)*direction,route.yaw(car.s)+(PI if direction<0 else 0),0)
	police.support_mesh.get_node("VehicleSolid").collision_layer=8 if police.active and police.support_active else 0
	police.mesh.get_node("VehicleSolid").collision_layer=8 if police.active else 0
	police.support_mesh.visible=police.active and police.support_active
	police.support_mesh.position=route.point(police.support_s,police.support_lane)
	police.support_mesh.rotation.y=route.yaw(police.support_s)
	police.mesh.visible = police.active
	police.mesh.position = route.point(police.s,police.lane)
	police.mesh.rotation.y = route.yaw(police.s)+police.yaw
	var pos = player_mesh.position
	var direction = route.tangent(visual_distance).rotated(Vector3.UP,player.heading_offset)
	var desired = pos-direction*4.3+Vector3.UP*1.95
	var look = pos+direction*16+Vector3.UP*1.25
	if mode=="finished" and finish_presentation.champion:
		var turn = smoothstep(.55,2.2,finish_presentation.age)
		desired = desired.lerp(pos+direction*3.8+player_mesh.global_basis.x*3+Vector3.UP*1.9,turn)
		look = look.lerp(pos+Vector3.UP*1.05,turn)
	if mode in ["ready","garage","settings"]:
		desired = pos+Vector3(3.6,1.9,3.8)
		look = pos+Vector3(0,.9,0)
	camera.position = camera.position.lerp(desired,minf(1,dt*8))
	if mode not in ["ready","garage","settings"]:
		camera.position += direction*(desired-camera.position).dot(direction)
	camera.position.x += sin(elapsed*67)*shake*.11*career.settings.shake
	camera.look_at(look)
	if mode == "racing": camera.rotation.z += player.lean*.09
	camera.fov = lerpf(camera.fov,58 if mode in ["ready","garage","settings"] else 60+player.speed*.14,minf(dt*5,1))
	for i in range(particles.size()-1,-1,-1):
		var p = particles[i]
		p.life -= dt
		p.velocity.y -= dt*9
		p.mesh.position += p.velocity*dt
		if p.life<=0:
			p.mesh.queue_free()
			particles.remove_at(i)
