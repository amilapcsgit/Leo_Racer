class_name LeoRaceRules
extends RefCounted
const ID := "balanced_v1"
static func resolve(vehicle: VehicleDefinition) -> Dictionary:
 if not vehicle.official:
  return {"max_speed":vehicle.max_speed,"boosted_speed":vehicle.boosted_speed if vehicle.boosted_speed>0 else vehicle.max_speed*1.2,"acceleration":vehicle.acceleration,"handling":vehicle.handling,"class_id":"modded","ai_lateral_acceleration":vehicle.ai_lateral_acceleration if vehicle.ai_lateral_acceleration>0 else 13.5}
 var bigster:=vehicle.id==&"bigster"
 return {"max_speed":50. if bigster else 165./3.6,"boosted_speed":62.5 if bigster else 55.,"acceleration":18.,"handling":1.,"class_id":"suv180" if bigster else "standard165","ai_lateral_acceleration":13.5}
static func apply(kart: LeoKart) -> void:
 var rules:=resolve(kart.definition)
 kart.max_speed=rules.max_speed;kart.acceleration=rules.acceleration;kart.handling=rules.handling;kart.race_boost_ceiling=rules.boosted_speed;kart.race_ai_lateral_acceleration=rules.ai_lateral_acceleration
