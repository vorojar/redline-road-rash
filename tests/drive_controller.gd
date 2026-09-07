extends RefCounted
static func steer(bike, target_lane: float) -> float:
	if absf(bike.curve_force)>.00015:
		var inward=-signf(bike.curve_force)
		var error=(target_lane-bike.lane)*inward
		if error<-.35: return -inward*.25
		if bike.bend_direction!=0:
			var target=(target_lane-bike.bend_lane)*inward/.6
			if target>1.1 and error>.4 and (bike.lane-bike.bend_lane)*inward>.45: return 0.0 # Release then press again for another deliberate adjustment.
			return inward*clampf(target,.11,1)
		return inward*clampf(error/.6,.11,1)
	var desired_heading = -clampf((target_lane-bike.lane)*.12,-.35,.35)
	var desired_rate = bike.heading_offset*bike.HEADING_RETURN+(desired_heading-bike.heading_offset)*6
	var normalized = clampf(-desired_rate/maxf(.1,bike.turn_rate()),-1,1)
	return signf(normalized)*pow(absf(normalized),1.0/bike.STEERING_EXPONENT)
