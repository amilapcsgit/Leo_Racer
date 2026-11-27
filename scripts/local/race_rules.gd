class_name LeoRaceRules
extends RefCounted
const ID := "distinct_v4+contact_v280_arcade_static"
enum Handling { EASY, ASSISTED, STANDARD }
const HANDLING_NAMES := ["Easy", "Assisted", "Standard"]
const CLASS := "arcade_v2"
static var _balance: Dictionary = {}

static func balance() -> Dictionary:
	if _balance.is_empty():
		_balance = JSON.parse_string(FileAccess.get_file_as_string("res://assets/config/vehicle-balance-v2.json"))
	return _balance

static func resolve(vehicle: VehicleDefinition) -> Dictionary:
	var data := balance()
	var key := String(vehicle.id)
	var profile: Array
	if data.vehicles.has(key):profile = data.vehicles[key]
	else:profile = data.profiles[data.imports.get(key,"compact")]
	return {"max_speed":float(profile[0])/3.6,"boosted_speed":float(profile[1])/3.6,
		"acceleration":float(profile[2]),"handling":float(profile[3]),
		"class_id":CLASS if vehicle.official else "modded",
		"ai_lateral_acceleration":13.5*float(profile[3])}
static func handling_suffix(preset: int) -> String:
	return ["+handling_easy_v1", "+handling_assisted_v1", ""][preset]

static func apply(kart: LeoKart, preset: int = Handling.STANDARD) -> void:
	var rules := resolve(kart.definition)
	var assist := 1.0 - float(preset) / float(Handling.STANDARD)
	var speed_scale := lerpf(1.0, 0.7, assist)
	kart.max_speed = rules.max_speed * speed_scale
	kart.race_boost_ceiling = rules.boosted_speed * speed_scale
	kart.acceleration = rules.acceleration * lerpf(1.0, 0.75, assist)
	kart.handling = rules.handling
	kart.race_ai_lateral_acceleration = rules.ai_lateral_acceleration
	kart.steering_assist = assist
