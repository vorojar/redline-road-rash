extends RefCounted
var stages: Array = []
var index: int = -1
var repair_time: float = 0
var serviced: Array[int] = []
var visited: Array[int] = []

func configure(track: Dictionary) -> void:
	stages = track.get("stages",[])
	index = -1
	repair_time = 0
	serviced.clear()
	visited.clear()

func section_at(distance: float) -> Dictionary:
	if stages.is_empty(): return {}
	var section: Dictionary = stages[0]
	for next in stages:
		if next.start>distance: break
		section = next
	return section

func pressure() -> float:
	return stages[index].pressure if index>=0 else 1.0

func update(race: Node3D, dt: float) -> void:
	if stages.is_empty() or race.tutorial: return
	var next_index = 0
	for i in range(stages.size()):
		if race.player.distance>=stages[i].start: next_index=i
	if index!=next_index:
		index=next_index
		visited.append(index)
		repair_time=0
		var stage: Dictionary=stages[index]
		race.notify(stage.name+(" · 靠右停车 2 秒维修补给" if stage.kind=="service" else ""),4)
		if stage.heat_floor>0: race.heat=maxf(race.heat,stage.heat_floor)
		if stage.kind=="service":
			race.heat=0
			race.police.active=false
			race.police.support_active=false
			race.police.roadblock=false
	if stages[index].kind=="service" and index not in serviced:
		var p=race.player
		var in_bay: bool=p.distance<stages[index].start+450 and p.lane>5.8 and p.lane<7.4 and p.speed<2 and p.crash_timer<=0
		repair_time=repair_time+dt if in_bay else 0.0
		if repair_time>=2:
			p.health=minf(100,p.health+40)
			p.durability=minf(p.max_durability,p.durability+35)
			serviced.append(index)
			race.notify("维修完成 · 体力 +40 / 车况 +35",3)
