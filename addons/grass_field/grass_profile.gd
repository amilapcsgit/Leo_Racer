class_name GrassProfile
extends Resource

@export var seed: int = 41
@export_range(0.25, 2.0) var height: float = 0.36
@export var root_color := Color("5b6530")
@export var tip_color := Color("96934b")
@export_range(0.0, 1.0) var wind: float = 0.12
@export_range(24.0, 110.0) var view_distance: float = 90.0
@export_range(24.0, 90.0) var split_distance: float = 66.0
@export_range(0.1, 1.0) var density: float = 0.8
@export_range(0.1, 1.0) var split_density: float = 0.55
@export_range(0.25, 10.0) var recovery_seconds: float = 3.5
