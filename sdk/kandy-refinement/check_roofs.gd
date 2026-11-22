extends SceneTree
## Audit the delivered packed scenes, including authored roofs on both landmarks.
func _initialize():
 var track:=OS.get_cmdline_user_args()[0]
 var manifest=JSON.parse_string(FileAccess.get_file_as_string(track.path_join("manifest.json")))
 for pack in manifest.packs:
  if not ProjectSettings.load_resource_pack(track.path_join(pack.file)):
   quit(1)
   return
 var cells=JSON.parse_string(FileAccess.get_file_as_string(track.path_join("cells.json")))
 var buildings:=0
 var duplicates:=0
 var landmarks:=0
 for cell in cells.cells:
  if not "/ceylon/" in cell.scene:continue
  var scene: Node=load(cell.scene).instantiate()
  for building in scene.get_children():
   if building.find_child("module_34",true,false) or building.find_child("module_48",true,false):
    buildings+=1
    if scene.has_node("Roof_"+str(building.name)):duplicates+=1
   if building.name=="Queens_Hotel" and building.has_node("Hotel_Main_Roof"):landmarks+=1
   if building.name=="Temple_of_the_Tooth":landmarks+=1
  scene.free()
 print("KANDY_ROOF_AUDIT buildings=",buildings," duplicates=",duplicates," landmarks=",landmarks)
 quit(0 if buildings>=102 and duplicates==0 and landmarks==2 else 1)
