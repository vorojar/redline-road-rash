extends RefCounted

const LABELS = ["流畅", "均衡", "精细"]

static func apply(viewport: Viewport, level: int) -> void:
	viewport.scaling_3d_scale = .75 if level == 0 else 1.0
	viewport.msaa_3d = [Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X][level]

static func apply_sun(sun: DirectionalLight3D, level: int, mobile: bool) -> void:
	sun.shadow_enabled = level > 0
	sun.directional_shadow_max_distance = (45.0 if mobile else 80.0) if level == 1 else 100.0
