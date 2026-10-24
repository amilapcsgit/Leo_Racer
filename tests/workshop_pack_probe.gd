extends SceneTree
## Build a tiny replacement tool without exporting or changing the game core.
const ENTRY := "res://tools/vehicle_workshop/workshop.gd"
const PROBE := """extends Control
signal completed(result: Dictionary)
var job: Dictionary={}
func configure(value: Dictionary) -> void:
 job=value
func _ready() -> void:
 print("WORKSHOP_REPLACEMENT_PROBE api=1 offline=true")
"""
func _initialize() -> void:
 var destination:="res://build/customcars/replacement-probe"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--output="):destination=argument.trim_prefix("--output=")
 destination=ProjectSettings.globalize_path(destination)
 if DirAccess.make_dir_recursive_absolute(destination)!=OK:quit(2);return
 var source:=destination.path_join("probe.gd")
 var file:=FileAccess.open(source,FileAccess.WRITE)
 if not file:quit(2);return
 file.store_string(PROBE);file.close()
 var pack:=PCKPacker.new()
 if pack.pck_start(destination.path_join("workshop.pck"))!=OK:quit(2);return
 if pack.add_file(ENTRY,source)!=OK or pack.flush()!=OK:quit(2);return
 print("WORKSHOP_PROBE_PACK_BUILT api=1")
 quit()
