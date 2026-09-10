extends SceneTree
const M=preload("res://scripts/expedition_model.gd")
var failures: Array[String]=[]
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func _initialize() -> void:
	var state:=M.initial()
	check(not M.bear_claims(state,80,6) and M.bear_claims(state,81,6) and M.bear_claims(state,127,6) and not M.bear_claims(state,128,6),"run boundaries")
	check(not M.bear_claims(state,99,8),"dawn ends")
	state.bear_driven_day=99
	check(not M.raid_due(state,99) and M.raid_due(state,100),"shout lasts the day")
	state.bear_dead=true;check(not M.raid_due(state,100),"bear stays gone")
	var food:=M.food("salmon",15.37,99);var mass:=0.0
	for portion in food: mass+=portion.weight_lb
	check(food.size()==16 and is_equal_approx(mass,15.37),"mass and meals preserved")
	food.append({"species":"beans","weight_lb":.5})
	var raid:=M.raid_food(food)
	check(raid.kept.size()==1 and is_equal_approx(raid.lost_lb,15.37) and food.size()==17,"raid takes animal food without mutating input")
	var fit:=0;var weak:=0
	for attempt in 1000:
		var w:=M.salmon_weight(1848,99,attempt)
		check(w>=10 and w<=20 and w==M.salmon_weight(1848,99,attempt),"salmon bounds and replay")
		if M.shot(1848,99,attempt,100,15,3): fit+=1
		if M.shot(1848,99,attempt,5,15,3): weak+=1
	check(fit>weak+200,"condition affects steadiness")
	print("EXPEDITION MODELS ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
