extends SceneTree
func _initialize():run.call_deferred()
func run():
 LeoAssets.configure(ProjectSettings.globalize_path('res://build/content-baseline/GameAssets'));LeoAssets.mount_packs();LeoVehicleLibrary.discover()
 root.size=Vector2i(640,640)
 var world:=Node3D.new();root.add_child(world)
 var catalog:=GarageCatalog.shared();var car:=VehicleAssembler.assemble(catalog.vehicle(&'bigster'),catalog.drivers[0]);world.add_child(car)
 var pivot:=car.find_child('CockpitSteering',true,false) as LeoCockpitSteering;pivot.set_process(false)
 for mesh in car.find_children('*','MeshInstance3D',true,false):
  if not pivot.is_ancestor_of(mesh):mesh.hide()
  else:
   for surface in mesh.mesh.get_surface_count():
    var mat:=mesh.get_active_material(surface) as StandardMaterial3D
    if mat:
     mat=mat.duplicate();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mesh.set_surface_override_material(surface,mat)
 var camera:=Camera3D.new();world.add_child(camera);camera.current=true;camera.fov=32.;camera.position=pivot.position+Vector3(0,.12,.8);camera.look_at(pivot.position)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color('#5b6875');world.add_child(environment)
 var folder:=ProjectSettings.globalize_path('res://build/refine278/wheel-review');DirAccess.make_dir_recursive_absolute(folder)
 for angle in [999]:
  pivot.basis=LeoCockpitSteering.NEUTRAL_BASIS
  for frame in 4:await process_frame
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder.path_join('wheel-%d.png'%angle))
 quit()

