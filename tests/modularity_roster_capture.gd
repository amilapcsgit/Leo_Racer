extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 root.size=Vector2i(1600,1000);DisplayServer.window_set_size(root.size)
 var catalog:=GarageCatalog.shared()
 var canvas:=Control.new();canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(canvas)
 var grid:=GridContainer.new();grid.columns=4;grid.add_theme_constant_override("h_separation",0);grid.add_theme_constant_override("v_separation",0);canvas.add_child(grid)
 var index:=0
 for vehicle in catalog.vehicles:
  await LeoAssets.scene_async(vehicle.model_path,self)
  var cell:=VBoxContainer.new();cell.custom_minimum_size=Vector2(400,250);grid.add_child(cell)
  var title:=Label.new();title.text=String(vehicle.id);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;cell.add_child(title)
  var container:=SubViewportContainer.new();container.custom_minimum_size=Vector2(400,220);cell.add_child(container)
  var view:=SubViewport.new();view.size=Vector2i(400,220);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;container.add_child(view)
  var world:=Node3D.new();view.add_child(world)
  var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.sky=Sky.new();env.environment.sky.sky_material=ProceduralSkyMaterial.new();env.environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY;env.environment.background_mode=Environment.BG_SKY;env.environment.background_color=Color(.12,.17,.22);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7;world.add_child(env)
  var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-25,0);sun.light_energy=1.5;world.add_child(sun)
  var model:=VehicleAssembler.assemble(vehicle,catalog.drivers[index%catalog.drivers.size()]);world.add_child(model)
  var bounds:=AABB();var first:=true
  for mesh in model.find_children("*","MeshInstance3D",true,false):
   var box: AABB=mesh.global_transform*mesh.get_aabb()
   bounds=box if first else bounds.merge(box);first=false
  var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=maxf(bounds.size.x,bounds.size.z)*1.25+1.;world.add_child(camera)
  var center:=bounds.get_center();camera.position=center+Vector3(7,4.2,9);camera.look_at(center,Vector3.UP);camera.current=true
  index+=1
 for frame in 5:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/modularity/full-roster.png")
 print("MODULARITY_ROSTER_CAPTURE vehicles=",catalog.vehicles.size())
 await process_frame;quit()
