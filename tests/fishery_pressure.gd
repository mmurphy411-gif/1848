extends SceneTree
const Fishery=preload("res://scripts/fishery.gd")
const Fight=preload("res://scripts/fight_model.gd")
const Rules=preload("res://scripts/fishing_rules.gd")
func _initialize() -> void:
	var catches: Array=[{"day":20,"spot_index":1,"species":"trout"},{"day":20,"spot_index":1,"species":"trout"}]
	assert(is_equal_approx(Fishery.pressure("trout",1,20,catches),.4))
	catches.append({"day":20,"spot_index":1,"species":"trout"})
	assert(is_equal_approx(Fishery.pressure("trout",1,20,catches),.15))
	assert(Fishery.pressure("trout",1,26,catches)==1)
	assert(Fishery.pressure("sucker",1,20,catches)==1)
	assert(Fishery.pressure("trout",0,20,catches)==1)
	assert(Fishery.pressure("trout",1,19,catches)==1)
	assert(Fishery.season_factor("trout",95)==1)
	assert(is_equal_approx(Fishery.season_factor("trout",120),.45))
	assert(is_equal_approx(Fishery.season_factor("trout",132),.35))
	var spots := Fishery.spots()
	for i in spots.size():
		assert(spots[i].spot_index==i)
		if spots[i].type=="pool": assert(spots[i].depth>=.8 and spots[i].depth<=1.6)
	var population := Fishery.expected_population(20,19,1848,"clear",catches)
	var remaining := 0
	for fish in population:
		if fish.spot.spot_index==1 and fish.species=="trout": remaining+=1
	assert(remaining<=1)
	assert(Fishery.bite_rate("trout",spots[1],20,19,"grasshopper",1848,"clear",catches)<Fishery.bite_rate("trout",spots[1],20,19,"grasshopper",1848,"clear"))
	var intervals: Array=[]
	for seed in 50:
		var f := Fight.begin(1,6,seed)
		var previous: float=f.run_at
		f.elapsed=previous+.8
		f=Fight.step(f,.01,false)
		var interval: float=f.run_at-previous
		assert(interval>=2 and interval<=4)
		intervals.append(interval)
	assert(intervals.min()!=intervals.max())
	assert(Rules.snag_chance(Vector3(0,0,-20),"grasshopper")==0)
	assert(Rules.snag_chance(Vector3(0,0,-20),"worm")==Rules.SUNK_SNAG_CHANCE)
	assert(Rules.snag_chance(Vector3(-14,0,-4.3),"grasshopper")==.25)
	print("FISHERY PRESSURE PASS: local catches, recovery, season, depths, population, seeded runs and snag geometry")
	quit()
