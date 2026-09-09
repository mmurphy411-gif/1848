extends CanvasLayer
## Contextual fishing feedback alongside the sack total.

var label := Label.new()
var action_label := Label.new()
var notice := ""
var notice_time := 0.0
var tension_panel := PanelContainer.new()
var tension_label := Label.new()
var tension_bar := ProgressBar.new()
var tension_hint := Label.new()
var tension_fill := StyleBoxFlat.new()

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
	_build_tension_meter()

func _build_tension_meter() -> void:
	add_child(tension_panel)
	tension_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	tension_panel.offset_left=-220;tension_panel.offset_right=220
	tension_panel.offset_top=-190;tension_panel.offset_bottom=-98
	tension_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var paper := StyleBoxFlat.new()
	paper.bg_color=Color(.045,.065,.07,.94)
	paper.set_corner_radius_all(8)
	paper.content_margin_left=16;paper.content_margin_right=16
	paper.content_margin_top=10;paper.content_margin_bottom=10
	tension_panel.add_theme_stylebox_override("panel",paper)
	var stack := VBoxContainer.new();stack.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation",5);tension_panel.add_child(stack)
	for text_label in [tension_label,tension_hint]:
		text_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		text_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		text_label.add_theme_font_size_override("font_size",18)
		text_label.add_theme_color_override("font_color",Color(.94,.90,.79))
	stack.add_child(tension_label)
	tension_bar.custom_minimum_size=Vector2(0,12)
	tension_bar.show_percentage=false;tension_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new();track.bg_color=Color(.17,.21,.22)
	track.set_corner_radius_all(4);tension_fill.set_corner_radius_all(4)
	tension_bar.add_theme_stylebox_override("background",track)
	tension_bar.add_theme_stylebox_override("fill",tension_fill)
	stack.add_child(tension_bar);stack.add_child(tension_hint)
	tension_panel.hide()

func _update_tension(fisher: Node,ui_open: bool) -> void:
	tension_panel.visible=fisher.state==fisher.State.FIGHT and not ui_open
	if not tension_panel.visible: return
	var fight: Dictionary=fisher.fight
	var tension: float=fight.tension
	var warning: bool=fight.running or fight.run_at-fight.elapsed<=.4
	tension_bar.value=tension*100
	tension_label.text="LINE TENSION  ·  %d%%" % roundi(tension*100)
	tension_fill.bg_color=Color(.92,.29,.22) if tension>=.75 else Color(.96,.69,.27) if tension>=.5 or warning else Color(.42,.76,.63)
	if fight.running: tension_hint.text="FISH RUNNING · Release F / Y"
	elif warning: tension_hint.text="FISH ABOUT TO RUN · Release F / Y"
	elif tension>=.5: tension_hint.text="HIGH TENSION · Release F / Y to ease"
	else: tension_hint.text="Hold F / Y to pull · Breaks at 100%"

func notify(text: String,seconds := 1.5) -> void:
	notice=text;notice_time=seconds

func _process(delta: float) -> void:
	if get_parent().has_method("prompt"):
		var game: Node=get_node("/root/GameState")
		label.offset_left=-300;label.text="%.2f oz · $%.2f" % [get_node("/root/Sack").ounces,game.dollars]
		notice_time=maxf(0,notice_time-delta)
		action_label.text=notice if notice_time>0 else get_parent().prompt()
		if get_parent().get_node("Sandbox").opened: action_label.text=""
		return
	if not get_parent().has_node("Activities"): return
	notice_time=maxf(0,notice_time-delta)
	var activities: Node=get_parent().get_node("Activities")
	var fisher: Node=get_parent().get_node("Walker/Fisher")
	var game := get_node("/root/GameState")
	_update_tension(fisher,activities.ui_open())
	action_label.text=""
	if activities.ui_open(): return
	if notice_time>0: action_label.text=notice;return
	if fisher.state!=0:
		action_label.text="%s · %d bait · %d hooks" % [str(fisher.bait_type).capitalize(),game.inventory.bait.get(fisher.bait_type,0)+(1 if fisher.bait_loaded else 0),game.inventory.hooks]
		return
	if not activities.idle():
		var recipe: String=get_parent().get_node("Camp").recipe
		action_label.text={"cook":"Cooking "+recipe if recipe!="" else "Frying fish","fire":"Tending fire","eat":"Eating"}.get(activities.action,"")
		return
	var trip: Node=get_node("/root/Trip")
	if trip.travelling: action_label.text="";return
	if trip.at_trail(): action_label.text="G / X · "+trip.prompt();return
	var camp: Node=get_parent().get_node("Camp")
	var target: String=camp.target(activities.walker)
	var names := {"FireRing":"Add wood" if camp.burning() else "Light fire · 3 driftwood","Skillet":"Skillet","Pot":"Pot","Rack":"Need salt to smoke" if game.inventory.goods.salt<.1 else "Smoke fish","Cache":"Food cache","Bedroll":"Sleep","Crate":"Eat · carried food" if camp.has_stored() else "Cut bait" if game.inventory.goods.pork>=.25 else "Open ledger"}
	if target!="": action_label.text="G / X · "+names[target];return
	var bait: String=get_parent().get_node("BaitSources").eligible(activities.walker.position,activities.clock.hour_at(activities.clock.elapsed))
	if bait!="": action_label.text="G / X · Gather "+bait

func _update(ounces: float) -> void:
	label.text = "%.2f oz" % ounces
