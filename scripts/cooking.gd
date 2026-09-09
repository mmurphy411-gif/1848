extends RefCounted
const RECIPES := {"fried":{"hours":1.0/3.0,"fire":true},"smoked":{"hours":4.0,"fire":true},"biscuits":{"hours":.25,"needs":{"flour":.5,"salt":.02},"portions":1,"utensil":"Skillet"},"beans":{"hours":2.0,"needs":{"beans":1.0,"salt":.05},"portions":3,"utensil":"Pot"},"pork":{"hours":1.0/6.0,"needs":{"pork":.5},"portions":1,"utensil":"Skillet"},"coffee":{"hours":1.0/6.0,"needs":{"coffee":.1},"portions":0,"utensil":"Pot"}}
static func portions(weight: float) -> int: return 2 if weight>=2 else 1
static func spoiled(fish: Dictionary, ending_day: int) -> bool:
	if fish.has("keeps_until"): return ending_day>=int(fish.keeps_until)
	return fish.state=="fresh" and (int(fish.day)<ending_day or fish.get("cooked",false))
static func can_cook(recipe: String,goods: Dictionary,fire_hours: float,hour: float,coffee_today: bool) -> bool:
	if not RECIPES.has(recipe) or not RECIPES[recipe].has("needs"): return false
	if fire_hours<RECIPES[recipe].hours: return false
	if recipe=="coffee" and (hour>=10 or coffee_today): return false
	for item in RECIPES[recipe].needs:
		if goods.get(item,0)+.000001<RECIPES[recipe].needs[item]: return false
	return true
static func fresh(species: String, weight: float, day: int) -> Dictionary:
	return {"species":species,"weight_lb":weight,"day":day,"state":"fresh"}
