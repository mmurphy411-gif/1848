extends RefCounted
## Season-owned encounters. Random outcomes are local to one dated action.
const Calendar=preload("res://scripts/calendar.gd")
static func initial() -> Dictionary:
	return {"salmon_taken":{},"bear_dead":false,"bear_driven_day":-1,"raided_day":-1,"deer_dead":[],"deer_spooked_until":-1,"shots":0,"hides_sold":0,"carcasses":[]}
static func salmon_weight(seed: int, day: int, attempt: int) -> float:
	var rng:=RandomNumberGenerator.new();rng.seed=seed+day*7919+attempt*104729
	return snappedf(rng.randf_range(10,20),.01)
static func bear_claims(state: Dictionary, day: int, hour: float) -> bool:
	return Calendar.salmon_run(day) and not state.bear_dead and state.bear_driven_day!=day and hour>=4.75 and hour<8
static func raid_due(state: Dictionary, day: int) -> bool:
	return Calendar.salmon_run(day) and not state.bear_dead and state.bear_driven_day!=day and state.raided_day!=day
static func raid_food(food: Array) -> Dictionary:
	var kept: Array=[];var lost:=0.0
	for item in food:
		if item.species in ["trout","salmon","sucker","pikeminnow","hardhead","venison","bear meat"]: lost+=float(item.weight_lb)
		else: kept.append(item.duplicate(true))
	return {"kept":kept,"lost_lb":lost}
static func food(species: String, weight: float, day: int) -> Array:
	# A large fish or dressed carcass becomes edible one-pound portions, preserving mass.
	var result: Array=[];var remaining:=weight
	while remaining>.00001:
		var amount:=minf(1,remaining)
		result.append({"species":species,"weight_lb":amount,"day":day,"state":"fresh"})
		remaining-=amount
	return result
static func shot(seed: int, day: int, attempt: int, condition: float, distance: float, aim: float) -> bool:
	var rng:=RandomNumberGenerator.new();rng.seed=seed+day*7919+attempt*65537
	var chance:=clampf((.48+.47*condition/100.0)*clampf(aim/2.5,0,1)-maxf(0,distance-12)*.014,.05,.95)
	return rng.randf()<chance
