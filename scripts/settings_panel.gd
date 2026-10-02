extends PanelContainer
## Settings page shared by the title and the pause menu. Changes apply at once.
const Style=preload("res://scripts/menu_style.gd")
signal closed
@onready var settings: Node=get_node("/root/Settings")

func _ready() -> void:
	add_theme_stylebox_override("panel",Style.parchment(46))
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",8);add_child(column)
	column.add_child(Style.label("Settings",40,Style.INK,true))
	var grid:=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",28);grid.add_theme_constant_override("v_separation",8)
	column.add_child(grid)
	_row(grid,"Mouse look",Style.slider(settings.get_value("mouse_sensitivity"),func(v): settings.set_value("mouse_sensitivity",v),.3,2.5,.05))
	var invert:=CheckBox.new();invert.button_pressed=settings.get_value("invert_y");invert.toggled.connect(func(on): settings.set_value("invert_y",on))
	_row(grid,"Invert look up / down",invert)
	for bus in [["master","Everything"],["ambience","River, wind and birds"],["foley","Work and footsteps"],["music","The harmonica"]]:
		_row(grid,bus[1],Style.slider(settings.get_value(bus[0]),func(v): settings.set_value(bus[0],v)))
	var days:=OptionButton.new()
	for name in settings.DAY_LENGTHS: days.add_item(name)
	days.selected=settings.DAY_LENGTHS.keys().find(settings.get_value("day_length"))
	days.item_selected.connect(func(i): settings.set_value("day_length",settings.DAY_LENGTHS.keys()[i]))
	days.add_theme_font_override("font",Style.HAND);days.add_theme_font_size_override("font_size",20)
	_row(grid,"Length of a day",days)
	var clock:=CheckBox.new();clock.button_pressed=settings.get_value("show_clock");clock.toggled.connect(func(on): settings.set_value("show_clock",on))
	_row(grid,"Pocket watch always showing",clock)
	var full:=CheckBox.new();full.button_pressed=settings.get_value("fullscreen");full.toggled.connect(func(on): settings.set_value("fullscreen",on))
	_row(grid,"Full screen",full)
	column.add_child(Style.label("Hold T to let time pass while you stand idle.",18,Style.FADED))
	var back:=Style.button("Back",func(): closed.emit())
	column.add_child(back)
	back.grab_focus.call_deferred()

func _row(grid: GridContainer, text: String, control: Control) -> void:
	grid.add_child(Style.label(text,22))
	grid.add_child(control)
