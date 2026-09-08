extends SceneTree
const Calendar=preload("res://scripts/calendar.gd")
const Weather=preload("res://scripts/weather.gd")
const Fishery=preload("res://scripts/fishery.gd")
const Condition=preload("res://scripts/condition_model.gd")
const Cooking=preload("res://scripts/cooking.gd")
const Fight=preload("res://scripts/fight_model.gd")
func _initialize() -> void:
	assert(Calendar.date_string(0)=="June 26, 1848")
	assert(Calendar.date_string(132)=="November 5, 1848")
	assert(not Calendar.salmon_run(80) and Calendar.salmon_run(81) and Calendar.salmon_run(127) and not Calendar.salmon_run(128))
	var counts: Dictionary={}
	for spot in Fishery.spots():
		assert(spot.depth>=.6)
		counts[spot.type]=counts.get(spot.type,0)+1
		assert(Fishery.presence("trout",spot,20,19,1848)==Fishery.presence("trout",spot,20,19,1848))
	assert(counts.pool>=4 and counts.seam==2 and counts.run==2)
	var spot: Dictionary=Fishery.spots()[1]
	assert(Fishery.presence("trout",spot,20,19,1848,"clear")>2*Fishery.presence("trout",spot,20,13,1848,"clear"))
	var mean := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed=1848
	for i in 200: mean+=-log(maxf(.00001,rng.randf()))/Fishery.bite_rate("trout",spot,20,19,"grasshopper",1848,"clear")/200
	assert(mean>=15 and mean<=40)
	for day in [0,60,95,130]:
		for hour in 24: assert(Fishery.expected_population(day,hour,1848).size()<=24)
	var rains:=0
	for seed in 50:
		for day in range(36,67):
			if Weather.state(day,seed)=="rain": rains+=1
	assert(float(rains)/1550>.03 and float(rains)/1550<.08)
	assert(Condition.speed(85)==1 and is_equal_approx(Condition.speed(40),.77))
	assert(Condition.missed(5)==5 and Cooking.portions(2.5)==2)
	var f := Fight.begin(1,6,0)
	for i in 1200:
		var run_next: bool=f.elapsed+.01>=f.run_at and f.elapsed+.01<f.run_at+.8
		f=Fight.step(f,.01,not run_next)
		if f.landed: break
	assert(f.landed and not f.broken and f.elapsed>=3 and f.elapsed<=8)
	print("M9 MODELS PASS; mean bite %.2fs; rain %.2f%%; 1lb fight %.2fs" % [mean,100.0*rains/1550,f.elapsed])
	quit()
