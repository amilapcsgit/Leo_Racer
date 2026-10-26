extends SceneTree
var errors: Array[String]=[]
var checked:=0
var counts: Dictionary={"adverts":0,"advert_faces":0,"flags":0,"lightmaps":0,"arches":0,"mountains":0,"world_labels":0}
var game: Node3D
var terrain: Image
var terrain_info: Dictionary
func ground(p: Vector3) -> float:
 var u:=clampf((p.x-float(terrain_info.origin[0]))/float(terrain_info.spacing),0.,float(terrain_info.size)-1.)
 var v:=clampf((p.z-float(terrain_info.origin[1]))/float(terrain_info.spacing),0.,float(terrain_info.size)-1.)
 var x:=floori(u);var z:=floori(v);var xx:=mini(x+1,int(terrain_info.size)-1);var zz:=mini(z+1,int(terrain_info.size)-1)
 return lerpf(lerpf(terrain.get_pixel(x,z).r,terrain.get_pixel(xx,z).r,u-x),lerpf(terrain.get_pixel(x,zz).r,terrain.get_pixel(xx,zz).r,u-x),v-z)
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
 checked+=1
 if not ok:errors.append(message);push_error(message)
func board_geometry(mesh: Mesh,pose: Transform3D) -> void:
 var box:=mesh.get_aabb()
 if absf(box.size.x-9.)>.02 or box.size.z>.02 or (absf(box.size.y-3.)>.02 and absf(box.size.y-4.5)>.02):return
 counts.advert_faces+=1
 var clearance:=INF
 for x in [box.position.x,box.end.x]:
  for y in [box.position.y,box.end.y]:
   var corner: Vector3=pose*Vector3(x,y,box.position.z)
   for point in game.circuit.points:clearance=minf(clearance,Vector2(corner.x-point.x,corner.z-point.z).length())
 check(clearance>float(game.track_definition.route.width)*.5+5.,"Actual board corners clear the race pavement")
func inspect(node: Node) -> void:
 if node is Label3D:counts.world_labels+=1
 if node.has_meta("advert_station"):
  counts.adverts+=1;check(float(node.get_meta("outer_offset"))<=-float(game.track_definition.route.width)*.5-8.,"Advert outside outer pavement")
 if node is MeshInstance3D and node.mesh:board_geometry(node.mesh,node.global_transform)
 if node is MultiMeshInstance3D and node.multimesh:
  for i in node.multimesh.instance_count:board_geometry(node.multimesh.mesh,node.global_transform*node.multimesh.get_instance_transform(i))
 if node is Node3D and (String(node.name).begins_with("PhysicalSign_") or node.has_meta("protected_asset")):
  check(absf(node.global_position.y-ground(node.global_position))<.08,"Exported sign or landmark root meets sampled ground: "+String(node.name))
 if node.has_meta("flag_hoist_uv"):counts.flags+=node.multimesh.instance_count if node is MultiMeshInstance3D else 1;check(node.get_meta("flag_hoist_uv")==0.,"Hoist at pinned UV edge")
 if node.has_meta("start_arch"):counts.arches+=1
 if node.get_meta("surface_role","")=="distant_mountains":counts.mountains+=1
 if node is LightmapGI:
  counts.lightmaps+=1;check(node.light_data!=null and not node.light_data.lightmap_textures.is_empty(),"Export retains lightmap textures")
  check(node.light_data.get_user_count()>0,"Baked meshes remain bound")
 for child in node.get_children():inspect(child)
func run() -> void:
 terrain_info=JSON.parse_string(FileAccess.get_file_as_string("res://build/TrackSDK/data/kandy/terrain.json"))
 terrain=Image.create_from_data(int(terrain_info.size),int(terrain_info.size),false,Image.FORMAT_RF,FileAccess.get_file_as_bytes("res://build/TrackSDK/data/kandy/terrain.r32"))
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
 check(game.track_definition.id=="kandy_lake","Kandy selected")
 check(game.track_definition.metadata.get("authored_signage",false),"Authored signage declared")
 var sky: LeoArtProfile=game.art_profile
 var visual:=load(sky.sky_visual_path) as Texture2D;var radiance:=load(sky.sky_lighting_path) as Texture2D
 check(visual.get_width()==4096 and visual.get_height()==2048,"Full 4K panorama survives export")
 var image:=radiance.get_image()
 if image.is_compressed():image.decompress()
 var peak:=0.
 for y in range(0,image.get_height(),2):
  for x in range(0,image.get_width(),2):
   var pixel:=image.get_pixel(x,y);peak=maxf(peak,maxf(pixel.r,maxf(pixel.g,pixel.b)))
 check(peak>10.,"HDR radiance survives packaging")
 var seam_error:=0.
 for y in range(0,image.get_height(),8):
  var a:=image.get_pixel(0,y);var b:=image.get_pixel(image.get_width()-1,y)
  seam_error=maxf(seam_error,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
 check(seam_error<.003,"Exported HDR map has a periodic longitude boundary")
 var stream: Node=game.world.find_child("ColomboSceneryStreaming",true,false);await stream.stop()
 inspect(game.world)
 for cell in stream.cells:
  if stream.loaded.has(cell.id):continue
  var packed:=load(String(cell.scene)) as PackedScene
  if not packed:check(false,"Cell dependency is self-contained: "+String(cell.scene));continue
  var instance: Node3D=packed.instantiate();game.add_child(instance);inspect(instance);instance.free()
 check(counts.world_labels==0,"No floating Kandy world labels")
 check(counts.adverts>=10 and counts.flags>20,"Billboards and national flags retained")
 check(counts.advert_faces==counts.adverts,"All actual billboard faces checked, including static batches")
 check(counts.arches==1 and counts.mountains==3 and counts.lightmaps==3,"Arch, mountain layers and baked precincts complete")
 var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://build/Release-2.3.0/GameAssets/tracks/kandy_lake/route.json"))
 check(old==game.track_definition.route,"Published racing route unchanged")
 var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checked,"counts":counts,"peak_hdr_radiance":peak,"hdr_seam_error":seam_error,"hdr_image_format":image.get_format(),"errors":errors}
 FileAccess.open("res://build/kandy231/presentation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("KANDY231_PRESENTATION ",JSON.stringify(report));await game.quit_game(0 if errors.is_empty() else 2)
