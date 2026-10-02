extends RefCounted
## Shared look for the paper menus: the ledger's parchment, iron-gall ink and
## the hand-lettered face. Static helpers so every menu is built the same way.
const INK:=Color(.16,.12,.07)
const FADED:=Color(.36,.29,.2)
const CURSIVE:=preload("res://assets/fonts/Cedarville-Cursive.ttf")
const HAND:=preload("res://assets/fonts/PatrickHand-Regular.ttf")

static func parchment(margin := 48) -> StyleBoxTexture:
	var style:=StyleBoxTexture.new();style.texture=preload("res://assets/camp/camp_atlas.png")
	style.content_margin_left=margin;style.content_margin_right=margin;style.content_margin_top=margin*.7;style.content_margin_bottom=margin*.7
	return style

static func label(text: String, size := 22, color := INK, cursive := false) -> Label:
	var l:=Label.new();l.text=text
	l.add_theme_font_override("font",CURSIVE if cursive else HAND);l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	return l

static func button(text: String, action: Callable, size := 24) -> Button:
	var b:=Button.new();b.text=text;b.focus_mode=Control.FOCUS_ALL;b.alignment=HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font",HAND);b.add_theme_font_size_override("font_size",size)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: b.add_theme_color_override(state,INK)
	b.add_theme_color_override("font_disabled_color",Color(INK,.35))
	var plain:=StyleBoxFlat.new();plain.bg_color=Color(0,0,0,0);plain.content_margin_left=14;plain.content_margin_right=14;plain.content_margin_top=4;plain.content_margin_bottom=4
	var hover:=plain.duplicate();hover.bg_color=Color(.55,.44,.28,.28);hover.set_corner_radius_all(4)
	var focus:=hover.duplicate();focus.border_color=Color(INK,.5);focus.border_width_left=3
	b.add_theme_stylebox_override("normal",plain);b.add_theme_stylebox_override("hover",hover);b.add_theme_stylebox_override("pressed",hover)
	b.add_theme_stylebox_override("focus",focus);b.add_theme_stylebox_override("disabled",plain)
	b.pressed.connect(action)
	return b

static func slider(value: float, changed: Callable, low := 0.0, high := 1.0, step := .05) -> HSlider:
	var s:=HSlider.new();s.min_value=low;s.max_value=high;s.step=step;s.value=value;s.custom_minimum_size=Vector2(260,24)
	s.focus_mode=Control.FOCUS_ALL;s.value_changed.connect(changed)
	return s
