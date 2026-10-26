extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var view:=SubViewport.new();view.size=Vector2i(1536,768);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var background:=ColorRect.new();background.size=Vector2(1536,768);background.color=Color("153b32");view.add_child(background)
 var border:=Panel.new();border.position=Vector2(15,15);border.size=Vector2(1506,738)
 var style:=StyleBoxFlat.new();style.bg_color=Color("153b32");style.border_color=Color("dbcb96");style.set_border_width_all(10);border.add_theme_stylebox_override("panel",style);view.add_child(border)
 for row in [["KANDY LAKE",55,180,"res://assets/fonts/BarlowCondensed-BoldItalic.ttf"],["මහනුවර",285,146,"res://assets/art/kandy/fonts/NotoSansSinhala.ttf"],["கண்டி",510,144,"res://assets/art/kandy/fonts/NotoSansTamil.ttf"]]:
  var label:=Label.new();label.text=row[0];label.position=Vector2(35,row[1]);label.size=Vector2(1466,200);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_font_override("font",load(row[3]));label.add_theme_font_size_override("font_size",row[2]);label.add_theme_color_override("font_color",Color("fff4d5"));view.add_child(label)
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 var result:=view.get_texture().get_image().save_png("res://assets/art/kandy/signs/welcome.png")
 var path:="res://assets/art/kandy/signs/provenance.json";var provenance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));provenance.text_shaper="Godot advanced text server (Sinhala/Tamil)";provenance.files["welcome.png"]=FileAccess.get_sha256("res://assets/art/kandy/signs/welcome.png");FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(provenance,"  "))
 print("KANDY_MULTILINGUAL_TYPESET ",result);quit(result)
