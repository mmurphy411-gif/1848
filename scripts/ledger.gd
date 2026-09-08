extends CanvasLayer
const Calendar=preload("res://scripts/calendar.gd")
var opened := false
var book := PanelContainer.new()
var left := RichTextLabel.new()
var right := RichTextLabel.new()
@onready var game: Node=get_node("/root/GameState")
func _ready() -> void:
	layer=8
	add_child(book);book.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	book.offset_left=-540;book.offset_right=540;book.offset_top=-324;book.offset_bottom=324
	var style := StyleBoxTexture.new();style.texture=preload("res://assets/camp/camp_atlas.png")
	style.content_margin_left=48;style.content_margin_right=48;style.content_margin_top=30;style.content_margin_bottom=30
	book.add_theme_stylebox_override("panel",style)
	var row := HBoxContainer.new();row.add_theme_constant_override("separation",60);book.add_child(row)
	for page in [left,right]:
		page.custom_minimum_size=Vector2(460,575);page.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		page.add_theme_font_override("normal_font",preload("res://assets/fonts/Cedarville-Cursive.ttf"))
		page.add_theme_font_size_override("normal_font_size",22)
		page.add_theme_color_override("default_color",Color(.15,.12,.075));page.scroll_active=true
		row.add_child(page)
	game.changed.connect(refresh)
	book.hide()
func refresh() -> void:
	if not opened: return
	var condition := "Fit" if game.condition>=70 else "Tired" if game.condition>=40 else "Weak"
	left.text=Calendar.date_string(game.day)+"\n"+Calendar.weekday(game.day)+" — "+game.weather().capitalize()+"\n\n"+condition+".  %d meals today.\n\n" % game.inventory.meals_today
	left.text+="%d hooks and %.0f yards of line.\n" % [game.inventory.hooks,game.inventory.line_m*1.094]
	for bait in game.inventory.bait:
		if game.inventory.bait[bait]>0: left.text+="%s: %d\n" % [bait.capitalize(),game.inventory.bait[bait]]
	left.text+="\n"
	for entry in game.inventory.journal:
		if entry.day>=game.day-1: left.text+=entry.text+"\n"
	right.text="Season on the North Yuba\nSince June 26, 1848\nDay %d\n\n" % game.day
	for species in game.inventory.catches: right.text+="%d %s taken\n" % [game.inventory.catches[species],species]
	var smoked := 0
	for f in game.inventory.fish+game.inventory.cache:
		if f.state=="smoked": smoked+=1
	right.text+="\n%d smoked fish in store\n%d fish in the cache\n%.2f ounces of gold\n$%.2f in coin\n%d hooks lost\n\nPrices\n____________________\n____________________" % [smoked,game.inventory.cache.size(),get_node("/root/Sack").ounces,game.dollars,game.inventory.hooks_lost]
func open_book() -> void:
	opened=true;book.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;refresh()
func close_book() -> void:
	opened=false;book.hide();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func _input(event: InputEvent) -> void:
	if not opened: return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"): close_book()
	# Consume gameplay keys, while leaving mouse/scroll input to the book.
	if event is InputEventKey or event is InputEventJoypadButton: get_viewport().set_input_as_handled()
