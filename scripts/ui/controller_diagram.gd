class_name LeoControllerDiagram
extends Control
var game: Node
var fallback: LeoInputRouter
var reduced_motion:=false
var panels: Array[LeoControlMapPanel]=[]
var images: Array[TextureRect]:
 get:
  var result: Array[TextureRect]=[]
  for panel in panels:result.append(panel.image)
  return result
var signature:=""
func _ready() -> void:
 mouse_filter=MOUSE_FILTER_IGNORE;fallback=LeoInputRouter.new();fallback.load_profiles()
 var cfg:=ConfigFile.new();cfg.load("user://leo_racer.cfg");fallback.active_slots=clampi(int(cfg.get_value("game","human_count",1)),1,2)
 resized.connect(rebuild);rebuild()
func router() -> LeoInputRouter:return game.get("input_router") if is_instance_valid(game) and game.get("input_router") else fallback
func player_count() -> int:return clampi(int(game.get("human_count")),1,2) if is_instance_valid(game) and game.get("human_count")!=null else router().active_slots
func active_player() -> int:return 0
func kind_of(p: LeoPlayerInput) -> String:return LeoControlMapPanel.device_kind(p)
func short_binding(p: LeoPlayerInput,action: String) -> String:return LeoControlMapPanel.describe(p,action)
func binding_anchor(kind: String,p: LeoPlayerInput,action: String) -> String:
 var bindings: Array=p.bindings.get(action,[])
 return LeoControlMapPanel.binding_id(kind,bindings[0],action) if not bindings.is_empty() else ""
func current_signature() -> String:
 var value:=str(size)+str(player_count())
 for slot in player_count():value+=router().players[slot].kind+JSON.stringify(router().players[slot].bindings)
 return value
func rebuild() -> void:
 if not is_inside_tree() or not fallback:return
 for panel in panels:remove_child(panel);panel.queue_free()
 panels.clear();var count:=player_count();var width: float=(size.x-float(count-1)*16.)/count
 for slot in count:
  var panel:=LeoControlMapPanel.new();panel.player=router().players[slot];panel.slot=slot;panel.position=Vector2(slot*(width+16.),0);panel.size=Vector2(width,size.y);add_child(panel);panels.append(panel)
 signature=current_signature()
func _process(_dt: float) -> void:
 if is_visible_in_tree() and fallback and signature!=current_signature():rebuild()
func _exit_tree() -> void:
 if is_instance_valid(fallback):fallback.free()
