@tool
class_name DriverDefinition
extends Resource
@export var id: StringName
@export var display_name := "New driver"
@export_multiline var tagline := "Every racer. Every ride."
@export var standing_model: PackedScene
@export var seated_model: PackedScene
## Pelvis at origin, upright +Y, facing -Z; independent of open-kart orientation.
@export var cabin_model: PackedScene
@export var orientation := Transform3D.IDENTITY
@export var portrait: Texture2D
@export var material_name := ""
@export var material_albedo: Texture2D
@export var material_bindings: Dictionary = {}
@export var setup_complete := false
@export_multiline var attribution := ""
