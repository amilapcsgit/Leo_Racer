class_name LeoRaceRules
extends RefCounted
const ID := "balanced_v1"
static func resolve(vehicle: VehicleDefinition) -> Dictionary:
 var bigster:=vehicle.id==&"bigster"
 return {"max_speed":50. if bigster else 165./3.6,"boosted_speed":62.5 if bigster else 55.,"acceleration":18.,"handling":1.,"class_id":"suv180" if bigster else "standard165","ai_lateral_acceleration":13.5}
static func apply(kart: LeoKart) -> void:
 var rules:=resolve(kart.definition)
 kart.max_speed=rules.max_speed;kart.acceleration=rules.acceleration;kart.handling=rules.handling;kart.race_boost_ceiling=rules.boosted_speed;kart.race_ai_lateral_acceleration=rules.ai_lateral_acceleration
