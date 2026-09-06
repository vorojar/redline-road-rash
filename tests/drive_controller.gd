extends RefCounted
static func steer(bike, target_lane: float) -> float:
	var desired_heading = -clampf((target_lane-bike.lane)*.12,-.35,.35)
	var desired_rate = bike.curve_force*bike.speed+(desired_heading-bike.heading_offset)*6
	return clampf(-desired_rate/maxf(.1,bike.turn_rate()),-1,1)
