extends CanvasLayer
## Hold T (right shoulder) to let the day pass while the miner stands idle: the
## sun, the river, the fire and the outfit all run at twenty-four times speed.
## Also sets the base pace from the chosen day length, and shows the pocket watch.
const Calendar=preload("res://scripts/calendar.gd")
const SKIP:=24.0
var shade:=ColorRect.new()
var watch:=Label.new()
var passing:=false
var amount:=0.0
@onready var claim: Node3D=get_parent()
@onready var clock: Node=claim.get_node("Daylight/Clock")
@onready var game: Node=get_node("/root/GameState")

func _ready() -> void:
	layer=7
	var vignette:=ShaderMaterial.new();vignette.shader=Shader.new()
	vignette.shader.code="shader_type canvas_item;\nuniform float amount=0.0;\nvoid fragment(){float d=distance(UV,vec2(.5));COLOR=vec4(.05,.035,.02,smoothstep(.35,.85,d)*amount);}"
	shade.material=vignette;shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	watch.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);watch.offset_left=-420;watch.offset_right=420;watch.offset_top=26;watch.offset_bottom=70
	watch.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;watch.mouse_filter=Control.MOUSE_FILTER_IGNORE
	watch.add_theme_font_override("font",preload("res://assets/fonts/PatrickHand-Regular.ttf"));watch.add_theme_font_size_override("font_size",24)
	watch.add_theme_color_override("font_color",Color(.96,.91,.79));watch.add_theme_color_override("font_outline_color",Color(0,0,0,.6));watch.add_theme_constant_override("outline_size",6)
	add_child(watch)

static func time_string(hour: float) -> String:
	var h:=int(hour)%24;var m:=int((hour-floorf(hour))*60)
	var part:="in the morning" if h<12 else "in the afternoon" if h<18 else "in the evening" if h<21 else "at night"
	if h<5: part="before dawn"
	return "%d:%02d %s" % [12 if h%12==0 else h%12,m,part]

func _process(delta: float) -> void:
	var settings: Node=get_node_or_null("/root/Settings")
	var base: float=settings.day_rate() if settings else 1.0
	var activities: Node=claim.get_node("Activities")
	var photo: Node=claim.get_node_or_null("PhotoMode")
	var may: bool=clock.running and activities.idle() and not get_node("/root/Trip").travelling and not (photo and photo.get("active")) \
		and Vector2(claim.get_node("Walker").velocity.x,claim.get_node("Walker").velocity.z).length()<.2
	passing=may and Input.is_action_pressed("wait")
	clock.rate=base*(SKIP if passing else 1.0)
	amount=move_toward(amount,.85 if passing else 0.0,delta*3)
	shade.material.set_shader_parameter("amount",amount)
	var show_watch: bool=passing or (settings and settings.get_value("show_clock") and not activities.ui_open())
	watch.visible=show_watch
	if show_watch:
		watch.text=("The day passes  ·  " if passing else "")+"%s, %s  ·  %s" % [Calendar.weekday(game.day),Calendar.date_string(game.day).trim_suffix(", 1848"),time_string(clock.hour_at(clock.elapsed))]
