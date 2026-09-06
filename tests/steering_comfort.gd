extends SceneTree
const Bike=preload("res://game/bike_state.gd")
var checks=0
var failures=0
func check(value: bool,label: String):
	checks+=1
	if value: print("[PASS] "+label)
	else:
		failures+=1
		printerr("FAIL: "+label)
func fresh():
	var bike=Bike.new()
	bike.speed=53
	bike.lane=0
	return bike
func _initialize():
	for hz in [30,60,120]:
		for side in [-1,1]:
			var tap=fresh()
			for i in range(hz/10): tap.drive(1.0/hz,1,0,side,false)
			for i in range(hz/10): tap.drive(1.0/hz,1,0,0,false)
			check(absf(tap.heading_offset)<.1 and absf(tap.lane)<.8,"%d Hz 短按方向不过度摆头（%.1f 度，%.2f m）" % [hz,rad_to_deg(tap.heading_offset),tap.lane])
			check(tap.steering_rate==0,"松手后及时停止继续打方向")
			var nudge=fresh()
			for i in range(hz*4/10): nudge.drive(1.0/hz,1,0,side*.25,false)
			for i in range(hz/10): nudge.drive(1.0/hz,1,0,0,false)
			check(absf(nudge.heading_offset)<.1 and absf(nudge.lane)<1.5,"%d Hz 四分之一摇杆适合微调（%.1f 度，%.2f m）" % [hz,rad_to_deg(nudge.heading_offset),nudge.lane])
			check(nudge.lane*side>.1,"小幅输入仍有明确转向效果")
			var correction=fresh()
			for input in [side,0,-side,0]:
				for i in range(hz/10): correction.drive(1.0/hz,1,0,input,false)
			check(absf(correction.heading_offset)<.02 and absf(correction.lane)<1.5,"短按后反向微调可回正，不来回大幅甩动")
		var slow=fresh()
		var fast=fresh()
		slow.speed=25
		fast.speed=65
		fast.top_speed=65
		for i in range(hz/5):
			slow.drive(1.0/hz,0,0,.25,false)
			fast.drive(1.0/hz,0,0,.25,false)
		check(absf(fast.steering_rate)<absf(slow.steering_rate)*.95,"高速时同幅输入更沉稳")
	print("STEERING_COMFORT_RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
