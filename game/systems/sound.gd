extends Node
const Combat = preload("res://game/systems/combat.gd")
const EngineVoice = preload("res://game/systems/engine_voice.gd")

var engine_voice = EngineVoice.new()
var engine_layers: Dictionary = {}
var was_running: bool = false
var victory_count: int = 0
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
var start_tick_count: int = 0
var start_go_count: int = 0

func _ready() -> void:
	if DisplayServer.get_name() == "headless": return
	effects["start_tick"]=starting_tone(660,.12)
	effects["start_go"]=starting_tone(1046.5,.48)
	var limiter_exists = false
	for index in range(AudioServer.get_bus_effect_count(0)):
		if AudioServer.get_bus_effect(0,index).resource_name=="REDLINE output": limiter_exists=true
	if not limiter_exists and not OS.has_feature("web"):
		var limiter = AudioEffectHardLimiter.new()
		limiter.resource_name = "REDLINE output"
		limiter.pre_gain_db = 7
		limiter.ceiling_db = -1
		AudioServer.add_bus_effect(0,limiter)
	for layer in engine_voice.gains:
		engine_layers[layer] = loop_player("res://assets/audio/engines/ratchet_"+layer+".wav",-80)
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
	effects["engine_pop"] = load("res://assets/audio/engines/ratchet_pop.wav")
	effects["engine_start"] = load("res://assets/audio/engines/ratchet_start.wav")
	effects["victory"] = load("res://assets/audio/engines/victory.wav")
	ui = AudioStreamPlayer.new()
	ui.stream = load("res://assets/audio/menu.wav")
	ui.volume_db = -19
	add_child(ui)

func configure_engine(id: String) -> void:
	engine_voice.configure(id)
	gear = 1
	was_running = false
	for layer in engine_layers:
		var stream: AudioStreamWAV = load("res://assets/audio/engines/"+id+"_"+layer+".wav")
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = stream.data.size()/(4 if stream.stereo else 2)
		engine_layers[layer].stream = stream
		engine_layers[layer].volume_db = -80
		engine_layers[layer].play()
	if not effects.is_empty():
		effects.engine_pop = load("res://assets/audio/engines/"+id+"_pop.wav")
		effects.engine_start = load("res://assets/audio/engines/"+id+"_start.wav")

func celebrate() -> void:
	victory_count+=1
	play_effect("victory",-12,1)
	duck_time = 2.6

static func starting_tone(frequency: float, duration: float) -> AudioStreamWAV:
	var stream=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=44100
	var samples=int(duration*stream.mix_rate)
	var data=PackedByteArray();data.resize(samples*2)
	for i in range(samples):
		var t=float(i)/stream.mix_rate
		var envelope=minf(1,t/.006)*minf(1,(duration-t)/.035)
		var sample=int(11000*envelope*(sin(TAU*frequency*t)+.15*sin(TAU*frequency*2*t)))
		data.encode_s16(i*2,sample)
	stream.data=data
	return stream

func start_signal(go: bool) -> void:
	if go:start_go_count+=1
	else:start_tick_count+=1
	play_effect("start_go" if go else "start_tick",-10 if go else -13,1)

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

func update(speed: float, throttle: float, pursuit: float, racing: bool, volume: float, offroad: bool = false, dt: float = 1.0/60, music_volume: float = .65, corner_load: float = 0, motor_running: bool = false) -> void:
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
	var running: bool = racing or motor_running
	if running and not was_running:
		play_effect("engine_start",-13,1)
		was_running = true
	if engine_voice.update(dt,speed,throttle,gear,running):
		play_effect("engine_pop",-18 if engine_voice.bike_id=="revenant" else -16,1)
	rpm = engine_voice.rpm/engine_voice.spec.idle_rpm
	if engine_layers.is_empty(): return
	AudioServer.set_bus_volume_db(0,linear_to_db(clampf(volume,.0001,1)))
	for layer in engine_layers:
		var voice: AudioStreamPlayer = engine_layers[layer]
		voice.pitch_scale = engine_voice.pitches[layer]
		voice.volume_db = -10+linear_to_db(maxf(.0001,engine_voice.gains[layer]))-(5 if shift_time>0 else 0)
	wind.volume_db = lerpf(-65,-23,clampf(speed/65,0,1)) if racing else -80
	tire.volume_db = (-25 if offroad else lerpf(-44,-23,clampf((corner_load-12)/15,0,1))) if racing and speed>3 else -80
	tire.pitch_scale = .85+speed*.007
	siren.volume_db = lerpf(-60,-18,pursuit) if pursuit>0 and racing else -80
	var music_db = (-17 if running else -15)+linear_to_db(maxf(music_volume,.0001))-(5 if duck_time>0 else 0)
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
