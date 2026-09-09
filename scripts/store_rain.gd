extends "res://scripts/rain.gd"
func _ready() -> void:
	super._ready()
	var material:=ShaderMaterial.new();material.shader=load("res://shaders/store_rain.gdshader");particles.process_material=material
var last_overcast := -1.0
func _process(delta: float) -> void:
	super._process(delta)
	if absf(current-last_overcast)>.02:
		last_overcast=current
		daylight.apply(daylight.get_node("Clock").hour_at(daylight.get_node("Clock").elapsed))
