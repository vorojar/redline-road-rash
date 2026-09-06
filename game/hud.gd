extends Control

const Controls = preload("res://game/systems/controls.gd")
var touch_font = FontVariation.new()
var touch_bold = FontVariation.new()
var mobile = preload("res://game/mobile_hud.gd").new()
var race: Node3D
var font = SystemFont.new()
var bold = SystemFont.new()
var cream = Color("d8d3bd")
var faded = Color("8e948d")
var red = Color("c74632")
var gold = Color("bb9d54")
var clicks: Array[Dictionary] = []
var waiting_action: String = ""
var garage_index: int = 0
var hover: Vector2
var garage_view: SubViewportContainer

func _ready() -> void:
	var ui_font_path = "res://assets/fonts/RedlineUI.ttf" if OS.has_feature("web") else "res://assets/fonts/NotoSansSC.ttf"
	if OS.get_name()=="Windows" or OS.has_feature("web"):
		font = load(ui_font_path)
		bold = FontVariation.new()
		bold.base_font = font
		bold.variation_embolden = .7
	else:
		font.font_names = PackedStringArray(["Helvetica Neue","PingFang SC"])
		bold.font_names = font.font_names
		bold.font_weight = 800
	touch_font.base_font = load(ui_font_path)
	touch_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):500}
	touch_bold.base_font = touch_font.base_font
	touch_bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):700}
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	garage_view = preload("res://game/garage_view.gd").new()
	add_child(garage_view)
	garage_view.visible = false

func _process(_dt: float) -> void:
	if race.touch.enabled and not mobile_landscape() and race.mode in ["racing","countdown"]:
		race.suspend_input()
	garage_view.visible = race.mode == "garage" and (not race.touch.enabled or mobile_landscape())
	if race.touch.enabled:
		var factor = mobile_scale()
		garage_view.position = mobile_origin()+Vector2(448,130)*factor
		garage_view.size = Vector2(488,maxf(100,mobile_height()-228))*factor
		return
	var scale_value = get_viewport_rect().size/Vector2(1440,900)
	garage_view.position = Vector2(643,190)*scale_value
	garage_view.size = Vector2(735,465)*scale_value

func enter_garage() -> void:
	for i in range(race.career.catalog.bikes.size()):
		if race.career.catalog.bikes[i].id == race.career.selected:
			garage_index = i
	garage_view.show_bike(race.career.catalog.bikes[garage_index])


func mobile_landscape() -> bool:
	return get_viewport_rect().size.x>=get_viewport_rect().size.y

func mobile_scale() -> float:
	return minf(get_viewport_rect().size.x/960.0,get_viewport_rect().size.y/432.0)

func mobile_origin() -> Vector2:
	return Vector2((get_viewport_rect().size.x-960*mobile_scale())*.5,0)

func mobile_height() -> float:
	return get_viewport_rect().size.y/mobile_scale()

func mobile_point(point: Vector2) -> Vector2:
	return (point-mobile_origin())/mobile_scale()

func control_mode_label() -> String:
	return ["自动识别","触屏","键盘 / 手柄"][race.career.settings.control_mode]

func cycle_control_mode() -> void:
	race.career.settings.control_mode = (race.career.settings.control_mode+1)%3
	race.apply_control_mode()
	save_settings()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover = mobile_point(event.position) if race.touch.enabled else event.position/get_viewport_rect().size*Vector2(1440,900)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point = mobile_point(event.position) if race.touch.enabled else event.position/get_viewport_rect().size*Vector2(1440,900)
		for button in clicks:
			if button.rect.has_point(point):
				button.callback.call()
				accept_event()
				break

