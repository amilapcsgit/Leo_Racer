@tool
class_name DriverDefinition
extends Resource
@export var id: StringName
@export var display_name := "New driver"
@export_multiline var tagline := "Every racer. Every ride."
@export var standing_model_path := ""
@export var standing_model: PackedScene:
	get:
		return standing_model if standing_model else (LeoAssets.scene(standing_model_path) if not standing_model_path.is_empty() else null)
@export var seated_model_path := ""
@export var seated_model: PackedScene:
	get:
		return seated_model if seated_model else (LeoAssets.scene(seated_model_path) if not seated_model_path.is_empty() else null)
## Pelvis at origin, upright +Y, facing -Z; independent of open-kart orientation.
@export var cabin_model_path := ""
@export var cabin_model: PackedScene:
	get:
		return cabin_model if cabin_model else (LeoAssets.scene(cabin_model_path) if not cabin_model_path.is_empty() else null)
@export var orientation := Transform3D.IDENTITY
@export var portrait: Texture2D
@export var material_name := ""
@export var material_albedo: Texture2D
@export var material_bindings: Dictionary = {}
@export var setup_complete := false
@export_multiline var attribution := ""
