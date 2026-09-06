extends SceneTree
const Race = preload("res://game/race.gd")
const Combat = preload("res://game/systems/combat.gd")
var failures = 0
var checks = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if value: print("[PASS] "+label)
	else:
		failures += 1
		printerr("FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var race = Race.new()
	race.test_mode = true
	root.add_child(race)
	race.set_process(false)
	race.set_physics_process(false)
	race.mode = "racing"
	for r in race.racers: r.s = 1000.0
	var enemy = race.racers[1]
	enemy.s = 0.0
	enemy.lane = 3.5
	check(not race.attack(2),"空手无法凭空棍击")
	check(not Combat.grab(race) and enemy.weapon==1,"无前摇/硬直窗口无法夺械")
	race.player.cooldown = 0
	enemy.windup = .5
	check(Combat.grab(race) and race.player.weapon==1 and enemy.weapon==0 and enemy.windup==0,"夺械原子转移所有权并打断蓄力")
	race.player.cooldown = 0
	check(race.attack(2),"持有武器允许挥击")
	race.pending_attack = 0
	check(race.resolve_attack() and enemy.hp==72,"木棒伤害 28")
	race.player.attack_time = 0
	race.player.cooldown = 0
	race.player.stamina = 100
	race.player.defend(.1,true)
	enemy.weapon = 2
	enemy.kind = 2
	check(Combat.enemy_strike(race,enemy)=="parry" and race.player.health==100 and enemy.stagger>1,"精准格挡无伤并使对手硬直")
	race.player.defend(.3,true)
	check(Combat.enemy_strike(race,enemy)=="block" and race.player.health==98,"持续格挡降低伤害")
	race.player.guarding = false
	check(race.player.dodge(),"足够体力可闪避")
	check(Combat.enemy_strike(race,enemy)=="dodge" and race.player.health==98,"闪避窗口免伤")
	check(not race.player.dodge(),"闪避冷却禁止连按")
	race.player.dodge_time = 0
	race.player.dodge_cooldown = 0
	race.player.stamina = 10
	check(not race.player.dodge(),"不足体力不能闪避")
	race.player.dodge_time = 0
	race.player.guarding = false
	race.player.cooldown = 0
	race.player.weapon = 2
	enemy.hp = 100
	enemy.lane = 3.5
	enemy.guard = .5
	enemy.stamina = 100
	enemy.style = 4
	enemy.weapon = 0
	race.attack(2)
	race.pending_attack = 0
	race.resolve_attack()
	check(race.player.weapon==0 and enemy.weapon==2,"AI 近身格挡后可以夺走玩家武器")
	enemy.guard = 0
	enemy.dodge = .3
	race.player.cooldown = 0
	race.attack(0)
	race.pending_attack = 0
	var previous_hp: float = enemy.hp
	check(not race.resolve_attack() and enemy.hp==previous_hp,"AI 闪避期间攻击落空")
	enemy.dodge = 0
	enemy.guard = .5
	race.player.cooldown = 0
	race.attack(1)
	race.pending_attack = 0
	check(race.resolve_attack() and enemy.guard==0,"踢击破防")
	race.player_mesh.global_position = race.route.point(320,2)
	race.player_mesh.rotation.y = race.route.yaw(320)
	race.player.distance = 320
	for i in range(20): race.player_mesh.ground_move(race.route.point(320+i*.05,2),race.route.yaw(320),1.0/60)
	var before_front: float = race.player_mesh.front_compression
	for i in range(20): race.player_mesh.ground_move(race.route.point(321,2),race.route.yaw(321),1.0/60)
	check(race.player_mesh.front_compression>=0 and race.player_mesh.front_compression<=.12 and absf(before_front-race.player_mesh.front_compression)>.00001,"弹簧悬挂响应制动并保持行程范围")
	race.player.weapon = 2
	race.player.speed = 45
	race.player.lateral_velocity = 3
	race.player.crash()
	check(race.player.weapon==0 and race.player.crash_speed==45,"摔车丢武器并保存碰撞动量")
	race.update_visuals(.016)
	var rig = race.player_mesh.crash_rig
	check(rig.bodies.size()==12,"11 段人体刚体和独立摩托")
	var start: Vector3 = rig.bodies.spine.global_position
	for i in range(90):
		await physics_frame
		rig.sync(race.player_mesh)
	var end: Vector3 = rig.bodies.spine.global_position
	check(end.distance_to(start)>1.0,"真实物理步推进摔车动量")
	var bounded = true
	for body in rig.bodies.values():
		bounded = bounded and body.global_position.is_finite() and body.global_position.y > race.route.point(320).y-1 and body.global_position.distance_to(start)<35
	check(bounded,"刚体无穿地、数值爆炸或异常弹飞")
	rig.pause(true)
	var paused: Vector3 = rig.bodies.spine.global_position
	for i in range(12): await physics_frame
	check(rig.bodies.spine.global_position.distance_to(paused)<.001,"暂停冻结物理摔车")
	rig.pause(false)
	race.player.crash_timer = 4.1
	race.update_visuals(.016)
	check(rig.settled,"起身阶段锁定实际倒地位置")
	var projected = race.crash_location(rig.bike_body.global_position)
	check(projected.x>315 and projected.x<355,"碰撞恢复投影保持实际赛程")
	var limbs_ok = true
	for frame in range(30,253):
		race.player_mesh.recovery_blend = 1
		race.player_mesh.recovery_motion.apply(race.player_mesh,minf(frame/60.0,4.2))
		for key in race.player_mesh.segments:
			if key.begins_with("forearm"):
				var points = race.player_mesh.segments[key]
				limbs_ok = limbs_ok and points[0].distance_to(points[1])<.33
	check(limbs_ok,"起身抓把和上车时前臂不拉伸")
	var seated: Dictionary = race.player_mesh.segments.duplicate(true)
	race.player.crash_timer = 0
	race.update_visuals(.016)
	var transition = 0.0
	for key in seated:
		transition = maxf(transition,seated[key][1].distance_to(race.player_mesh.segments[key][1]))
	check(transition<.03,"跨腿上车终点连续接回骑姿")
	check(race.player_mesh.crash_rig==null,"恢复驾驶清理物理身体")
	race.sound.stop_all()
	race.queue_free()
	await process_frame
	await create_timer(.25).timeout
	print("CORE_RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
