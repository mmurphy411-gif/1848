extends SceneTree
## Compare equal work time at the same ground, without changing the original economy policy.
const River=preload("res://scripts/river_model.gd")
const Mining=preload("res://scripts/mining_model.gd")
const Gold=preload("res://scripts/gold_map.gd")
const Pan=preload("res://scripts/pan_result.gd")
func _initialize() -> void:
	var rows := PackedStringArray(["day,water,slabs_open,crevice_oz,crevice_remaining,rocker_site_z,rocker_oz,hand_pan_oz"])
	var taken := [0.0,0.0];var actions := [0,0];var loads := 0
	var total_rocker := 0.0;var total_pan := 0.0;var max_open := 0
	var tool_seconds := Mining.load_seconds({"pick":true})+Mining.ROCK_SECONDS
	for day in 133:
		var level := River.level(day,1848)
		var open := 0;var found := 0.0
		for i in 2:
			if Mining.exposed(i,level):
				open+=1
				var result := Mining.crevice(i,1848,taken[i],actions[i])
				taken[i]+=result;actions[i]+=1;found+=result
		max_open=maxi(max_open,open)
		var p := Vector3(0,0,River.shore_z(0,level)+.6)
		var rocker_oz := 0.0;var pan_oz := 0.0
		if Mining.rocker_site(p,level):
			rocker_oz=Mining.rocker_yield(p,1848,loads);loads+=1
			var rng := RandomNumberGenerator.new();rng.seed=1848+day
			for i in int(tool_seconds/14.0): pan_oz+=Pan.roll(Gold.density_at(p.x,p.z),rng).ounces
		total_rocker+=rocker_oz;total_pan+=pan_oz
		rows.append("%d,%.3f,%d,%.5f,%.5f,%.3f,%.5f,%.5f" % [day,level,open,found,Mining.reserve(0,1848)+Mining.reserve(1,1848)-taken[0]-taken[1],p.z,rocker_oz,pan_oz])
	FileAccess.open("res://artifacts/season-tools.csv",FileAccess.WRITE).store_string("\n".join(rows))
	var result := {"rocker_oz":total_rocker,"same_time_pan_oz":total_pan,"crevice_oz":taken[0]+taken[1],"max_open_slabs":max_open,"loads":loads,"seconds_per_work_session":tool_seconds}
	FileAccess.open("res://artifacts/season-tools.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("TOOLS SEASON ",result)
	quit(0 if total_rocker>total_pan and max_open==2 and taken[0]+taken[1]>0 else 1)
