class_name LeoSplitRaceView
extends Control
var game: Node3D
var views: Array[SubViewport]=[]
var cameras: Array[Camera3D]=[]
var overlays: Array[LeoPlayerHUD]=[]
var original_canvas_size:=Vector2i(1600,900)
func _ready() -> void:
 original_canvas_size=get_tree().root.content_scale_size
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
 var row:=HBoxContainer.new();row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);row.add_theme_constant_override("separation",3);row.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(row)
 for slot in 2:
  var container:=SubViewportContainer.new();container.stretch=true;container.size_flags_horizontal=Control.SIZE_EXPAND_FILL;container.size_flags_vertical=Control.SIZE_EXPAND_FILL;container.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(container)
  var viewport:=SubViewport.new();viewport.name="Player%dView" % (slot+1);viewport.world_3d=game.get_world_3d();viewport.handle_input_locally=false;viewport.size=Vector2i(960,1080);viewport.msaa_3d=Viewport.MSAA_2X;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;container.add_child(viewport);views.append(viewport)
  var camera:=Camera3D.new();camera.name="Player%dCamera" % (slot+1);camera.fov=63.;camera.far=game.race_camera_far();camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;viewport.add_child(camera);cameras.append(camera)
  var layer:=CanvasLayer.new();viewport.add_child(layer)
  var overlay:=LeoPlayerHUD.new();overlay.game=game;overlay.slot=slot;layer.add_child(overlay);overlays.append(overlay)
 hide()
func activate(enabled: bool) -> void:
 get_tree().root.content_scale_size=Vector2i.ZERO if enabled else original_canvas_size
 visible=enabled
 for slot in 2:
  cameras[slot].far=game.race_camera_far()
  views[slot].render_target_update_mode=SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
  overlays[slot].set_process(enabled)
  if enabled:
   cameras[slot].current=true
   game.local_players[slot].camera=cameras[slot]
 if enabled:game.camera.current=false
 else:
  game.camera.current=true
  game.local_players[0].camera=game.camera
  game.local_players[1].camera=null

func set_frozen(frozen: bool) -> void:
 if not visible:return
 for viewport in views:viewport.render_target_update_mode=SubViewport.UPDATE_ONCE if frozen else SubViewport.UPDATE_ALWAYS
