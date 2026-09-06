@tool
extends Path3D

@export var rebuild_preview: bool = false:
	set(value):
		if value and is_inside_tree():
			queue_redraw_preview()
		rebuild_preview = false

func queue_redraw_preview() -> void:
	# Native Godot Path3D control handles are the spline editor.
	if curve != null:
		curve.bake_interval = 1.0

func point(distance: float, lane: float = 0) -> Vector3:
	var length = curve.get_baked_length()
	var s = clampf(distance, 0, length)
	var p = curve.sample_baked(s, true)
	var direction = tangent(s)
	if distance < 0:
		p += direction * distance
	elif distance > length:
		p += direction * (distance - length)
	var right = Vector3(-direction.z, 0, direction.x).normalized()
	return p + right * lane

func tangent(s: float) -> Vector3:
	var length = curve.get_baked_length()
	s = clampf(s,0,length)
	return (curve.sample_baked(clampf(s + 0.5, 0, length), true) - curve.sample_baked(clampf(s - 0.5, 0, length), true)).normalized()

func yaw(s: float) -> float:
	var t = tangent(s)
	return atan2(-t.x, -t.z)

func slope(s: float) -> float:
	return asin(tangent(s).y)

func curvature(s: float) -> float:
	return wrapf(yaw(s + 3) - yaw(s - 3), -PI, PI) / 6.0
