extends SceneTree
func _initialize():
 var bike=load("res://game/bike_state.gd").new()
 bike.distance=100;bike.speed=20
 bike.drive(.1,0,1,0,false,true)
 assert(bike.speed>0 and bike.speed<20,"先刹车")
 for i in range(180):bike.drive(1.0/60,0,1,0,false,true)
 var position=bike.distance
 for i in range(60):bike.drive(1.0/60,0,1,0,false,true)
 assert(bike.distance<position and bike.speed>=-4,"停稳后限速倒车")
 for i in range(60):bike.drive(1.0/60,0,0,0,false)
 assert(bike.speed==0,"松开停止倒车")
 for i in range(60):bike.drive(1.0/60,1,0,0,false)
 assert(bike.speed>0,"油门恢复前进")
 bike.speed=0
 for i in range(60):bike.drive(1.0/60,0,1,0,false)
 assert(bike.speed==0,"触控与自动驾驶刹车不倒车")
 print("REVERSE PASS");quit()
