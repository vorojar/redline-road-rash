extends RefCounted
static func steer(bike, target_lane: float) -> float:
	var desired_heading = -clampf((target_lane-bike.lane)*.12,-.35,.35)
	var desired_rate = bike.heading_offset*bike.HEADING_RETURN+(desired_heading-bike.heading_offset)*6
	var normalized = clampf(-desired_rate/maxf(.1,bike.turn_rate()),-1,1)
	return signf(normalized)*pow(absf(normalized),1.0/bike.STEERING_EXPONENT)
