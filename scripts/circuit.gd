class_name LeoCircuit
extends RefCounted

var points: PackedVector3Array
var length: float
var step: float
const WIDTH := 18.0
const GATES := 8
var boosts: Array = []

func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/track.json"))
	length = float(data.length)
	for p in data.points:
		points.append(Vector3(p[0], p[1], p[2]))
	step = length / points.size()
	boosts = data.boosts

func sample(distance: float, lane: float = 0.0) -> Vector3:
	var f := fposmod(distance, length) / step
	var i := int(f)
	var p := points[i].lerp(points[(i + 1) % points.size()], f - i)
	var t := direction(distance)
	return p + Vector3(-t.z, 0, t.x) * lane

func direction(distance: float) -> Vector3:
	var i := int(fposmod(distance, length) / step)
	return (points[(i + 2) % points.size()] - points[(i - 1 + points.size()) % points.size()]).normalized()

func project(p: Vector3, hint: int = -1) -> Dictionary:
	var best := INF
	var best_i := 0
	var best_t := 0.0
	var span := points.size() if hint < 0 else 36
	var start := 0 if hint < 0 else hint - 18
	for j in range(start, start + span):
		var i := posmod(j, points.size())
		var a := points[i]
		var ab := points[(i + 1) % points.size()] - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0, 1)
		var closest := a + ab * t
		var d := Vector2(p.x - closest.x, p.z - closest.z).length_squared()
		if d < best:
			best = d
			best_i = i
			best_t = t
	var s := (best_i + best_t) * step
	var center := sample(s)
	var tangent := direction(s)
	return {"distance": s, "index": best_i, "center": center, "tangent": tangent,
		"offset": (p - center).dot(Vector3(-tangent.z, 0, tangent.x))}

func delta_distance(a: float, b: float) -> float:
	return fposmod(b - a + length * 0.5, length) - length * 0.5
