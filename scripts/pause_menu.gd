extends CanvasLayer
## Esc on the claim: the world holds still while the book is open.
const Style=preload("res://scripts/menu_style.gd")
const SaveGame=preload("res://scripts/save_game.gd")
var opened:=false
var dim:=ColorRect.new()
var panel:=PanelContainer.new()
var column:=VBoxContainer.new()
var status:=Label.new()
var settings_page: Control
var mouse_before:=Input.MOUSE_MODE_CAPTURED
@onready var claim: Node3D=get_parent()

func _ready() -> void:
	layer=40;process_mode=Node.PROCESS_MODE_ALWAYS
	dim.color=Color(0,0,0,.45);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(dim)
	add_child(panel);panel.add_theme_stylebox_override("panel",Style.parchment(52))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER);panel.offset_left=-230;panel.offset_right=230;panel.offset_top=-260;panel.offset_bottom=260
	column.add_theme_constant_override("separation",4);panel.add_child(column)
	column.add_child(Style.label("1848",64,Style.INK,true))
	status=Style.label("",18,Style.FADED);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(status)
	column.add_child(Style.button("Back to the river",close))
	column.add_child(Style.button("The outfit's roll book",func(): close();claim.get_node("CrewBook").open_book()))
	column.add_child(Style.button("The pocket ledger",func(): close();claim.get_node("Ledger").open_book()))
	column.add_child(Style.button("Settings",_settings))
	column.add_child(Style.button("Save the season",_save))
	column.add_child(Style.button("Save and quit",func(): if _save() or get_node("/root/GameState").season_ended: claim.request_quit()))
	column.add_child(Style.label("Saves are also written at every dawn.",16,Style.FADED))
	hide()

func open() -> void:
	if opened: return
	mouse_before=Input.mouse_mode
	opened=true;show();get_tree().paused=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var game: Node=get_node("/root/GameState")
	status.text="%s · %s" % [preload("res://scripts/calendar.gd").date_string(game.day),game.weather().capitalize()]
	column.get_child(2).grab_focus.call_deferred()

func close() -> void:
	if not opened: return
	if is_instance_valid(settings_page): settings_page.queue_free()
	panel.show()
	opened=false;hide();get_tree().paused=false
	Input.mouse_mode=mouse_before if mouse_before!=Input.MOUSE_MODE_VISIBLE or claim.get_node("Activities").ui_open() else Input.MOUSE_MODE_CAPTURED

func _settings() -> void:
	panel.hide()
	settings_page=preload("res://scripts/settings_panel.gd").new()
	add_child(settings_page)
	settings_page.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	settings_page.offset_left=-380;settings_page.offset_right=380;settings_page.offset_top=-300;settings_page.offset_bottom=300
	settings_page.closed.connect(func(): settings_page.queue_free();panel.show();column.get_child(2).grab_focus())

func _save() -> bool:
	var game: Node=get_node("/root/GameState")
	if game.season_ended or get_node("/root/Trip").travelling or not claim.get_node("Activities").idle() and not claim.get_node("Activities").ui_open():
		status.text="Not now. Finish what you are doing first.";return false
	var ok: bool=SaveGame.write(game,claim)
	status.text="Season saved · "+preload("res://scripts/calendar.gd").date_string(game.day) if ok else "Could not write the save."
	return ok

func _input(event: InputEvent) -> void:
	if not opened:
		if event.is_action_pressed("pause") and claim.open_pause(): get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if is_instance_valid(settings_page): settings_page.queue_free();panel.show()
		else: close()
		get_viewport().set_input_as_handled()
