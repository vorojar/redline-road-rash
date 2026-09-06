extends RefCounted
const Combat=preload("res://game/systems/combat.gd")
# Wrist and blade direction are authored together. The club stays in the right
# hand; a left-side target is reached with a backhand instead of swapping hands.
static func sample(shoulder: Vector3, side: float, age: float, active: bool) -> Dictionary:
	var ready = shoulder+Vector3(.11,-.22,-.08)
	var rest_axis = Vector3(.32,.88,.25).normalized()
	if not active: return {"hand":ready,"axis":rest_axis}
	var impact: float=Combat.DELAYS[2]
	var load = smoothstep(0,impact*.52,age)
	var hit = smoothstep(impact*.52,impact,age)
	var follow = smoothstep(impact,impact+.16,age)
	var settle = smoothstep(impact+.18,impact+Combat.RECOVERY,age)
	var chamber = shoulder+(Vector3(.10,.08,.19) if side>0 else Vector3(.15,.03,-.15))
	var contact = shoulder+(Vector3(.47,-.04,-.18) if side>0 else Vector3(-.36,-.02,-.35))
	var exit_hand = shoulder+(Vector3(.26,-.20,-.37) if side>0 else Vector3(-.28,-.17,-.34))
	var load_axis = Vector3(.15,.86,.49).normalized() if side>0 else Vector3(.82,.53,-.20).normalized()
	var hit_axis = Vector3(.98,-.06,-.16).normalized() if side>0 else Vector3(-.96,-.08,-.24).normalized()
	var follow_axis = Vector3(.50,-.24,-.83).normalized() if side>0 else Vector3(-.72,-.38,.20).normalized()
	var hand = ready.lerp(chamber,load).lerp(contact,hit).lerp(exit_hand,follow).lerp(ready,settle)
	var axis = rest_axis.slerp(load_axis,load).slerp(hit_axis,hit).slerp(follow_axis,follow).slerp(rest_axis,settle).normalized()
	return {"hand":hand,"axis":axis}
