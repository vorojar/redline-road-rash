extends Node
const Combat = preload("res://game/systems/combat.gd")

var engine: AudioStreamPlayer
var idle: AudioStreamPlayer
var music: AudioStreamPlayer
var wind: AudioStreamPlayer
var tire: AudioStreamPlayer
var siren: AudioStreamPlayer
var ui: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var effects: Dictionary = {}
var voice_index: int = 0
var variation: int = 0
var gear: int = 1
var shift_time: float = 0
var duck_time: float = 0
var rpm: float = .8

func _ready() -> void:
	if DisplayServer.get_name() == "headless": return
	var limiter_exists = false
	for index in range(AudioServer.get_bus_effect_count(0)):
		if AudioServer.get_bus_effect(0,index).resource_name=="REDLINE output": limiter_exists=true
	if not limiter_exists and not OS.has_feature("web"):
		var limiter = AudioEffectHardLimiter.new()
		limiter.resource_name = "REDLINE output"
		limiter.pre_gain_db = 7
		limiter.ceiling_db = -1
		AudioServer.add_bus_effect(0,limiter)
	engine = loop_player("res://assets/audio/engine.wav",-80)
	idle = loop_player("res://assets/audio/engine_idle.wav",-80)
	music = loop_player("res://assets/audio/roadway.ogg",-24)
	wind = loop_player("res://assets/audio/wind.wav",-80)
	tire = loop_player("res://assets/audio/tire.wav",-80)
	siren = loop_player("res://assets/audio/siren.wav",-80)
	for name in ["hit_0","hit_1","hit_2","wood_0","wood_1","wood_2","metal_0","metal_1","metal_2","swing","crash","shift"]:
		effects[name] = load("res://assets/audio/"+name+".wav")
	for i in range(6):
		var voice = AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	ui = AudioStreamPlayer.new()
	ui.stream = load("res://assets/audio/menu.wav")
	ui.volume_db = -19
	add_child(ui)

func loop_player(path: String, volume: float) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	var stream: AudioStream = load(path)
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = stream.data.size()/(4 if stream.stereo else 2)
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	player.play()
	return player

func update(speed: float, throttle: float, pursuit: float, racing: bool, volume: float, offroad: bool = false, dt: float = 1.0/60, music_volume: float = .65, corner_load: float = 0) -> void:
	var next_gear = gear
	if speed>gear*13.0+2 and gear<5: next_gear += 1
	elif speed<(gear-1)*13.0-2 and gear>1: next_gear -= 1
	if speed<2: next_gear = 1
	if next_gear!=gear:
		if racing and speed>8:
			shift_time = .16
			play_effect("shift",-18,1)
		gear = next_gear
	shift_time = maxf(0,shift_time-dt)
	duck_time = maxf(0,duck_time-dt)
	var ratio: float = [2.9,2.05,1.55,1.24,1.0][gear-1]
	var target_rpm = clampf(.70+speed*ratio*.017+throttle*.10,.75,1.95)
	rpm = lerpf(rpm,target_rpm,minf(dt*13,1))
	if engine == null: return
	AudioServer.set_bus_volume_db(0,linear_to_db(clampf(volume,.0001,1))+(5 if OS.has_feature("web") else 0))
	engine.pitch_scale = rpm
	var load_gain = smoothstep(0,18,speed)*lerpf(.48,1,throttle)
	engine.volume_db = -13+linear_to_db(maxf(.0001,load_gain))-(7 if shift_time>0 else 0) if racing else -80
	idle.pitch_scale = lerpf(.92,1.20,clampf(speed/20,0,1))
	idle.volume_db = -20+linear_to_db(maxf(.0001,1-load_gain*.8)) if racing else -80
	wind.volume_db = lerpf(-65,-23,clampf(speed/65,0,1)) if racing else -80
	tire.volume_db = (-25 if offroad else lerpf(-44,-23,clampf((corner_load-12)/15,0,1))) if racing and speed>3 else -80
	tire.pitch_scale = .85+speed*.007
	siren.volume_db = lerpf(-60,-18,pursuit) if pursuit>0 and racing else -80
	var music_db = (-10 if racing else -12)+linear_to_db(maxf(music_volume,.0001))-(5 if duck_time>0 else 0)
	music.volume_db = lerpf(music.volume_db,music_db,minf(dt*5,1))

func play_effect(name: String, db: float, pitch: float) -> void:
	if voices.is_empty(): return
	var voice = voices[voice_index%voices.size()]
	voice_index += 1
	voice.stream = effects[name]
	voice.volume_db = db
	voice.pitch_scale = pitch
	voice.play()

func swing(kind: int) -> void:
	play_effect("swing",-21 if kind==0 else -16,1.2 if kind==0 else .9)

func hit(crash: bool = false, kind: int = 0, weapon: int = 0, intensity: float = 1.0) -> void:
	if crash:
		play_effect("crash",-8,1)
		duck_time = .65
	else:
		var group = ("wood" if weapon==1 else "metal") if kind==2 and weapon>0 else "hit"
		var impact: Dictionary = Combat.IMPACTS[kind]
		play_effect(group+"_"+str(variation%3),impact.db+linear_to_db(intensity),impact.pitch+(variation%3)*.035)
		variation += 1
		duck_time = [.10,.18,.28][kind]*intensity

func click() -> void:
	if ui != null: ui.play()

func stop_all() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null

func _exit_tree() -> void: stop_all()
