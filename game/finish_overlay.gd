extends RefCounted

static func text(h, value: String, pos: Vector2, size: float, color: Color, strong: bool = false) -> void:
	h.text(value,pos.x,pos.y,int(size),color,strong)

static func trophy(h, center: Vector2, scale: float, color: Color) -> void:
	# Layered cup, handles and pedestal keep the award legible at phone size.
	h.draw_circle(center+Vector2(0,-25)*scale,120*scale,Color(color,.06))
	for side in [-1,1]:
		var points=PackedVector2Array()
		for i in range(25):
			var a=lerpf(-PI*.5,PI*.5,i/24.0)
			points.append(center+Vector2(side*(67+43*cos(a)),-29+43*sin(a))*scale)
		h.draw_polyline(points,color.darkened(.25),10*scale,true)
	h.draw_colored_polygon(PackedVector2Array([center+Vector2(-74,-79)*scale,center+Vector2(74,-79)*scale,center+Vector2(58,-8)*scale,center+Vector2(26,33)*scale,center+Vector2(-26,33)*scale,center+Vector2(-58,-8)*scale]),color)
	h.draw_colored_polygon(PackedVector2Array([center+Vector2(-63,-72)*scale,center+Vector2(-10,-72)*scale,center+Vector2(-10,23)*scale,center+Vector2(-25,23)*scale,center+Vector2(-47,-9)*scale]),color.lightened(.22))
	h.draw_rect(Rect2(center+Vector2(-12,30)*scale,Vector2(24,54)*scale),color.darkened(.12))
	h.draw_colored_polygon(PackedVector2Array([center+Vector2(-12,78)*scale,center+Vector2(12,78)*scale,center+Vector2(52,97)*scale,center+Vector2(-52,97)*scale]),color)
	h.draw_rect(Rect2(center+Vector2(-61,97)*scale,Vector2(122,24)*scale),Color("4a3923"))
	h.draw_rect(Rect2(center+Vector2(-57,97)*scale,Vector2(114,5)*scale),color.lightened(.16))
	text(h,"1",center+Vector2(-14,0)*scale,46*scale,Color("fff1c8"),true)

static func draw(h, width: float, height: float) -> void:
	var race=h.race
	var presentation=race.finish_presentation
	var age: float=presentation.age
	var reveal: float=presentation.reveal()
	var u=minf(width/960.0,height/540.0)
	var origin=Vector2((width-960*u)*.5,(height-540*u)*.5)
	if age<.85:
		var label="冲线！" if race.result=="FINISH" else "比赛结束"
		var banner=Rect2(origin+Vector2(295,155)*u,Vector2(370,100)*u)
		h.panel(banner,Color(.03,.045,.035,smoothstep(0,.15,age)*.8))
		text(h,label,origin+Vector2(373,222)*u,48*u,h.gold if race.result=="FINISH" else h.cream,true)
		return
	h.draw_rect(Rect2(0,0,width,height),Color(.025,.04,.035,reveal*.94))
	var accent=h.gold if presentation.champion else h.cream
	var title="冠军！" if presentation.champion else ("第 %d 名完赛" % race.rank if race.result=="FINISH" else "车辆报废" if race.result=="WRECKED" else "被警方截获")
	if race.tutorial and race.result=="FINISH": title="练习完成"
	text(h,"REDLINE / "+race.track.name,origin+Vector2(66,63)*u,18*u,Color(h.faded,reveal),true)
	h.draw_line(origin+Vector2(66,82)*u,origin+Vector2(894,82)*u,Color(accent,.3*reveal),u)
	if presentation.champion:
		var cup_scale=u*lerpf(.72,1.0,smoothstep(.85,1.7,age))
		trophy(h,origin+Vector2(230,242+24*(1-reveal))*u,cup_scale,Color(h.gold,reveal))
		for i in range(26):
			var t=fmod(age*.14+i*.173,1.0)
			var x=70+fmod(i*127.0,800)+sin(age*1.8+i)*15
			var y=95+t*290
			h.draw_rect(Rect2(origin+Vector2(x,y)*u,Vector2(3+i%3,6+i%4)*u),Color(h.gold,.48*reveal*maxf(0,1-age/10)))
	else:
		var center=origin+Vector2(228,235)*u
		h.draw_circle(center,91*u,Color(accent,.075*reveal))
		h.draw_arc(center,78*u,0,TAU,64,Color(accent,.6*reveal),4*u,true)
		text(h,str(race.rank) if race.result=="FINISH" else "×",center+Vector2(-26,25)*u,78*u,Color(accent,reveal),true)
	text(h,title,origin+Vector2(410,173)*u,48*u,Color(accent,reveal),true)
	text(h,"这条公路属于你。" if presentation.champion else race.message,origin+Vector2(412,213)*u,21*u,Color(h.faded,reveal))
	text(h,"用时  %.2f s" % race.elapsed,origin+Vector2(412,266)*u,24*u,Color(h.cream,reveal),true)
	text(h,"击倒 %d   环境击倒 %d   最长连击 %d" % [race.player.knockouts,race.player.environment_kos,race.player.best_combo],origin+Vector2(412,301)*u,19*u,Color(h.faded,reveal))
	var displayed_reward=int(race.reward*smoothstep(1.2,2.3,age))
	text(h,"奖金  $%d" % displayed_reward,origin+Vector2(412,350)*u,32*u,Color(h.gold,reveal),true)
	text(h,"余额 $%d" % race.career.credits,origin+Vector2(412,380)*u,18*u,Color(h.faded,reveal))
	if presentation.buttons_ready():
		h.button(Rect2(origin+Vector2(66,435)*u,Vector2(398,66)*u),"再赛一局",func():race.menu_action("retry"),true)
		h.button(Rect2(origin+Vector2(486,435)*u,Vector2(408,66)*u),"返回赛事 / 车库",func():race.menu_action("home"))
