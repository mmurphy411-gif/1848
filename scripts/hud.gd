extends CanvasLayer
## The sack total is the only player HUD element.

var label := Label.new()
var action_label := Label.new()
var notice := ""
var notice_time := 0.0

func _ready() -> void:
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	label.offset_left = -160
	label.offset_top = -54
	label.offset_right = -28
	label.offset_bottom = -28
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.94, 0.90, 0.79))
	var sack := get_node("/root/Sack")
	sack.changed.connect(_update)
	_update(sack.ounces)
	add_child(action_label)
	action_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	action_label.offset_left=-430;action_label.offset_right=430;action_label.offset_top=-85;action_label.offset_bottom=-40
	action_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	action_label.add_theme_font_size_override("font_size",20)
	action_label.add_theme_color_override("font_color",Color(.94,.90,.79))
	action_label.add_theme_constant_override("outline_size",5)
	action_label.mouse_filter=Control.MOUSE_FILTER_IGNORE

func notify(text: String,seconds := 1.5) -> void:
	notice=text;notice_time=seconds

func _process(delta: float) -> void:
	if not get_parent().has_node("Activities"): return
	notice_time=maxf(0,notice_time-delta)
	var activities: Node=get_parent().get_node("Activities")
	var fisher: Node=get_parent().get_node("Walker/Fisher")
	var game := get_node("/root/GameState")
	action_label.text=""
	if activities.ui_open(): return
	if notice_time>0: action_label.text=notice;return
	if fisher.state!=0:
		action_label.text="%s · %d bait · %d hooks" % [str(fisher.bait_type).capitalize(),game.inventory.bait.get(fisher.bait_type,0)+(1 if fisher.bait_loaded else 0),game.inventory.hooks]
		return
	if not activities.idle(): return
	var camp: Node=get_parent().get_node("Camp")
	var target: String=camp.target(activities.walker)
	var names := {"FireRing":"Add wood" if camp.burning() else "Light fire · 3 driftwood","Skillet":"Skillet","Rack":"Smoke fish","Cache":"Food cache","Bedroll":"Sleep","Crate":"Open ledger"}
	if target!="": action_label.text="G / X · "+names[target];return
	var bait: String=get_parent().get_node("BaitSources").eligible(activities.walker.position,activities.clock.hour_at(activities.clock.elapsed))
	if bait!="": action_label.text="G / X · Gather "+bait

func _update(ounces: float) -> void:
	label.text = "%.2f oz" % ounces
