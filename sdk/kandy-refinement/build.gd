extends SceneTree
const Baker=preload("res://resource_baker.gd")
const Dress=preload("res://kandy_scenery.gd")
const Batches=preload("res://static_scenery_batcher.gd")
const PREFIX="res://mods/tracks/kandy_lake/ceylon/"
const TEMPLE_CELL="cell_-1_-2"
var source: String
var stage: String
var dress=Dress.new()
var cells: Dictionary
var manifest: Dictionary
var authored: Node3D
var baker
var changed:=0

func _initialize():
 run.call_deferred()

func read(path: String) -> Dictionary:
 return JSON.parse_string(FileAccess.get_file_as_string(path))

func write(path: String, data: Dictionary):
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(data,"  ")+"\n")

func own_generated(n: Node, owner_node: Node):
 for c in n.get_children():
  c.owner=owner_node
  if c.scene_file_path.is_empty():own_generated(c,owner_node)

func upgrade_groups(cell: Node3D) -> Array:
 var result: Array=[]
 for child in cell.get_children():
  if child.name.begins_with("Roof_") or child.name.begins_with("Landu_Kelae_") or child.name in ["Temple_of_the_Tooth","Queens_Hotel","Walakulu_Bemma_and_paving"]:
   result.append(child)
 return result

func apply_group(cell: Node3D, group: Node3D):
 var baked: Node3D=baker.flatten(group)
 cell.add_child(baked)
 Batches.bake(baked)

func run():
 var args:=OS.get_cmdline_user_args()
 source=args[0]
 stage=args[1]
 manifest=read(source.path_join("manifest.json"))
 cells=read(source.path_join("cells.json"))
 assert(int(manifest.course_revision)==2)
 for entry in manifest.packs:
  if not ProjectSettings.load_resource_pack(source.path_join(entry.file),false):
   printerr("Cannot mount baseline ",entry.file)
   quit(2)
   return
 dress.setup(read(source.path_join("route.json")),read(source.path_join("geography.json")))
 DirAccess.make_dir_recursive_absolute(stage)
 baker=Baker.new(stage.path_join("scratch"),PREFIX)
 var scene_path:="res://kandy_scenery_28.tscn"
 for arg in args:
  if arg.begins_with("--scene="):scene_path=arg.trim_prefix("--scene=")
 var rebuild:="--generate" in args
 if rebuild:
  authored=Node3D.new()
  authored.name="KandyScenery"
 else:
  authored=load(scene_path).instantiate()
 root.add_child(authored)
 var resident: Node3D=load(manifest.scene).instantiate()
 root.add_child(resident)
 if rebuild:
  var patch:=dress.scenery_group(authored,"Resident")
  dress.shore(patch,resident)
 for node in resident.get_children():
  if dress.old_wall(node):node.free()
 var resident_patch: Node3D=authored.get_node("Resident")
 for group in upgrade_groups(resident_patch):
  apply_group(resident,group)
 manifest.scene=baker.pack(resident,"resident")
 resident.free()
 for cell in cells.cells:
  var xz:=Vector2(cell.center[0],cell.center[1])
  if xz.length()>950.:continue
  var name: String=cell.id
  var stock: Node3D=load(cell.scene).instantiate()
  root.add_child(stock)
  var patch: Node3D
  if rebuild:
   dress.town(stock,name)
   dress.vegetation(stock,false)
   if name==TEMPLE_CELL:
    var old: Node3D=stock.get_node("KandyPrecinct_tooth_temple")
    dress.temple(stock,old.transform,dress.bounds(old,old.transform.affine_inverse()))
    dress.hotel(stock)
   var additions:=upgrade_groups(stock)
   if not additions.is_empty():
    patch=dress.scenery_group(authored,name)
    for group in additions:group.reparent(patch,true)
  else:
   patch=authored.get_node_or_null(name)
  if patch:
   if name==TEMPLE_CELL:
    stock.get_node("KandyPrecinct_tooth_temple").free()
    for candidate in ["fort_apartments","_Node3D_4477"]:
     var block:=stock.get_node_or_null(candidate)
     if block:block.free()
   for group in upgrade_groups(patch):
    if group.name.begins_with("Landu_Kelae_"):
     var original:=stock.get_node_or_null("_"+str(group.name).trim_prefix("Landu_Kelae_"))
     if original:original.free()
    if group.name in ["Roof_fort_apartments","Roof__Node3D_4477"]:continue
    apply_group(stock,group)
   cell.scene=baker.pack(stock,name)
   changed+=1
  stock.free()
 if rebuild:
  own_generated(authored,authored)
  var packed:=PackedScene.new()
  if packed.pack(authored)!=OK or ResourceSaver.save(packed,scene_path)!=OK:
   printerr("Could not save editable scenery")
   quit(2)
   return
 if not baker.flush(stage.path_join("ceylon-scenery.pck")):
  printerr("Could not write Kandy scenery pack")
  quit(2)
  return
 manifest.packs.append({"file":"ceylon-scenery.pck","sha256":FileAccess.get_sha256(stage.path_join("ceylon-scenery.pck"))})
 manifest.version="1.2.0"
 manifest.lighting.sun_angles=[-24,-120,0]
 manifest.lighting.sun_color="ffe1ba"
 manifest.lighting.sun_energy=1.1
 manifest.lighting.ambient_energy=.63
 write(stage.path_join("manifest.json"),manifest)
 write(stage.path_join("cells.json"),cells)
 print("KANDY_UPGRADE_READY cells=",changed," resources=",baker.files.size())
 quit()
