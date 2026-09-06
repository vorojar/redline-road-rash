extends RefCounted

const CHARGE_SECONDS: float = 1.0
const BURST_SECONDS: float = 2.2
const COOLDOWN_SECONDS: float = 8.0
var charge: float = 0.0
var remaining: float = 0.0
var cooldown: float = 0.0
var charging: bool = false
var previous_held: bool = false
var activations: int = 0

func update(dt: float, held: bool, eligible: bool) -> bool:
	cooldown = maxf(0,cooldown-dt)
	if remaining>0:
		remaining = maxf(0,remaining-dt) if eligible else 0.0
		if remaining<=0: cooldown = COOLDOWN_SECONDS
	var pressed = held and not previous_held
	var released = not held and previous_held
	if pressed and eligible and cooldown<=0 and remaining<=0:
		charging = true
		charge = 0
	if charging:
		if not eligible:
			charging = false
			charge = 0
		elif held:
			charge = minf(CHARGE_SECONDS,charge+dt)
		elif released:
			if charge>=CHARGE_SECONDS-.0001:
				remaining = BURST_SECONDS
				activations += 1
			charging = false
			charge = 0
	previous_held = held
	return remaining>0

func meter() -> float:
	if remaining>0: return remaining/BURST_SECONDS*100
	if cooldown>0: return (1-cooldown/COOLDOWN_SECONDS)*100
	if charging: return charge/CHARGE_SECONDS*100
	return 100

func label() -> String:
	if remaining>0: return "冲刺 %.1f s" % remaining
	if cooldown>0: return "恢复 %.1f s" % cooldown
	if charging: return "蓄满 · 松开冲刺" if charge>=CHARGE_SECONDS-.0001 else "蓄力 %d%%" % int(meter())
	return "松开后重新蓄力" if previous_held else "SHIFT 按住蓄力 / 松开冲刺"
