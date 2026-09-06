extends RefCounted
const VOICES = preload("res://data/engine_voices.json")
var spec: Dictionary = VOICES.data.ratchet
var bike_id: String = "ratchet"
var rpm: float = 1100
var load: float = 0
var previous_throttle: float = 0
var pop_cooldown: float = 0
var overrun: float = 0
var gains: Dictionary = {"idle":0.0,"low":0.0,"high":0.0,"coast":0.0}
var pitches: Dictionary = {"idle":1.0,"low":1.0,"high":1.0,"coast":1.0}
var pops: int = 0

func configure(id: String) -> void:
	bike_id = id
	spec = VOICES.data[id]
	rpm = spec.idle_rpm
	load = 0
	previous_throttle = 0
	pop_cooldown = 0
	overrun = 0
	for layer in gains: gains[layer]=0.0

func update(dt: float, speed: float, throttle: float, gear: int, active: bool) -> bool:
	pop_cooldown = maxf(0,pop_cooldown-dt)
	overrun = maxf(0,overrun-dt)
	var pop = active and previous_throttle>.55 and throttle<.15 and rpm>spec.redline*.35 and pop_cooldown<=0
	if pop:
		pop_cooldown = 1.6
		overrun = 1.0
		pops+=1
	previous_throttle = throttle if active else 0.0
	load = move_toward(load,throttle if active else 0.0,dt*4)
	var ratio: float = [3.4,2.5,1.9,1.5,1.2][gear-1]
	var road_rpm: float = spec.idle_rpm+speed*ratio*(spec.redline-spec.idle_rpm)/85.0
	var free_rev: float = lerpf(spec.idle_rpm,spec.redline*.48,load)*clampf(1-speed/5,0,1)
	var target: float = clampf(maxf(road_rpm,free_rev),spec.idle_rpm,spec.redline*.97)
	rpm = move_toward(rpm,target,dt*spec.redline*(1.4 if target>rpm else .6))
	var rev: float = clampf((rpm-spec.idle_rpm)/(spec.redline-spec.idle_rpm),0,1)
	var idle_mix: float = 1-smoothstep(.015,.17,rev)
	var high_mix: float = smoothstep(.28,.7,rev)
	var coast_mix: float = (1-smoothstep(.05,.25,load))*smoothstep(.08,.32,rev)
	var active_gain = 1.0 if active else 0.0
	var targets = {
		"idle":idle_mix*.7,
		"low":(1-idle_mix)*(1-high_mix)*(1-coast_mix)*lerpf(.38,.9,load),
		"high":(1-idle_mix)*high_mix*(1-coast_mix)*lerpf(.4,1,load),
		"coast":(1-idle_mix)*coast_mix*.7
	}
	for layer in gains:
		gains[layer] = lerpf(gains[layer],targets[layer]*active_gain,1-exp(-dt*10))
	pitches.idle = clampf(rpm/spec.idle_rpm,.75,1.55)
	pitches.low = clampf(rpm/(spec.redline*.35),.55,1.8)
	pitches.high = clampf(rpm/(spec.redline*.72),.6,1.4)
	pitches.coast = clampf(rpm/(spec.redline*.5),.55,1.75)
	return pop
