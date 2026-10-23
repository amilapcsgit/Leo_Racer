class_name LeoInputGlyph
extends HBoxContainer
var glyph: TextureRect
var caption: Label
func configure(kind: String,words: String) -> void:
 if not glyph:
  mouse_filter=Control.MOUSE_FILTER_IGNORE
  glyph=TextureRect.new();glyph.custom_minimum_size=Vector2(32,32);glyph.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;glyph.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;glyph.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(glyph)
  caption=Label.new();caption.add_theme_font_size_override("font_size",20);caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(caption)
 glyph.texture=load("res://assets/ui/icons/"+kind+".svg");caption.text=words
