extends SceneTree
const Calendar=preload("res://scripts/calendar.gd")
const Weather=preload("res://scripts/weather.gd")
const Fishery=preload("res://scripts/fishery.gd")
const Condition=preload("res://scripts/condition_model.gd")
const Cooking=preload("res://scripts/cooking.gd")
const Fight=preload("res://scripts/fight_model.gd")
# A diagnostic stock of hooks/line is supplied, as by F4, until milestone 10.
# Otherwise the required 8–20 losses cannot be exercised with four starting hooks.
const Rules=preload("res://scripts/fishing_rules.gd")
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
	var spots := Fishery.spots()
	var catch_log: Array[Dictionary]=[]
	var october_river_days := 0
	var october_days := 0
	var max_spot_take := 0
	var last_spot: Dictionary={}
	for day in 130:
		var weather := Weather.state(day,seed)
		var meals := 0
		var river_meals := 0
		var daily_take: Dictionary={}
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
					var pool: Dictionary={}
					var rate := 0.0
					var rates: Dictionary={}
					# Preserve the original trout policy, rotating its fishing water.
					for spot in spots:
						var total := 0.0
						var candidates: Dictionary={}
						for species in ["trout"]:
							var value := Fishery.bite_rate(species,spot,day,hour,bait,seed,"auto",catch_log)
							# The live action cannot hook a species with no visible body.
							if roundi(Fishery.presence(species,spot,day,hour,seed,"auto",catch_log))==0: value=0
							if Fishery.pressure(species,spot.spot_index,day,catch_log)<.5: value=0
							candidates[species]=value;total+=value
						if total>rate: rate=total;pool=spot;rates=candidates
					if pool.is_empty(): break
					# Rotation takes real walking time along the bank, at the game's
					# existing 2.4 m/s speed; a landing and reveal take 4.5 s too.
					if not last_spot.is_empty() and last_spot.spot_index!=pool.spot_index:
						remaining-=absf(pool.position.x-last_spot.position.x)/preload("res://scripts/walker.gd").WALK_SPEED
					last_spot=pool
					if remaining<=0: break
					var angle := rng.randf()*TAU
					var scatter := sqrt(rng.randf())*1.5
					var cast_at := Vector3(pool.position.x+cos(angle)*scatter,0,pool.position.y+sin(angle)*scatter)
					if rng.randf()<Rules.snag_chance(cast_at,bait):
						remaining-=1.5
						if rng.randf()<.5: losses+=1;continue
					var wait := -log(maxf(.00001,rng.randf()))/maxf(.00001,rate)
					remaining-=wait+3.2
					if remaining<=0: break
					var species := "trout"
					var roll := rng.randf()*rate
					for name in rates:
						roll-=rates[name]
						if roll<=0 and rates[name]>0: species=name;break
					var weight := Fishery.roll_weight(species,rng)
					var fight := Fight.begin(weight,5.5,rng.randi())
					for frame in 2000:
						var next_running: bool=fight.elapsed+.02>=fight.run_at and fight.elapsed+.02<fight.run_at+.8
						fight=Fight.step(fight,.02,not next_running)
						if fight.landed or fight.broken: break
					if fight.broken: losses+=1
					if not fight.landed: continue
					remaining-=fight.elapsed+4.5
					catches.append(Cooking.fresh(species,weight,day))
					catch_log.append({"day":day,"spot_index":pool.spot_index,"species":species})
					daily_take[pool.spot_index]=daily_take.get(pool.spot_index,0)+1
					max_spot_take=maxi(max_spot_take,daily_take[pool.spot_index])
					species_counts[species]=species_counts.get(species,0)+1
					rows+="%d,\"%s\",%s,%.0f,%d,%s,%.3f,%d,%d,%.1f\n" % [day,Calendar.date_string(day),weather,hour,pool.spot_index,species,weight,losses,meals,condition]
				if not catches.is_empty():
					condition=Condition.eat(condition);meals+=1;river_meals+=1
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
		if day>=97 and day<=127:
			october_days+=1
			if river_meals==2: october_river_days+=1
		if day==128: november_stock=stock
		rows+="%d,\"%s\",%s,21,camp,,, %d,%d,%.1f\n" % [day,Calendar.date_string(day),weather,losses,meals,condition]
		if not careful and day>=6: assert(condition==5)
	return {"rows":rows,"hooks_lost":losses,"healthy_days":fit_days,"condition":condition,"smoked_november":november_stock,"species":species_counts,"first_salmon":first_salmon,"last_salmon":last_salmon,"october_river_days":october_river_days,"october_days":october_days,"max_spot_take":max_spot_take}
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
	if careful.healthy_days<ceil(130*.85):
		print("DESIGN STOP: careful policy healthy on ",careful.healthy_days,"/130 days; pressure constants unchanged")
		quit(2);return
	var failures: Array[String]=[]
	# User ruling, 2026-09-08: plentiful fish are acceptable; fishing consumes
	# minutes that could be spent panning. Retain food floors, remove scarcity caps.
	if careful.species.get("trout",0)<150: failures.append("trout take below 150")
	if careful.smoked_november<5: failures.append("smoked stock below 5")
	if float(careful.october_river_days)/careful.october_days>=.7: failures.append("October river-only meals on at least 70% of days")
	if careful.max_spot_take>3: failures.append("more than three fish from a spot in a day")
	if careful.hooks_lost<8 or careful.hooks_lost>20: failures.append("hook losses outside 8–20")
	assert(careless.condition==5)
	var spot: Dictionary=Fishery.spots()[1]
	var dusk := Fishery.bite_rate("trout",spot,20,19,"grasshopper",1848,"clear")
	var noon := Fishery.bite_rate("trout",spot,20,13,"grasshopper",1848,"clear")
	var rain := Fishery.bite_rate("trout",spot,20,19,"grasshopper",1848,"rain")
	assert(dusk/noon>=1.5 and rain/dusk>=1.4)
	assert(1/dusk>=15 and 1/dusk<=40)
	assert(Calendar.salmon_intensity(99)==1 and Calendar.salmon_intensity(80)==0 and Calendar.salmon_intensity(128)==0)
	print("SEASON SIMULATION ","PASS" if failures.is_empty() else "DESIGN STOP: "+str(failures),"; nominal clear dusk wait ",1/dusk)
	quit(0 if failures.is_empty() else 1)
