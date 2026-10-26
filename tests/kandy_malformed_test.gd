extends SceneTree
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures.append(message);push_error(message)
func run() -> void:
 var fixture:=ProjectSettings.globalize_path("res://build/kandy/malformed");DirAccess.make_dir_recursive_absolute(fixture)
 if FileAccess.file_exists(fixture.path_join("scenery.pck")):DirAccess.remove_absolute(fixture.path_join("scenery.pck"))
 var installed:=ProjectSettings.globalize_path(LeoTrackDefinition.content_root().path_join("kandy_lake"))
 var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(installed.path_join("manifest.json")))
 var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(installed.path_join("route.json")))
 var cases: Array=[]
 for bad in [{"asset_api":{}},{"asset_api":4},{"core":{"min":{},"max_major":2}},{"core":{"min":"oops","max_major":2}},{"core":{"min":"99.0.0","max_major":2}},{"surface_profile":"unknown"},{"packs":[{"file":{},"sha256":""}]}]:
  var changed:=metadata.duplicate(true);changed.merge(bad,true);cases.append([changed,route])
 var bad:=route.duplicate(true);bad.width=13.;cases.append([metadata,bad])
 for invalid in [{"sky_visual_path":"res://outside.png","sky_lighting_path":"res://outside.exr"},{"sky_visual_path":"res://mods/tracks/kandy_lake/../outside.png","sky_lighting_path":"res://mods/tracks/kandy_lake/light.exr"},{"sky_visual_path":"res://mods/tracks/kandy_lake/sky.png"},{"sky_horizon_offset":"bad"}]:
  var changed:=metadata.duplicate(true);changed.lighting=invalid;cases.append([changed,route])
 var wrong_signage:=metadata.duplicate(true);wrong_signage.authored_signage="yes";cases.append([wrong_signage,route])
 bad=route.duplicate(true);bad.points[10][1]=100.;cases.append([metadata,bad])
 bad=route.duplicate(true);bad.widths=[{}];cases.append([metadata,bad])
 for pair in cases:
  FileAccess.open(fixture.path_join("manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(pair[0]))
  FileAccess.open(fixture.path_join("route.json"),FileAccess.WRITE).store_string(JSON.stringify(pair[1]))
  var track:=LeoTrackDefinition.new();track.folder=fixture;track.read_manifest(fixture.path_join("manifest.json"));check(not track.error.is_empty(),"Malformed definition rejected")
 FileAccess.open(fixture.path_join("manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(metadata));FileAccess.open(fixture.path_join("route.json"),FileAccess.WRITE).store_string(JSON.stringify(route))
 var valid:=LeoTrackDefinition.new();valid.folder=fixture;valid.read_manifest(fixture.path_join("manifest.json"));check(valid.error.is_empty(),"Valid API3 accepted")
 check(not valid.mount() and valid.error.begins_with("Missing track scenery"),"Missing PCK fails clearly")
 FileAccess.open(fixture.path_join("scenery.pck"),FileAccess.WRITE).store_string("damaged")
 check(not valid.mount() and valid.error.begins_with("Damaged track scenery"),"Corrupt PCK fails clearly")
 var report:={"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"errors":failures}
 FileAccess.open("res://build/kandy/malformed-test.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("KANDY_MALFORMED ",JSON.stringify(report));quit(0 if failures.is_empty() else 2)
