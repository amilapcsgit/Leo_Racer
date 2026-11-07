extends RefCounted
## Preference is saved separately from the immutable grid for the current race.
const SECTION := "game"
const KEY := "allow_ai_bigster"
const EMPTY_ROSTER := "No eligible AI cars. Install a default car in Content or enable Bigster in Settings → Game Logic."
var active_allow_ai_bigster := false
var active_ai: Dictionary = {}

static func read_preference(config: ConfigFile) -> bool:
	var value: Variant=config.get_value(SECTION,KEY,false)
	return value if value is bool else false

static func write_preference(config: ConfigFile, allow: bool) -> void:
	config.set_value(SECTION,KEY,allow)

func prepare(catalog: GarageCatalog, humans: int, seed: int, allow_bigster: bool=false) -> String:
	var pool:=LeoDefaultRoster.ai_vehicles(catalog,allow_bigster)
	if pool.is_empty():return EMPTY_ROSTER
	var planned: Dictionary={}
	for slot in range(clampi(humans,1,2),6):planned[slot]=pool[posmod(seed+slot*3,pool.size())]
	# Commit only after validation. A failed restart leaves its old grid intact.
	active_allow_ai_bigster=allow_bigster;active_ai=planned
	return ""

func vehicle(slot: int) -> VehicleDefinition:
	return active_ai.get(slot) as VehicleDefinition