func rebind(key: int) -> void:
	if key == KEY_ESCAPE:
		waiting_action = ""
		return
	if key in [KEY_ENTER,KEY_R,KEY_M,KEY_F3,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:
		race.notify("该按键保留给菜单或方向键，请选其他键。",3)
		return
	var bindings: Dictionary = race.career.settings.bindings
	var old = int(bindings.get(waiting_action,Controls.KEYS[waiting_action]))
	for action in Controls.LABELS:
		if action != waiting_action and int(bindings.get(action,Controls.KEYS[action])) == key:
			bindings[action] = old
	bindings[waiting_action] = key
	Controls.setup(bindings)
	waiting_action = ""
	save_settings()

func save_settings() -> void:
	if not race.test_mode and not race.career.save_profile():
		race.notify("设置未能保存。",3)

func text(value: String,x: float,y: float,size: int = 18,color: Color = Color("d8d3bd"),heavy: bool = false) -> void:
	var selected_font = (touch_bold if heavy else touch_font) if race.touch.enabled else (bold if heavy else font)
	draw_string(selected_font,Vector2(x,y),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func panel(rect: Rect2, color: Color = Color(0.035,.042,.04,.94)) -> void:
	draw_rect(rect,color)
	draw_rect(rect,Color(.5,.51,.45,.30),false,1)

func button(rect: Rect2,label: String,callback: Callable,primary: bool = false,disabled: bool = false) -> void:
	var color = Color("772a22") if primary else Color("292e2b")
	if rect.has_point(hover) and not disabled:
		color = color.lightened(.15)
	if disabled:
		color = Color("191e1c")
	panel(rect,color)
	text(label,rect.position.x+18,rect.position.y+rect.size.y*.5+9,26 if race.touch.enabled else 20,faded if disabled else cream,true)
	if not disabled:
		clicks.append({"rect":rect,"callback":callback})

func bar(x: float,y: float,width: float,value: float,color: Color) -> void:
	draw_rect(Rect2(x,y,width,7),Color("303732"))
	draw_rect(Rect2(x,y,width*clampf(value/100,0,1),7),color)

func dial(center: Vector2,radius: float,value: float,maximum: float,label: String) -> void:
	draw_circle(center,radius+5,Color("747a72"))
	draw_circle(center,radius+2,Color("242925"))
	draw_circle(center,radius,Color("0a100e"))
	for i in range(25):
		var a = deg_to_rad(140+i*10.8)
		var dir = Vector2(cos(a),sin(a))
		draw_line(center+dir*(radius-5),center+dir*(radius-(14 if i%4==0 else 8)),red if i>20 else cream,2)
		if i%4==0:
			text(str(int(float(i)/24*maximum)),center.x+dir.x*(radius-28)-10,center.y+dir.y*(radius-28)+5,12,faded)
	var angle = deg_to_rad(140+clampf(value/maximum,0,1)*259)
	draw_line(center-Vector2(cos(angle),sin(angle))*9,center+Vector2(cos(angle),sin(angle))*(radius-20),red,3)
	draw_circle(center,5,cream)
	text(label,center.x-19,center.y+radius*.54,11,faded)

func _draw() -> void:
	if race != null and race.touch.enabled:
		clicks.clear()
		draw_set_transform(mobile_origin(),0,Vector2.ONE*mobile_scale())
		mobile.draw(self)
		return
	draw_set_transform(Vector2.ZERO,0,get_viewport_rect().size/Vector2(1440,900))
	clicks.clear()
	if race == null or race.player == null:
		return
	if race.mode in ["ready","garage","settings"]:
		draw_menu()
	else:
		draw_race()
	if race.message_time>0 and race.mode in ["ready","garage","settings"]:
		panel(Rect2(480,821,880,45))
		text(race.message,500,850,17,gold)

func draw_menu() -> void:
	draw_rect(Rect2(0,0,1440,100),Color(.03,.04,.04,.90))
	text("REDLINE",48,59,42,cream,true)
	text("公 路 狂 徒   /   CLASSIC HIGHWAY COMBAT",285,55,16,faded)
	text("$ %s" % race.career.credits,1210,54,25,gold,true)
	if race.mode == "ready":
		panel(Rect2(45,145,465,619))
		text("THE ROAD BELONGS",73,197,25,cream,true)
		text("TO NOBODY.",73,241,38,cream,true)
		text("高速穿过车流，把对手甩在身后。",73,284,18,faded)
		text("选择赛事",73,333,14,gold)
		for i in range(2):
			var track: Dictionary = race.career.catalog.tracks[i]
			var locked = track.id not in race.career.unlocked
			button(Rect2(73,349+i*61,408,51),("▶ " if race.track.id == track.id else "   ")+track.name+(" · 未解锁" if locked else ""),func(): race.select_track(i),race.track.id == track.id)
		button(Rect2(73,492,408,61),"开始比赛     ENTER",func(): race.start(),true)
		button(Rect2(73,567,197,48),"车库 / GARAGE",func(): race.menu_action("garage"))
		button(Rect2(284,567,197,48),"驾驶设置",func(): race.menu_action("settings"))
		button(Rect2(73,629,408,48),"教学练习 · 不计奖金",func(): race.start(true))
		text("WASD 驾驶  ·  J K L 攻击  ·  SHIFT 蓄力",73,717,16,faded)
		text(race.track.subtitle,875,668,21,gold,true)
		text(race.career.bike().name,875,710,30,cream,true)
		text("%d km/h   ·   %s" % [int(race.player.top_speed*3.6),race.difficulty().name],875,744,18,cream)
		text("3D 重制 / 90 年代公路精神",48,851,14,faded)
	elif race.mode == "garage":
		draw_garage()
	else:
		draw_settings()

func draw_garage() -> void:
	draw_rect(Rect2(0,100,1440,800),Color("101713"))
	panel(Rect2(633,136,755,657))
	text("360° SHOWROOM",655,174,22,cream,true)
	panel(Rect2(45,136,570,657))
	text("GARAGE",73,190,37,cream,true)
	text("比赛获奖金，升级你的公路机器。",73,223,18,faded)
	for i in range(3):
		var bike: Dictionary = race.career.catalog.bikes[i]
		button(Rect2(73,250+i*66,512,55),bike.name+("  /  已拥有" if bike.id in race.career.owned else "  /  $%d" % bike.price),func(): preview_bike(i),garage_index == i)
	var selected: Dictionary = race.career.catalog.bikes[garage_index]
	text(selected.description,73,480,18,faded)
	text("极速",73,522,15)
	bar(143,512,315,selected.top_speed/65*100,gold)
	text("%d km/h" % int(selected.top_speed*3.6),474,522,17,gold)
	text("加速",73,554,15)
	bar(143,544,315,selected.acceleration/18*100,gold)
	text("%.1f" % selected.acceleration,474,554,17,cream)
	text("操控",73,586,15)
	bar(143,576,315,selected.handling/6*100,gold)
	text("%.1f" % selected.handling,474,586,17,cream)
	text("耐久",73,618,15)
	bar(143,608,315,selected.durability/130*100,gold)
	text("%d" % selected.durability,474,618,17,cream)
	var owned = selected.id in race.career.owned
	button(Rect2(73,652,512,52),"使用这辆摩托" if owned else "购买  $%d" % selected.price,func(): purchase_bike(),true,not owned and race.career.credits<int(selected.price))
	button(Rect2(73,722,512,44),"← 返回赛事",func(): race.menu_action("home"))
	text(selected.name,660,711,32,cream,true)
	text(selected.body_style,660,744,17,gold)
	text("拖动旋转 / 上下调整视角 · 滚轮缩放",659,774,15,faded)
	button(Rect2(1125,665,235,47),"自动旋转："+("开" if garage_view.auto_rotate else "关"),func(): garage_view.auto_rotate=not garage_view.auto_rotate)
	button(Rect2(1125,727,235,42),"重置视角",func(): garage_view.reset_view())

func preview_bike(index: int) -> void:
	garage_index = index
	garage_view.show_bike(race.career.catalog.bikes[index])
	race.sound.click()

func purchase_bike() -> void:
	var selected: Dictionary = race.career.catalog.bikes[garage_index]
	if selected.id in race.career.owned:
		race.career.selected = selected.id
	elif not race.career.buy(selected.id):
		return
	save_settings()
	race.reset_race()
	race.mode = "garage"
	race.notify("已选择 "+selected.name)

func draw_settings() -> void:
	panel(Rect2(45,133,1350,670))
	text("DRIVING SETUP",75,186,35,cream,true)
	text("键盘 / 手柄 · 设置自动保存",75,217,17,faded)
	var settings = race.career.settings
	button(Rect2(75,249,400,50),"难度："+race.difficulty().name,func(): settings.difficulty=(int(settings.difficulty)+1)%3; save_settings())
	button(Rect2(75,312,400,50),"音量：%d%%" % (settings.volume*100),func(): settings.volume=0.0 if settings.volume>=.99 else minf(1,settings.volume+.25); save_settings())
	button(Rect2(75,375,400,50),"镜头震动：%d%%" % (settings.shake*100),func(): settings.shake=0.0 if settings.shake>.9 else settings.shake+.5; save_settings())
	button(Rect2(75,438,400,50),"道路辅助："+("开" if settings.assist else "关"),func(): settings.assist=not settings.assist; race.player.assist=settings.assist; save_settings())
	button(Rect2(75,501,400,50),"大号速度读数："+("开" if settings.large_hud else "关"),func(): settings.large_hud=not settings.large_hud; save_settings())
	button(Rect2(75,564,400,42),"音乐：%d%%" % (settings.music*100),func(): settings.music=0.0 if settings.music>=.99 else minf(1,settings.music+.25); save_settings())
	text("手柄：RT 油门 / LT 刹车 / 左摇杆 转向",75,634,17,cream)
	text("X 拳 / A 踢 / Y 武器 / B 格挡 / RB 蓄力",75,664,17,cream)
	text("L3 闪避 / R3 夺械 / LB 定速 / Start 暂停",75,694,16,faded)
	button(Rect2(75,710,620,60),"操作："+control_mode_label(),func(): cycle_control_mode())
	text("Music: Umplix (CC0) · Engines: dklon (CC-BY-SA 3.0)",75,797,13,faded)
	var actions = Controls.LABELS.keys()
	for i in range(actions.size()):
		var action: String = actions[i]
		var col = i/6
		var row = i%6
		button(Rect2(535+col*405,249+row*60,375,50),Controls.LABELS[action]+"     "+("按一个键…" if waiting_action == action else Controls.key_label(action,settings.bindings)),func(): waiting_action=action)
	button(Rect2(1028,722,332,48),"保存并返回",func(): save_settings(); race.mode="ready")

func draw_race() -> void:
	var p = race.player
	if race.mode=="racing" and p.crash_timer<=0:
		var preview = race.route.curvature(p.distance+maxf(25,p.speed*1.4))
		if absf(preview)>.006:
			var advised = int(p.corner_speed(preview,p.top_speed,p.handling)*3.6/10)*10
			panel(Rect2(532,28,370,68))
			text(("左弯  <<" if preview>0 else ">>  右弯")+"   建议 %d km/h" % advised,551,57,20,gold,true)
			text("入弯前收油 / 刹车" if p.speed*3.6>advised+10 else "保持选线 · 出弯加速",551,82,15,red if p.speed*3.6>advised+10 else faded)
	# The classic race information belongs on the instrument panel, keeping the road open.
	panel(Rect2(0,730,1440,170),Color("101713"))
	draw_line(Vector2(0,732),Vector2(1440,732),Color("717567"),3)
	text("REDLINE",28,766,22,cream,true)
	text("RIDER",29,804,13,faded)
	bar(97,796,190,p.health,Color("789463"))
	text("BIKE",29,835,13,faded)
	bar(97,827,190,p.durability/p.max_durability*100,gold)
	text("BALANCE",29,866,13,faded)
	bar(97,858,190,p.stability,red if p.stability<40 else Color("758e82"))
	dial(Vector2(397,817),67,p.speed*3.6,240,"KM/H")
	text("%03d" % int(p.speed*3.6),490,830,62 if race.career.settings.large_hud else 49,cream,true)
	text("KM/H",495,855,13,faded)
	text("GEAR",635,779,12,faded)
	text(str(race.sound.gear),648,823,35,gold,true)
	text("BURST",635,851,12,faded)
	bar(635,862,86,race.nitro,gold)
	text(race.burst.label(),493,888,13,gold if race.burst.charging else faded)
	text("POSITION",770,778,13,faded)
	text("%d / 6" % race.rank,770,827,41,cream,true)
	text("%02d:%05.2f" % [int(race.elapsed)/60,fmod(race.elapsed,60)],770,859,19,faded)
	text("%04d / %d M" % [int(p.distance),int(race.track.length)],951,778,17,cream)
	bar(951,794,208,p.distance/float(race.track.length)*100,gold)
	text("%d KO   /   %d 环境击倒" % [p.knockouts,p.environment_kos],951,831,17,cream)
	text("%d 连击" % p.combo,951,862,15,gold)
	draw_mini_map(Vector2(1300,818))
	text("J 拳  K 踢  L 武器  ·  U 格挡  I 闪避  O 夺械  ·  SHIFT 蓄力  SPACE 定速",398,710,14,cream)
	panel(Rect2(40,570,270,116))
	text(race.Combat.WEAPONS[p.weapon].name+"  /  "+("格挡中" if p.guarding else ("反击！" if p.counter_time>0 else "就绪")),58,601,19,gold,true)
	text("体力",58,632,14,faded)
	bar(108,623,177,p.stamina,Color("758e82"))
	text("闪避 %.1f s" % p.dodge_cooldown if p.dodge_cooldown>0 else "闪避可用 · O 抢夺蓄力中的武器",58,663,14,faded)
	if race.police.active or race.heat>15:
		panel(Rect2(1110,28,300,72))
		text("POLICE / 警方追击" if race.police.active else "HEAT / 警觉度",1127,57,17,red if race.police.active else gold,true)
		bar(1127,76,264,race.heat,red)
	var opponent = race.nearest_target(18)
	if opponent>=0 and race.mode == "racing":
		var r = race.racers[opponent]
		panel(Rect2(40,30,264,81))
		text(r.name+("  /  即将攻击" if r.windup>0 else "  /  %d m" % Vector2(r.s-p.distance,r.lane-p.lane).length()),58,60,18,red if r.windup>0 else cream,true)
		bar(58,82,226,r.hp,red)
		var world_pos = r.mesh.global_position+Vector3(0,2.15,0)
		if opponent==race.target_index and not race.camera.is_position_behind(world_pos):
			var screen = race.camera.unproject_position(world_pos)/get_viewport_rect().size*Vector2(1440,900)
			draw_arc(screen,13,0,TAU,20,red if r.windup>0 else gold,2)
	if race.message_time>0 and race.mode == "racing":
		panel(Rect2(447,637,546,45))
		text(race.message,465,667,19,cream,true)
	if p.crash_timer>0 and race.mode == "racing":
		var step = "滑行 / 失去控制" if p.crash_timer>4.2 else ("撑地 / 起身" if p.crash_timer>3.25 else ("走回摩托" if p.crash_timer>1.55 else ("抓把 / 扶车" if p.crash_timer>.75 else "跨腿上车")))
		panel(Rect2(490,294,460,116))
		text("CRASH",527,339,34,red,true)
		text(step+"   %.1f s" % p.crash_timer,527,382,22,cream)
	if race.tutorial and race.mode == "racing":
		var lessons = ["01  按住油门，达到 70 km/h","02  左右转向，移动到另一条车道","03  靠近骑手，按 J / K / L 命中一次","04  按住 Shift 蓄满，再松开冲刺","教学完成 · 继续挑战终点，练习中不会报废"]
		panel(Rect2(415,30,610,59))
		text(lessons[race.lesson],436,68,20,gold)
	if race.flash>0:
		draw_rect(Rect2(0,0,1440,730),Color(.65,.12,.05,race.flash*.3))
	if race.debug_hud:
		panel(Rect2(25,144,350,104))
		text("FPS %d   DRAW %d" % [Engine.get_frames_per_second(),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)],41,175,17)
		text("%.0f triangles" % Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),41,204,17)
		text("F3 隐藏 · 物理 60 Hz",41,231,14,faded)
	if race.mode in ["paused","finished","countdown"]:
		draw_overlay()

