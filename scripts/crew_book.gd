extends CanvasLayer
## The outfit's roll book: who is on the bar, at what job, on what terms. Opened
## with C (gamepad Back), or G beside a hand. Terms and jobs change at once; a
## foreman re-sets the jobs each dawn.
const Model=preload("res://scripts/crew_model.gd")
const Calendar=preload("res://scripts/calendar.gd")
const Prices=preload("res://scripts/prices.gd")
const INK:=Color(.16,.12,.07)
const FADED:=Color(.36,.29,.2)
var opened:=false
var book:=PanelContainer.new()
var header:=Label.new()
var summary:=Label.new()
var rows:=VBoxContainer.new()
var focus_id:=""
var cursive:=preload("res://assets/fonts/Cedarville-Cursive.ttf")
var hand_font:=preload("res://assets/fonts/PatrickHand-Regular.ttf")
@onready var game: Node=get_node("/root/GameState")

func _ready() -> void:
	layer=9
	add_child(book);book.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	book.offset_left=-600;book.offset_right=600;book.offset_top=-340;book.offset_bottom=340
	var style:=StyleBoxTexture.new();style.texture=preload("res://assets/camp/camp_atlas.png")
	style.content_margin_left=56;style.content_margin_right=56;style.content_margin_top=34;style.content_margin_bottom=30
	book.add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",6);book.add_child(column)
	header.add_theme_font_override("font",cursive);header.add_theme_font_size_override("font_size",34);header.add_theme_color_override("font_color",INK)
	column.add_child(header)
	summary.add_theme_font_override("font",hand_font);summary.add_theme_font_size_override("font_size",19);summary.add_theme_color_override("font_color",FADED)
	summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(summary)
	var rule:=ColorRect.new();rule.color=Color(INK,.35);rule.custom_minimum_size=Vector2(0,2);column.add_child(rule)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;rows.add_theme_constant_override("separation",4);scroll.add_child(rows)
	var footer:=Label.new();footer.text="C / Esc closes · a foreman re-sets the jobs at dawn · wages are paid each night in coin, then dust"
	footer.add_theme_font_override("font",hand_font);footer.add_theme_font_size_override("font_size",16);footer.add_theme_color_override("font_color",FADED)
	column.add_child(footer)
	book.hide()
	game.crew_changed.connect(func(): if opened: refresh())

func _label(text: String, size := 20, width := 0.0, color := INK) -> Label:
	var l:=Label.new();l.text=text
	l.add_theme_font_override("font",hand_font);l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color)
	if width>0: l.custom_minimum_size.x=width;l.clip_text=true
	l.mouse_filter=Control.MOUSE_FILTER_PASS
	return l

func _button(text: String, action: Callable, width := 0.0) -> Button:
	var b:=Button.new();b.text=text;b.flat=false;b.focus_mode=Control.FOCUS_ALL
	b.add_theme_font_override("font",hand_font);b.add_theme_font_size_override("font_size",18)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: b.add_theme_color_override(state,INK)
	var plain:=StyleBoxFlat.new();plain.bg_color=Color(.55,.44,.28,.18);plain.set_corner_radius_all(4);plain.content_margin_left=8;plain.content_margin_right=8
	var hover:=plain.duplicate();hover.bg_color=Color(.55,.44,.28,.38)
	var focus:=plain.duplicate();focus.bg_color=Color(.55,.44,.28,.3);focus.border_color=Color(INK,.6);focus.set_border_width_all(1)
	b.add_theme_stylebox_override("normal",plain);b.add_theme_stylebox_override("hover",hover);b.add_theme_stylebox_override("pressed",hover);b.add_theme_stylebox_override("focus",focus)
	if width>0: b.custom_minimum_size.x=width
	b.pressed.connect(action)
	return b

func refresh() -> void:
	for child in rows.get_children(): rows.remove_child(child);child.queue_free()
	var crew: Dictionary=game.crew
	var hands: Array=crew.hands
	header.text="%s · the outfit" % (crew.bar_name if crew.bar_name!="" else "The bar")
	var payroll:=0.0
	for h in hands:
		if h.terms=="wages": payroll+=Model.wage(h.id,game.day,game.seed)*(1.5 if h.foreman else 1.0)
	var days: float=Model.provision_days(crew,game.inventory)
	summary.text="%s · %d hands · payroll $%.2f a night · rations for %s · %d pans for %d panning · bunks for %d of %d%s%s\nWashed today %.2f oz · this season %.2f oz · wages paid $%.2f" % [
		Calendar.date_string(game.day),hands.size(),payroll,
		("%.1f days" % days) if days!=INF else "—",
		int(game.inventory.get("pans",0)),hands.filter(func(h): return h.job=="pan").size(),
		int(game.inventory.get("bunks",0))*4,hands.size(),
		" · strongbox" if game.inventory.get("strongbox",false) else "",
		" · no Sunday rest" if crew.sundays else "",
		crew.take_today,crew.take_total,crew.wages_paid]
	if hands.is_empty():
		rows.add_child(_label("No hands yet. Men looking for work wait by the trail above camp; more come as word of the strike spreads.",19,0,FADED))
	for h in hands: rows.add_child(_hand_row(h))
	var arrivals:=Model.applicants(crew,game.day)
	if not arrivals.is_empty():
		rows.add_child(_label("Men at the trail, looking for work",24,0,INK))
		for man in arrivals:
			var row:=HBoxContainer.new();row.add_theme_constant_override("separation",10)
			row.add_child(_label(man.name,21,200))
			row.add_child(_label(man.origin,17,440,FADED))
			row.add_child(_label("asks $%.2f a day" % Model.wage(man.id,game.day,game.seed),18,150,FADED))
			row.add_child(_button("Hire",func(): _hire(man.id),90))
			rows.add_child(row)
	var dam: Dictionary=crew.dam
	var project:="Wing dam · "
	if dam.built: project+="standing since %s. The channel is open to bedrock until the autumn rise." % Calendar.date_string(int(dam.day))
	else:
		var blocker: String=Model.dam_blocker(crew,game.inventory,game.water_level())
		project+="%d%% built · %s" % [roundi(100*float(dam.progress)/Model.DAM_HOURS),"set men to building it" if blocker=="" else blocker+(" · five hands, pick, shovel and timber from Lambert's, at low water" if hands.size()<5 or blocker!="" else "")]
	rows.add_child(_label(project,18,0,FADED))
	var sunday:=CheckBox.new();sunday.text="Work Sundays (the men will resent it)";sunday.button_pressed=crew.sundays
	sunday.add_theme_font_override("font",hand_font);sunday.add_theme_font_size_override("font_size",18);sunday.add_theme_color_override("font_color",INK)
	sunday.toggled.connect(func(on): game.crew.sundays=on;refresh())
	rows.add_child(sunday)

