extends SceneTree
func _initialize() -> void:
 for kind in ["keyboard","controller","wheel"]:
  var image:=Image.new()
  var result:=image.load_svg_from_string(FileAccess.get_file_as_string("res://assets/ui/controls/"+kind+".svg"),3.)
  if result!=OK:quit(1);return
  image.save_png("res://assets/ui/controls/"+kind+"-279.png")
 print("CONTROL_PNGS_279 PASS");quit()
