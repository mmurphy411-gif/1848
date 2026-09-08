extends SceneTree
const Calendar=preload("res://scripts/calendar.gd")
const Weather=preload("res://scripts/weather.gd")
const Fishery=preload("res://scripts/fishery.gd")
const Condition=preload("res://scripts/condition_model.gd")
const Cooking=preload("res://scripts/cooking.gd")
const Fight=preload("res://scripts/fight_model.gd")
# A diagnostic stock of hooks/line is supplied, as by F4, until milestone 10.
# Otherwise the required 8–20 losses cannot be exercised with four starting hooks.
const SNAG_EXPOSURE := .16
func simulate(seed: int,careful: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new();rng.seed=seed
	var condition := 85.0
	var stock := 0
	var losses := 0
	var fit_days := 0
	var species_counts: Dictionary={}
	var rows := "day,date,weather,hour,spot,species,weight,hooks_lost,meals,condition\n"
	var november_stock := 0
	var first_salmon := -1
	var last_salmon := -1
	var pool: Dictionary=Fishery.spots()[1]
	for day in 130:
		var weather := Weather.state(day,seed)
		var meals := 0
		if Calendar.salmon_run(day): last_salmon=day;if first_salmon<0: first_salmon=day
		if careful:
			for hour in [6.0,19.0]:
				var bait_count := 0
				for attempt in (4 if hour==6 or weather=="rain" else 6):
					if rng.randf()<.7: bait_count+=1
				var remaining := 1200.0/(20.5-4.75) # one game hour per session
				var catches: Array=[]
				while remaining>0 and bait_count>0:
					bait_count-=1
					var bait := "hellgrammite" if hour==6 else "worm" if weather=="rain" else "grasshopper"
					var rate := Fishery.bite_rate("trout",pool,day,hour,bait,seed)
					var wait := -log(maxf(.00001,rng.randf()))/maxf(.00001,rate)
					remaining-=wait+3.2
					if remaining<=0: break
					# Some casts brush the obstacle's snag band, the same .25/.5
					# snag/free rules used by the live action.
					if rng.randf()<SNAG_EXPOSURE and rng.randf()<.25:
						remaining-=1.5
						if rng.randf()<.5: losses+=1;continue
					var weight := Fishery.roll_weight("trout",rng)
					var fight := Fight.begin(weight,5.5,rng.randi())
					for frame in 2000:
						var next_running: bool=fight.elapsed+.02>=fight.run_at and fight.elapsed+.02<fight.run_at+.8
						fight=Fight.step(fight,.02,not next_running)
						if fight.landed or fight.broken: break
					if not fight.landed: continue
					remaining-=fight.elapsed
					catches.append(Cooking.fresh("trout",weight,day))
					species_counts.trout=species_counts.get("trout",0)+1
					rows+="%d,\"%s\",%s,%.0f,pool,trout,%.3f,%d,%d,%.1f\n" % [day,Calendar.date_string(day),weather,hour,weight,losses,meals,condition]
				if not catches.is_empty():
					condition=Condition.eat(condition);meals+=1
					# Four hours of maintained fire preserve surplus before sleep.
					# One rack slot per session: eight smoking hours plus frying
					# fit the day's nine hours of fire from ten gathered wood.
					stock+=mini(1,catches.size()-1)
				elif stock>0:
					stock-=1;condition=Condition.eat(condition,true);meals+=1
				if hour==6 and meals<1: condition=Condition.missed(condition)
		else: condition=Condition.missed(condition)
		if meals<2: condition=Condition.missed(condition)
		if condition>=60: fit_days+=1
		if day==128: november_stock=stock
		rows+="%d,\"%s\",%s,21,camp,,, %d,%d,%.1f\n" % [day,Calendar.date_string(day),weather,losses,meals,condition]
		if not careful and day>=6: assert(condition==5)
	return {"rows":rows,"hooks_lost":losses,"healthy_days":fit_days,"condition":condition,"smoked_november":november_stock,"species":species_counts,"first_salmon":first_salmon,"last_salmon":last_salmon}
func _initialize() -> void:
	var careful := simulate(1848,true)
	var repeat := simulate(1848,true)
	assert(careful==repeat)
	assert(careful!=simulate(1849,true))
	var careless := simulate(1848,false)
	for pair in [["careful",careful],["careless",careless]]:
		var file := FileAccess.open("res://artifacts/season-"+pair[0]+".csv",FileAccess.WRITE)
		file.store_string(pair[1].rows)
		var summary: Dictionary=pair[1].duplicate();summary.erase("rows")
		print(pair[0],": ",JSON.stringify(summary))
	assert(careful.healthy_days>=117)
	assert(careful.hooks_lost>=8 and careful.hooks_lost<=20)
	assert(careless.condition==5)
	var spot: Dictionary=Fishery.spots()[1]
	var dusk := Fishery.bite_rate("trout",spot,20,19,"grasshopper",1848,"clear")
	var noon := Fishery.bite_rate("trout",spot,20,13,"grasshopper",1848,"clear")
	var rain := Fishery.bite_rate("trout",spot,20,19,"grasshopper",1848,"rain")
	assert(dusk/noon>=1.5 and rain/dusk>=1.4)
	assert(1/dusk>=15 and 1/dusk<=40)
	assert(Calendar.salmon_intensity(99)==1 and Calendar.salmon_intensity(80)==0 and Calendar.salmon_intensity(128)==0)
	print("SEASON SIMULATION PASS; nominal clear dusk wait ",1/dusk)
	quit()
