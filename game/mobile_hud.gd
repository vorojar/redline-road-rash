extends RefCounted

const ICONS = {
	"steer": preload("res://assets/ui/steer.svg"),
	"attack": preload("res://assets/ui/attack.svg"),
	"brake": preload("res://assets/ui/brake.svg"),
	"guard": preload("res://assets/ui/guard.svg"),
	"boost": preload("res://assets/ui/boost.svg"),
	"grab": preload("res://assets/ui/grab.svg"),
	"pause": preload("res://assets/ui/pause.svg")
}

func draw_control(h, action: String, rect: Rect2) -> void:
	var active: bool = h.race.touch.held(action)
	var center = rect.get_center()
	var radius = rect.size.x*.5
	var color = h.gold if action=="boost" else h.cream
	h.draw_circle(center,radius,Color(.025,.04,.032,.78),true,-1,true)
	if active:
		h.draw_circle(center,radius-2,Color(.48,.16,.12,.88),true,-1,true)
	h.draw_arc(center,radius-1,0,TAU,64,Color(color,.9 if active else .48),2,true)
	if action == "steer":
		h.draw_arc(center,radius-12,0,TAU,64,Color(h.cream,.13),1.5,true)
		var knob = center+Vector2(h.race.touch.steer*50,0)
		h.draw_circle(knob,29,Color(h.cream,.22 if active else .12),true,-1,true)
		h.draw_texture_rect(ICONS.steer,Rect2(knob-Vector2(20,20),Vector2(40,40)),false,h.cream)
	else:
		var size = radius*(1.02 if action=="attack" else .98)
		h.draw_texture_rect(ICONS[action],Rect2(center-Vector2.ONE*size*.5,Vector2.ONE*size),false,color)
		if action == "boost":
			h.draw_arc(center,radius-6,-PI*.5,-PI*.5+TAU*clampf(h.race.nitro/100,.001,1),64,h.gold,3.5,true)

func draw(h) -> void:
	var race = h.race
	var height: float = h.mobile_height()
	if not h.mobile_landscape():
		h.panel(Rect2(0,0,960,height),Color("101713"))
		h.text("REDLINE",80,height*.43,70,h.cream,true)
		h.text("请横屏握持手机或平板",80,height*.43+75,36,h.gold)
		h.text("转回横屏后，点继续比赛",80,height*.43+132,30,h.faded)
		return
	if race.mode in ["ready","garage","settings"]:
		draw_menu(h,height)
	else:
		draw_race(h,height)

func heading(h, title: String) -> void:
	h.panel(Rect2(0,0,960,82),Color("101713"))
	h.text(title,24,52,34,h.cream,true)
	h.text("$ %d" % h.race.career.credits,732,51,26,h.gold)

func draw_menu(h, height: float) -> void:
	var race = h.race
	if race.mode!="ready": h.draw_rect(Rect2(0,0,960,height),Color("101713"))
	heading(h,"REDLINE" if race.mode=="ready" else ("车库 / GARAGE" if race.mode=="garage" else "驾驶设置"))
	if race.mode == "ready":
		h.panel(Rect2(16,92,436,252))
		for i in range(2):
			var track: Dictionary = race.career.catalog.tracks[i]
			h.button(Rect2(28,104+i*76,412,64),track.name+(" · 未解锁" if track.id not in race.career.unlocked else ""),func(): race.select_track(i),race.track.id==track.id)
		h.button(Rect2(28,268,412,64),"开始比赛",func(): race.start(),true)
		h.panel(Rect2(478,92,458,92))
		h.panel(Rect2(16,356,436,70))
		h.text(race.career.bike().name,490,129,32,h.cream,true)
		h.text("自动油门 · 松开刹车继续加速",490,169,24,h.gold)
		h.button(Rect2(492,196,432,64),"车库 · 选择摩托",func(): race.menu_action("garage"))
		h.button(Rect2(492,272,432,64),"驾驶设置",func(): race.menu_action("settings"))
		h.button(Rect2(492,348,432,64),"教学练习",func(): race.start(true))
		h.text("左手滑动转向",28,379,26,h.cream)
		h.text("右手攻击 / 刹车 / 蓄力冲刺",28,414,24,h.faded)
	elif race.mode == "garage":
		h.panel(Rect2(16,88,414,height-104),Color("101713"))
		for i in range(3):
			var bike: Dictionary = race.career.catalog.bikes[i]
			h.button(Rect2(28,100+i*74,390,64),bike.name,func(): h.preview_bike(i),h.garage_index==i)
		var selected: Dictionary = race.career.catalog.bikes[h.garage_index]
		var owned: bool = selected.id in race.career.owned
		h.button(Rect2(28,height-86,390,64),"使用这辆摩托" if owned else "购买 $%d" % selected.price,func(): h.purchase_bike(),true,not owned and race.career.credits<int(selected.price))
		h.text("%d km/h · 耐久 %d" % [selected.top_speed*3.6,selected.durability],456,116,26,h.gold)
		h.button(Rect2(452,height-86,218,64),"重置视角",func(): h.garage_view.reset_view())
		h.button(Rect2(684,height-86,252,64),"返回赛事",func(): race.menu_action("home"))
	else:
		var settings: Dictionary = race.career.settings
		h.panel(Rect2(16,92,928,height-108),Color("101713"))
		h.button(Rect2(28,104,430,64),"难度："+race.difficulty().name,func(): settings.difficulty=(int(settings.difficulty)+1)%3; h.save_settings())
		h.button(Rect2(28,180,430,64),"道路辅助："+("开" if settings.assist else "关"),func(): settings.assist=not settings.assist; race.player.assist=settings.assist; h.save_settings())
		h.button(Rect2(28,256,430,64),"音量：%d%%" % (settings.volume*100),func(): settings.volume=0.0 if settings.volume>=.99 else minf(1,settings.volume+.25); h.save_settings())
		h.button(Rect2(28,332,430,64),"音乐：%d%%" % (settings.music*100),func(): settings.music=0.0 if settings.music>=.99 else minf(1,settings.music+.25); h.save_settings())
		h.button(Rect2(490,104,434,64),"操作："+h.control_mode_label(),func(): h.cycle_control_mode())
		h.button(Rect2(490,180,434,64),"转向区："+("右手" if settings.touch_left_handed else "左手"),func(): settings.touch_left_handed=not settings.touch_left_handed; race.clear_touch(); h.save_settings())
		h.text("油门自动开启，按住刹车减速。",490,287,24,h.faded)
		h.button(Rect2(490,332,434,64),"保存并返回",func(): h.save_settings(); race.mode="ready",true)
	if race.message_time>0:
		h.panel(Rect2(190,84,580,52))
		h.text(race.message,206,119,24,h.gold)