func draw_mini_map(center: Vector2) -> void:
	var p = race.player
	var prev = Vector2.ZERO
	for i in range(25):
		var s = clampf(p.distance-30+i*12,0,float(race.track.length))
		var t = race.route.point(s)-race.route.point(p.distance)
		var pos = center+Vector2(t.x*.16,-i*4+50)
		if i>0:
			draw_line(prev,pos,Color("657268"),5)
		prev = pos
	draw_circle(center+Vector2(p.lane*.5,38),4,red)
	text("ROUTE",center.x-24,center.y+65,11,faded)

func draw_overlay() -> void:
	draw_rect(Rect2(0,0,1440,730),Color(.02,.03,.025,.6))
	if race.mode == "countdown":
		text(str(int(ceil(race.countdown))),659,398,112,gold,true)
		text("油门准备  /  RT 或 W",602,451,21)
		return
	panel(Rect2(410,150,620,505))
	text("PAUSED" if race.mode == "paused" else race.result,450,221,49,cream,true)
	text("比赛已暂停" if race.mode == "paused" else race.message,450,269,22,gold)
	if race.mode == "finished":
		text("名次 %d / 6    用时 %.2f s" % [race.rank,race.elapsed],450,320,21)
		text("击倒 %d    环境击倒 %d    最长连击 %d" % [race.player.knockouts,race.player.environment_kos,race.player.best_combo],450,363,19)
		text("奖金  $%d      余额  $%d" % [race.reward,race.career.credits],450,408,24,gold,true)
		if "coast" in race.career.unlocked:
			text("海岸断崖赛事已解锁",450,445,16,faded)
	else:
		text("WASD / 方向键 驾驶   J K L 攻击",450,330,21)
		text("刹车会取消定速油门。",450,375,19,faded)
	button(Rect2(450,480,540,56),"继续比赛 / ESC" if race.mode == "paused" else "再赛一局 / R",func(): race.menu_action("resume" if race.mode == "paused" else "retry"),true)
	button(Rect2(450,552,540,51),"返回赛事 / 车库",func(): race.menu_action("home"))