func _hand_row(h: Dictionary) -> Control:
	var man:=Model.roster_entry(h.id)
	var row:=VBoxContainer.new();row.add_theme_constant_override("separation",0)
	var line:=HBoxContainer.new();line.add_theme_constant_override("separation",10);row.add_child(line)
	line.add_child(_button("★" if h.foreman else "☆",func(): Model.set_foreman(game.crew,h.id);_changed(),40))
	var name:=_label(man.name+(" · foreman" if h.foreman else ""),21,250)
	if h.id==focus_id: name.add_theme_color_override("font_color",Color(.45,.18,.05))
	line.add_child(name)
	var jobs:=OptionButton.new();jobs.custom_minimum_size.x=170;jobs.focus_mode=Control.FOCUS_ALL
	jobs.add_theme_font_override("font",hand_font);jobs.add_theme_font_size_override("font_size",18)
	for job in Model.JOBS: jobs.add_item(Model.JOB_NAMES[job])
	jobs.selected=Model.JOBS.find(h.job)
	jobs.item_selected.connect(func(i): h.job=Model.JOBS[i];_changed())
	line.add_child(jobs)
	var reason: String=Model.job_ready(game.crew,h,game.inventory,game.mining,game.water_level())
	line.add_child(_label(reason.capitalize() if reason!="" else Model.mood(h.morale),18,150,Color(.5,.16,.08) if reason!="" or h.morale<40 else FADED))
	var arrears: float=h.get("arrears",0.0)
	if arrears>0: line.add_child(_label("owed $%.2f" % arrears,16,0,Color(.5,.16,.08)))
	var terms:="On shares · keeps %d%%" % roundi(Model.SHARE*100) if h.terms=="shares" else "Wages $%.2f" % (Model.wage(h.id,game.day,game.seed)*(1.5 if h.foreman else 1.0))
	line.add_child(_button(terms,func(): h.terms="shares" if h.terms=="wages" else "wages";_changed(),190))
	line.add_child(_label("%.2f oz today" % h.take_today,17,110,FADED))
	line.add_child(_button("Let go",func(): _dismiss(h.id),80))
	var notes:=_label("%s%s · %s" % [man.origin,", teetotal" if man.get("teetotal",false) else "",_skills(man)],15,0,FADED)
	row.add_child(notes)
	return row

func _skills(man: Dictionary) -> String:
	var good: Array=[]
	for job in man.skills:
		if float(man.skills[job])>=1.15: good.append({"pan":"a fine hand with a pan","rocker":"strong on the cradle","crevice":"knows bedrock","fish":"a born fisherman","cook":"can cook","haul":"good with a pack"}[job])
	return ", ".join(good) if not good.is_empty() else "a willing worker"

func _changed() -> void:
	Model.assign_spots(game.crew,game.water_level())
	game.crew_changed.emit()
	refresh()

func _hire(id: String) -> void:
	if Model.hire(game.crew,id,game.day):
		game.event("Hired %s at $%.2f a day." % [Model.roster_entry(id).name,Model.wage(id,game.day,game.seed)])
	_changed()

func _dismiss(id: String) -> void:
	game.event("Let %s go." % Model.roster_entry(id).name)
	Model.dismiss(game.crew,id)
	_changed()

func open_book(id := "") -> void:
	focus_id=id
	var ledger:=get_parent().get_node_or_null("Ledger")
	if ledger and ledger.opened: ledger.close_book()
	opened=true;book.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;refresh()

func close_book() -> void:
	opened=false;book.hide();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("crew") and not event.is_echo():
		if opened: close_book()
		elif get_parent().get_node("Activities").idle(): open_book()
		else: return
		get_viewport().set_input_as_handled();return
	if not opened: return
	if event.is_action_pressed("ui_cancel"): close_book();get_viewport().set_input_as_handled();return
	# Gameplay keys stay with the book; arrows, Enter and the mouse drive the controls.
	if event is InputEventKey and event.physical_keycode in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_E,KEY_F,KEY_G,KEY_T,KEY_P]:
		get_viewport().set_input_as_handled()