func draw_race(h, height: float) -> void:
	var race = h.race
	var p = race.player
	h.panel(Rect2(0,0,960,90),Color(.04,.065,.05,.90))
	h.text("%03d" % int(p.speed*3.6),24,52,40,h.cream,true)
	h.text("km/h",120,50,22,h.faded)
	h.text("%d / 6" % race.rank,230,51,32,h.cream,true)
	h.text("%d / %d m" % [p.distance,race.track.length],362,49,24,h.faded)
	var opponent = race.nearest_target(18)
	if opponent>=0:
		var rival = race.racers[opponent]
		h.text(rival.name+" · %d m" % Vector2(rival.s-p.distance,rival.lane-p.lane).length(),610,29,20,h.red if rival.windup>0 else h.cream,true)
		h.bar(610,43,220,rival.hp,h.red if rival.hp<35 else h.gold)
		h.text("准备格挡" if rival.windup>0 else "对手体力",610,78,18,h.red if rival.windup>0 else h.faded)
	else:
		h.text(race.Combat.WEAPONS[p.weapon].name,624,49,24,h.gold)
	h.bar(24,70,160,p.health,h.red if p.health<35 else Color("789463"))
	h.bar(230,70,104,p.durability/p.max_durability*100,h.gold)
	h.bar(362,70,210,p.stamina,Color("758e82"))
	if race.mode in ["racing","countdown"]:
		var rects: Dictionary = race.touch.layout(height,race.career.settings.touch_left_handed)
		for action in rects:
			var rect: Rect2 = rects[action]
			if action=="grab" and not race.can_touch_grab(): continue
			draw_control(h,action,rect)

		var preview: float = race.route.curvature(p.distance+maxf(25,p.speed*1.4))
		if absf(preview)>.006:
			var advised = int(p.corner_speed(preview,p.top_speed,p.handling)*3.6/10)*10
			h.panel(Rect2(288,102,384,48))
			h.text(("左弯" if preview>0 else "右弯")+" · 建议 %d km/h" % advised,308,135,26,h.gold)
		if race.message_time>0:
			h.text(race.message,300,187,24,h.cream)
		if p.crash_timer>0:
			h.panel(Rect2(288,162,384,62))
			h.text("摔车 · 起身 %.1f s" % p.crash_timer,310,205,28,h.red,true)
		if race.tutorial:
			var lessons = ["自动加速至 70 km/h","滑动转向，换到另一条车道","靠近对手，点击攻击命中","按住蓄力，蓄满后松开冲刺","教学完成 · 继续挑战终点"]
			h.text(lessons[race.lesson],288,224,24,h.gold)
	if race.mode in ["paused","finished","countdown"]:
		draw_overlay(h,height)

func draw_overlay(h, height: float) -> void:
	var race = h.race
	if race.mode == "countdown":
		h.text(str(int(ceil(race.countdown))),448,height*.50,80,h.gold,true)
		h.text("自动油门 · 准备转向",344,height*.50+45,26,h.cream)
		return
	h.panel(Rect2(0,90,960,height-90),Color(.02,.03,.025,.75))
	var y = maxf(96,(height-324)*.5)
	h.panel(Rect2(204,y,552,324),Color("101713"))
	h.text("比赛已暂停" if race.mode=="paused" else race.result,230,y+47,36,h.cream,true)
	if race.mode == "paused":
		h.text("滑动转向 · 点击攻击",230,y+91,26,h.gold)
		h.text("按住刹车减速，松开后自动加速。",230,y+130,24,h.faded)
	else:
		h.text("名次 %d / 6 · 用时 %.1f s" % [race.rank,race.elapsed],230,y+91,26,h.gold)
		h.text("奖金 $%d · 余额 $%d" % [race.reward,race.career.credits],230,y+130,26,h.cream)
	h.button(Rect2(230,y+164,500,64),"继续比赛" if race.mode=="paused" else "再赛一局",func(): race.menu_action("resume" if race.mode=="paused" else "retry"),true)
	h.button(Rect2(230,y+242,500,64),"返回赛事 / 车库",func(): race.menu_action("home"))
