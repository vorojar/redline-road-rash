extends SceneTree
# Metres along the road, heading in radians. Smooth joins preserve usable racing lines.
const PLANS = {
	"pine": [[0,0],[85,0],[210,.95],[350,-.65],[465,-.65],[605,.85],[770,.85],[890,-.75],[1050,-.75],[1190,.8],[1320,.8],[1440,-.95],[1590,-.95],[1740,.7],[1870,.7],[2010,-.85],[2160,-.85],[2310,.8],[2440,.8],[2580,-.7],[2750,-.7],[2890,.35],[3100,.35]],
	"coast": [[0,0],[75,0],[210,-1.05],[330,-1.05],[465,.9],[610,.9],[755,-1.15],[875,-1.15],[1015,.8],[1160,.8],[1310,-.9],[1450,-.9],[1600,1.0],[1740,1.0],[1890,-1.1],[2040,-1.1],[2190,.95],[2350,.95],[2500,-1.05],[2640,-1.05],[2790,.95],[2940,.95],[3090,-.8],[3260,-.8],[3420,.35],[3700,.35]]
}
func long_plan() -> Array:
	return [[0,0],[450,0],[950,.28],[1450,-.18],[1750,-.18],[2100,.85],[2460,-.65],[2820,.42],[3200,.12],[3650,.12],[4100,-.12],[4650,-.12],[5050,.05],[5650,.05],[6100,-.18],[6550,.36],[7100,-.35],[7650,.18],[8100,.18],[8500,0],[8900,-.7],[9300,.7],[9750,-.5],[10200,.35],[10600,.0],[11100,-.22],[11600,0],[12300,0]]

func heading(plan: Array, s: float) -> float:
	for i in range(1,plan.size()):
		if s<=plan[i][0]:
			return lerpf(plan[i-1][1],plan[i][1],smoothstep(plan[i-1][0],plan[i][0],s))
	return plan[-1][1]
func elevation(s: float, coast: bool) -> float:
	return (24 if coast else 0)+sin(s/165)*8+sin(s/390)*15+sin(s/78)*1.4
func _initialize() -> void:
	for route_name in ["pine", "coast", "interstate"]:
		var c = Curve3D.new()
		c.bake_interval = .75
		var plan: Array = long_plan() if route_name=="interstate" else PLANS[route_name]
		var p = Vector3(0,elevation(0,route_name=="coast"),0)
		var count = 620 if route_name=="interstate" else 160 if route_name=="pine" else 195
		for i in range(count):
			var s = i*20.0
			if i>0:
				var a = heading(plan,s-10)
				p += Vector3(-sin(a),0,-cos(a))*20
			p.y = elevation(s,route_name=="coast")
			var angle = heading(plan,s)
			var rise = (elevation(s+1,route_name=="coast")-elevation(s-1,route_name=="coast"))/2
			var h = Vector3(-sin(angle),rise,-cos(angle))*20/3
			c.add_point(p,-h,h)
		ResourceSaver.save(c,"res://data/tracks/"+route_name+".tres")
		var path = Path3D.new()
		path.name = "EditableRoadSpline"
		path.curve = c
		var scene = PackedScene.new()
		scene.pack(path)
		ResourceSaver.save(scene,"res://data/tracks/"+route_name+"_editor.tscn")
		print(route_name," length=",c.get_baked_length())
		path.free()
	quit()
