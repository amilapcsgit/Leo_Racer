class_name LeoArtProfile
extends Resource
## One editable art direction resource; simulation never reads these values.
@export var sun_color := Color("ffdfac")
@export var sun_energy := 1.8
@export var sun_angles := Vector3(-16.0, -145.0, 0.0)
@export var exposure := .80
@export var ambient_energy := .40
@export var sky_top := Color("1e5f74")
@export var sky_horizon := Color("e07a5f")
@export var haze_color := Color("dc864b")
@export var haze_density := .0009
@export var bloom_intensity := .55
@export var cobalt := Color("1d4ed8")
@export var gold := Color("d4af37")
@export var city_palette: PackedColorArray = PackedColorArray([Color("b95046"),Color("137e83"),Color("be8638"),Color("705078"),Color("c9b692"),Color("a43d68")])
@export var camera_boost_peak := 14.0
@export var camera_boost_hold := 9.0
@export var camera_roll_degrees := 5.0
@export var landmark_position := Vector3(-105,.07,-235)
