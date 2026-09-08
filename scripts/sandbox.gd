extends CanvasLayer
const Calendar=preload("res://scripts/calendar.gd")
var opened := false
var panel := PanelContainer.new()
var fields: Dictionary={}
var weather := OptionButton.new()
var fire := CheckButton.new()
var date_label := Label.new()
@onready var game: Node=get_node("/root/GameState")
@onready var claim: Node3D=get_parent()
func _ready() -> void:
	if not OS.is_debug_build(): set_process_input(false);return
	layer=10;add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left=-380;panel.offset_right=-16;panel.offset_top=20;panel.offset_bottom=-20
	var scroll := ScrollContainer.new();panel.add_child(scroll)
	var column := VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(column)
	var title := Label.new();title.text="SEASON SANDBOX  ·  F4";column.add_child(title);column.add_child(date_label)
	for key in ["seed","day","hour","dollars","gold","condition","hooks","line","firewood","bait.grasshopper","bait.hellgrammite","bait.worm","bait.pork","fish.fresh","fish.smoked"]:
		var row := HBoxContainer.new();column.add_child(row)
		var label := Label.new();label.text=key;label.custom_minimum_size.x=170;row.add_child(label)
		var value := SpinBox.new();value.min_value=0;value.max_value=2147483647 if key=="seed" else 132 if key=="day" else 24 if key=="hour" else 100000
		value.step=.25 if key in ["hour","gold","dollars","condition","line"] else 1
		value.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(value);fields[key]=value
	for name in ["auto","clear","hot","rain","frost"]: weather.add_item(name)
	column.add_child(weather);fire.text="Fire lit";column.add_child(fire)
	for name in ["Apply","Dawn","Dusk","Next day","Sleep","Refresh fish"]:
		var button := Button.new();button.text=name;button.pressed.connect(command.bind(name));column.add_child(button)
	panel.hide()
func refresh_fields() -> void:
	var values := {"seed":game.seed,"day":game.day,"hour":claim.get_node("Daylight/Clock").hour_at(claim.get_node("Daylight/Clock").elapsed),"dollars":game.dollars,"gold":get_node("/root/Sack").ounces,"condition":game.condition,"hooks":game.inventory.hooks,"line":game.inventory.line_m,"firewood":game.inventory.firewood}
	for bait in game.inventory.bait: values["bait."+bait]=game.inventory.bait[bait]
	for kind in ["fresh","smoked"]: values["fish."+kind]=game.inventory.fish.filter(func(f):return f.state==kind).size()
	for key in fields: fields[key].value=values[key]
	date_label.text=Calendar.date_string(game.day)
	weather.select(["auto","clear","hot","rain","frost"].find(game.weather_override));fire.button_pressed=claim.get_node("Camp").burning()
func command(name: String) -> void:
	var clock: Node=claim.get_node("Daylight/Clock")
	match name:
		"Apply":
			if claim.get_node("Activities").busy: return
			claim.get_node("Walker/Fisher").cancel()
			claim.get_node("Walker/Panner")._reset()
			var args: Dictionary={}
			for key in fields:
				if key!="gold": args[key]=str(fields[key].value)
			args.weather=weather.get_item_text(weather.selected)
			game.apply_scenario(args)
			get_node("/root/Sack").ounces=fields.gold.value;get_node("/root/Sack").changed.emit(fields.gold.value)
			clock.start(game.start_hour)
			claim.get_node("Camp").last_hour=game.start_hour
			claim.get_node("Camp").fire_hours=2.0 if fire.button_pressed else 0.0
			claim.get_node("BaitSources").reset()
		"Dawn": clock.start(clock.DAWN)
		"Dusk": clock.start(19)
		"Next day": clock.end_day()
		"Sleep":
			close_panel()
			claim.get_node("Activities").sleep()
	claim.get_node("FishSchool").refresh()
	refresh_fields()
func close_panel() -> void:
	opened=false;panel.hide();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_sandbox"):
		if opened: close_panel()
		else:
			claim.get_node("Ledger").close_book()
			opened=true;refresh_fields();panel.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif opened:
		if event.is_action_pressed("ui_cancel"): close_panel();get_viewport().set_input_as_handled()
		elif event is InputEventKey and not (get_viewport().gui_get_focus_owner() is LineEdit):
			if event.physical_keycode in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_E,KEY_F,KEY_G]: get_viewport().set_input_as_handled()
