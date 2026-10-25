class_name LeoCircuit
extends RefCounted

var elevated := false
var definition: LeoTrackDefinition
var widths: Array = []
var bounds := AABB()
var _cells: Dictionary = {}
var points: PackedVector3Array
var length: float
var step: float
const WIDTH := 18.0
const GATES := 8
var boosts: Array = []
var sectors: Array = []
var features: Dictionary = {}

func _init(track: LeoTrackDefinition = null) -> void:
	definition=track
	elevated=track.elevated() if track else false
	var data: Dictionary
	if track:data=track.route
	else:data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/track-astra.json"))
	length=float(data.length)
	for p in data.points:points.append(Vector3(p[0],p[1],p[2]))
	step=length/points.size();boosts=data.get("boosts",[]);sectors=data.get("sectors",[]);features=data.get("features",{})
	widths=data.get("widths",[])
	if widths.size()!=points.size():widths.resize(points.size());widths.fill(float(data.get("width",18.)))
	bounds=AABB(points[0],Vector3.ZERO)
	for i in points.size():
		bounds=bounds.expand(points[i])
		var a:=Vector2(points[i].x,points[i].z)
		var next:=points[(i+1)%points.size()]
		var b:=Vector2(next.x,next.z)
		var low:Vector2i=Vector2i((a.min(b)/64.).floor());var high:Vector2i=Vector2i((a.max(b)/64.).floor())
		for x in range(low.x,high.x+1):
			for y in range(low.y,high.y+1):
				var key:=Vector2i(x,y)
				if not _cells.has(key):_cells[key]=[]
				_cells[key].append(i)

func width_at(distance: float) -> float:
	var f:=fposmod(distance,length)/step;var i:=int(f)
	return lerpf(float(widths[i]),float(widths[(i+1)%points.size()]),f-i)

func sector_name(distance: float) -> String:
	var fraction := fposmod(distance,length)/length
	var label := "LOTUS COAST"
	for sector in sectors:
		if fraction >= float(sector.fraction): label = sector.name
	return label

func sample(distance: float, lane: float = 0.0) -> Vector3:
	var f := fposmod(distance, length) / step
	var i := int(f)
	var p := points[i].lerp(points[(i + 1) % points.size()], f - i)
	var t := direction(distance)
	var side:=Vector3(-t.z,0,t.x)
	return p + (side.normalized() if elevated else side) * lane

func direction(distance: float) -> Vector3:
	var i := int(fposmod(distance, length) / step)
	return (points[(i + 2) % points.size()] - points[(i - 1 + points.size()) % points.size()]).normalized()

func project(p: Vector3, hint: int = -1) -> Dictionary:
	var best := INF
	var best_i := 0
	var best_t := 0.0
	var candidates: Array=[]
	if hint>=0:
		for j in range(hint-18,hint+18):candidates.append(posmod(j,points.size()))
	else:
		var key:=Vector2i(floori(p.x/64.),floori(p.z/64.))
		for x in range(-1,2):
			for y in range(-1,2):candidates.append_array(_cells.get(key+Vector2i(x,y),[]))
		if candidates.is_empty():candidates=range(points.size())
	for i in candidates:
		var a := points[i]
		var ab := points[(i + 1) % points.size()] - a
		var planar:=Vector2(ab.x,ab.z)
		var t := clampf(Vector2(p.x-a.x,p.z-a.z).dot(planar)/planar.length_squared() if elevated else (p-a).dot(ab)/ab.length_squared(),0,1)
		var closest := a + ab * t
		var d := Vector2(p.x - closest.x, p.z - closest.z).length_squared()
		if d < best:
			best = d
			best_i = i
			best_t = t
	if hint>=0 and best>1600.:return project(p,-1)
	var s := (best_i + best_t) * step
	var center := sample(s)
	var tangent := direction(s)
	return {"distance": s, "index": best_i, "center": center, "tangent": tangent,
		"offset": (p - center).dot(Vector3(-tangent.z, 0, tangent.x))}

func delta_distance(a: float, b: float) -> float:
	return fposmod(b - a + length * 0.5, length) - length * 0.5

func frame_at(distance: float, yaw: float = NAN) -> Basis:
	var forward:=direction(distance)
	var side:=Vector3(-forward.z,0,forward.x).normalized()
	var up:=side.cross(forward).normalized()
	if not is_nan(yaw):forward=Vector3(-sin(yaw),0,-cos(yaw)).slide(up).normalized()
	return Basis(forward.cross(up).normalized(),up,-forward)
