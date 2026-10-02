extends CanvasLayer
## The opening: a slow crane over the bar at golden hour, and a season to begin.
const Style=preload("res://scripts/menu_style.gd")
const SaveGame=preload("res://scripts/save_game.gd")
const LIGHT:=Color(.97,.92,.8)
const GOLDEN_HOUR:=18.55
var opened:=true
var camera:=Camera3D.new()
var time:=0.0
var column:=VBoxContainer.new()
var fade:=ColorRect.new()
var card:=VBoxContainer.new()
var settings_page: Control
var save: Dictionary={}
@onready var claim: Node3D=get_parent()

func _ready() -> void:
	layer=45
	save=SaveGame.read()
	var shade:=TextureRect.new();var gradient:=GradientTexture2D.new();gradient.gradient=Gradient.new()
	gradient.gradient.set_color(0,Color(0,0,0,.62));gradient.gradient.set_color(1,Color(0,0,0,0));gradient.fill_to=Vector2(1,0)
	shade.texture=gradient;shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE);shade.offset_right=900;shade.stretch_mode=TextureRect.STRETCH_SCALE
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(shade)
	add_child(column);column.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	column.offset_left=110;column.offset_right=780;column.offset_top=170;column.add_theme_constant_override("separation",6)
	var title:=Style.label("1848",190,LIGHT,true);title.add_theme_color_override("font_shadow_color",Color(0,0,0,.55))
	title.add_theme_constant_override("shadow_offset_x",3);title.add_theme_constant_override("shadow_offset_y",4)
	column.add_child(title)
	column.add_child(_light(Style.label("One season on the North Yuba River, before the world arrived.",26,LIGHT)))
	var gap:=Control.new();gap.custom_minimum_size.y=40;column.add_child(gap)
	if not save.is_empty():
		column.add_child(_menu("Continue the season",func(): _begin(save)))
		column.add_child(_light(Style.label("     "+SaveGame.summary(save),19,Color(LIGHT,.7))))
	column.add_child(_menu("Begin a new season" if save.is_empty() else "Begin again · June 26",func(): _begin({})))
	column.add_child(_menu("Settings",_settings))
	column.add_child(_menu("Leave the river",func(): claim.request_quit()))
	var credit:=_light(Style.label("2.0 · the outfit · E pan · G act · C crew · T let time pass · P daguerreotype · Esc menu",17,Color(LIGHT,.55)))
	add_child(credit);credit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);credit.offset_left=110;credit.offset_top=-60;credit.offset_bottom=-30
	fade.color=Color(0,0,0,1);fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);fade.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(fade)
	create_tween().tween_property(fade,"color:a",0.0,2.5)
	claim.add_child(camera);camera.attributes=claim.get_node("Daylight").camera_attributes;camera.fov=48;camera.make_current()
	claim.get_node("Daylight").apply(GOLDEN_HOUR)
	claim.get_node("Daylight/Clock").start(GOLDEN_HOUR,false);claim.get_node("Daylight/Clock").running=false
	claim.get_node("Walker").set_physics_process(false)
	claim.get_node("HUD").visible=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	column.get_child(3).grab_focus.call_deferred()

func _light(l: Label) -> Label:
	l.add_theme_color_override("font_shadow_color",Color(0,0,0,.6));l.add_theme_constant_override("shadow_offset_x",2);l.add_theme_constant_override("shadow_offset_y",2)
	return l

func _menu(text: String, action: Callable) -> Button:
	var b:=Style.button(text,action,32)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: b.add_theme_color_override(state,LIGHT)
	b.add_theme_color_override("font_shadow_color",Color(0,0,0,.6));b.add_theme_constant_override("shadow_offset_x",2);b.add_theme_constant_override("shadow_offset_y",2)
	var hover:=StyleBoxFlat.new();hover.bg_color=Color(1,.9,.7,.12);hover.border_color=Color(LIGHT,.7);hover.border_width_left=3;hover.content_margin_left=14
	b.add_theme_stylebox_override("hover",hover);b.add_theme_stylebox_override("focus",hover)
	return b

func _process(delta: float) -> void:
	if not opened: return
	time+=delta
	# A slow drift over the river, looking upstream across the bar into the sun.
	var x:=22.0-fposmod(time*.35,60.0)
	camera.position=Vector3(x,6.5+sin(time*.07)*.8,-19.0)
	camera.look_at(Vector3(x-16,.4,4.0))

func _settings() -> void:
	column.hide()
	settings_page=preload("res://scripts/settings_panel.gd").new();add_child(settings_page)
	settings_page.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	settings_page.offset_left=90;settings_page.offset_right=850;settings_page.offset_top=-300;settings_page.offset_bottom=300
	settings_page.closed.connect(func(): settings_page.queue_free();column.show();column.get_child(3).grab_focus())

func _begin(data: Dictionary) -> void:
	if not opened: return
	opened=false
	for b in column.get_children(): if b is Button: b.disabled=true
	await create_tween().tween_property(fade,"color:a",1.0,1.2).finished
	column.hide();camera.queue_free()
	if is_instance_valid(settings_page): settings_page.queue_free()
	claim.get_node("HUD").visible=true
	claim.begin_play(data)
	var game: Node=get_node("/root/GameState")
	_card(preload("res://scripts/calendar.gd").date_string(game.day),"The North Yuba River" if data.is_empty() else (game.crew.bar_name if game.crew.bar_name!="" else "The North Yuba River"))
	await get_tree().create_timer(1.6).timeout
	await create_tween().tween_property(fade,"color:a",0.0,2.5).finished
	await get_tree().create_timer(1.2).timeout
	await create_tween().tween_property(card,"modulate:a",0.0,1.5).finished
	if data.is_empty(): claim.get_node("HUD").notify("E pan at the water · G act · C crew book · T let time pass · Esc menu",9)
	queue_free()

func _card(line: String, place: String) -> void:
	add_child(card);card.set_anchors_and_offsets_preset(Control.PRESET_CENTER);card.offset_left=-500;card.offset_right=500;card.offset_top=-80
	card.alignment=BoxContainer.ALIGNMENT_CENTER
	for text in [[line,64,true],[place,28,false]]:
		var l:=_light(Style.label(text[0],text[1],LIGHT,text[2]));l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;card.add_child(l)
	move_child(card,-1)

func _unhandled_input(event: InputEvent) -> void:
	# Clicks off the menu and Esc stay with the title (and its date card).
	if event is InputEventMouseButton or event.is_action_pressed("ui_cancel"): get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not opened: return
	if event.is_action_pressed("ui_cancel") and is_instance_valid(settings_page):
		settings_page.queue_free();column.show();get_viewport().set_input_as_handled();return
	# Keep the world asleep behind the menu.
	if event is InputEventKey and not event.physical_keycode in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_ENTER,KEY_KP_ENTER,KEY_SPACE,KEY_ESCAPE,KEY_TAB]:
		get_viewport().set_input_as_handled()
