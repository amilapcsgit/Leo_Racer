@tool
class_name WheelBinding
extends Resource
## Paths are relative to the imported vehicle root. Axle is in vehicle space.
@export var rotating_groups: Array[NodePath] = []
@export var stationary_groups: Array[NodePath] = []
@export var steering := false
@export var axle := Vector3.RIGHT
@export var pivot := Vector3.ZERO
@export_range(.01, 3.0) var radius := .49
