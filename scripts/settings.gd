extends Node
## Player preferences, kept in user://settings.cfg and applied at once.
signal changed
const PATH:="user://settings.cfg"
const DAY_LENGTHS:={"Leisurely · 20 min":1.0,"Brisk · 12 min":1.6667,"Hurried · 6 min":3.3333}
var values:={"mouse_sensitivity":1.0,"invert_y":false,"master":1.0,"ambience":1.0,"foley":1.0,"music":.8,
	"day_length":"Leisurely · 20 min","fullscreen":false,"show_clock":false}

func _ready() -> void:
	var file:=ConfigFile.new()
	if file.load(PATH)==OK:
		for key in values: values[key]=file.get_value("settings",key,values[key])
	if not DAY_LENGTHS.has(values.day_length): values.day_length="Leisurely · 20 min"
	apply()

func get_value(key: String): return values.get(key)

func set_value(key: String, value) -> void:
	values[key]=value
	apply()
	var file:=ConfigFile.new()
	for k in values: file.set_value("settings",k,values[k])
	file.save(PATH)

## Game-clock multiplier for the chosen day length.
func day_rate() -> float: return DAY_LENGTHS.get(values.day_length,1.0)

func apply() -> void:
	for bus in ["Master","Ambience","Foley","Music"]:
		var index:=AudioServer.get_bus_index(bus)
		if index>=0: AudioServer.set_bus_volume_db(index,linear_to_db(maxf(.0001,float(values[bus.to_lower()]))))
	if DisplayServer.get_name()!="headless":
		var mode:=DisplayServer.window_get_mode()
		var full:=mode==DisplayServer.WINDOW_MODE_FULLSCREEN or mode==DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if bool(values.fullscreen)!=full: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	changed.emit()
