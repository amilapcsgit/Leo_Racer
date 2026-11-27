extends RefCounted

const SIDE := 128
const STEP := 0.5
const MAX_SWEEP := 24.0
const INTERVAL := 0.05
var origin := Vector2i.ZERO
var texture: ImageTexture
var pixels := PackedByteArray()
var stamps: Dictionary[Vector2i, Vector4] = {}
var last_eye := Vector2.INF

func _init() -> void:
	pixels.resize(SIDE * SIDE * 4)
	texture = ImageTexture.create_from_image(Image.create_from_data(SIDE, SIDE, false, Image.FORMAT_RGBA8, pixels))

func update(eye: Vector2, segments: Array, now: float, recovery: float) -> void:
	if eye.distance_to(last_eye) > SIDE * STEP * 0.5:
		stamps.clear()
	last_eye = eye
	origin = Vector2i((eye / STEP).floor()) - Vector2i.ONE * (SIDE / 2)
	for segment in segments:
		stamp(segment, now)
	pixels.fill(0)
	for cell: Vector2i in stamps.keys():
		var local := cell - origin
		var entry := stamps[cell]
		var strength := entry.z * (1.0 - (now - entry.w) / recovery)
		if strength <= 0.0 or not Rect2i(0, 0, SIDE, SIDE).has_point(local):
			stamps.erase(cell)
			continue
		var index := (local.y * SIDE + local.x) * 4
		pixels[index] = int((entry.x * 0.5 + 0.5) * 255.0)
		pixels[index + 1] = int((entry.y * 0.5 + 0.5) * 255.0)
		pixels[index + 2] = int(strength * 255.0)
	texture.update(Image.create_from_data(SIDE, SIDE, false, Image.FORMAT_RGBA8, pixels))

func stamp(segment: Array, now: float) -> void:
	var a: Vector2 = segment[0]
	var b: Vector2 = segment[1]
	var radius: float = segment[2]
	var strength: float = segment[3]
	if a.distance_to(b) > MAX_SWEEP:
		a = b
	var area := Rect2(a, Vector2.ZERO).expand(b).grow(radius)
	var cells := Rect2i(Vector2i((area.position / STEP).floor()), Vector2i((area.size / STEP).ceil()) + Vector2i.ONE)
	cells = cells.intersection(Rect2i(origin, Vector2i.ONE * SIDE))
	var motion := (b - a).normalized()
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			var cell := Vector2i(x, y)
			var point := (Vector2(cell) + Vector2.ONE * 0.5) * STEP
			var closest := Geometry2D.get_closest_point_to_segment(point, a, b) if a != b else a
			var offset := point - closest
			var weight := strength * (1.0 - offset.length() / radius)
			if weight > 0.0:
				var direction := motion if motion != Vector2.ZERO else offset.normalized()
				stamps[cell] = Vector4(direction.x, direction.y, weight, now)
