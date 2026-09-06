extends RefCounted

static func text(h, value: String, pos: Vector2, size: float, color: Color, strong: bool = false) -> void:
	h.text(value,pos.x,pos.y,int(size),color,strong)

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
		var cup_scale=lerpf(.88,1.0,smoothstep(.85,1.7,age))
		var cup_size=Vector2(355,355)*u*cup_scale
		var cup_center=origin+Vector2(230,248)*u
		h.draw_texture_rect(h.trophy_view.get_texture(),Rect2(cup_center-cup_size*.5,cup_size),false,Color(1,1,1,reveal))
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
