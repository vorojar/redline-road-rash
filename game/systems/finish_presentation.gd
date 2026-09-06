extends RefCounted
var active: bool = false
var age: float = 0
var champion: bool = false
var result: String = ""
var start_distance: float = 0
var distance: float = 0
var speed: float = 0
var celebrated: bool = false

func begin(outcome: String, winner: bool, position: float, velocity: float) -> void:
	active = true
	age = 0
	result = outcome
	champion = winner and outcome=="FINISH"
	start_distance = position
	distance = position
	speed = minf(24,velocity) if outcome=="FINISH" else 0.0
	celebrated = false

func update(dt: float) -> bool:
	if not active: return false
	age += dt
	speed = move_toward(speed,0,dt*14)
	distance = minf(start_distance+26,distance+speed*dt)
	if champion and age>=.85 and not celebrated:
		celebrated = true
		return true
	return false

func buttons_ready() -> bool:
	return active and age>=(2.6 if result=="FINISH" else 1.6)

func reveal() -> float:
	return smoothstep(.65,1.35,age)
