extends SceneTree
const Prices=preload("res://scripts/prices.gd")
const Stock=preload("res://scripts/store_stock.gd")
var failures: Array[String]=[]

func check(ok: bool, label: String) -> void:
	if not ok and not label in failures: failures.append(label)

func _initialize() -> void:
	var early:=0.0; var late:=0.0; var maximum_step:=0.0
	for seed in range(1848,1898):
		var previous:=Prices.gold_price(0,seed)
		for day in 133:
			var value:=Prices.gold_price(day,seed)
			check(value>=12 and value<=18,"gold bounds")
			check(value==Prices.gold_price(day,seed),"determinism")
			maximum_step=maxf(maximum_step,absf(value-previous))
			check(absf(value-previous)<=.75,"gold daily step")
			previous=value
			if day<=30: early+=value/(50*31)
			if day>=100: late+=value/(50*33)
		var sale:=Prices.credit(2,30,seed)
		check(is_equal_approx(sale.weighed,1.84) and is_equal_approx(sale.dollars,1.84*Prices.gold_price(30,seed)),"thumb")
		check(Prices.price("flour",0,seed)>=.09 and Prices.price("flour",0,seed)<=.11,"June flour")
		check(Prices.price("flour",97,seed)>=.37 and Prices.price("flour",97,seed)<=.43,"October flour")
	check(early>=15.3 and early<=16.7,"early gold mean")
	check(late>=13.3 and late<=14.7,"late gold mean")
	var sale_items: Array[String]=[]
	for good in Stock.catalogue():
		check(good.base_price>0 and good.unit!="" and good.pounds_per_unit>=0,"catalogue fields")
		if good.for_sale: sale_items.append(good.item)
		var previous_mean:=0.0
		for checkpoint in Prices.CHECKPOINTS:
			var mean:=0.0
			for seed in range(1848,1898):
				var value:=Prices.index(checkpoint[0],seed,good.item)
				check(absf(value/float(checkpoint[1])-1)<=.080001,"index checkpoints")
				mean+=value/50
			check(mean>previous_mean,"index mean rises"); previous_mean=mean
		for day in 133:
			check(Stock.stock(good.item,day,1848)==Stock.stock(good.item,day,1848),"stock deterministic")
	check(sale_items==["hook","line","rod","flour","beans","pork","coffee","salt","crowbar","pick","shovel","boots","rocker","spear","rifle","powder","tent"],"Phase 2 releases expedition goods")
	check(Stock.stock("hook",0)==24 and Stock.stock("hook",3)==48,"hook shipments")
	check(Stock.stock("hook",5,1848,[{"day":5,"item":"hook","count":30}])==18,"purchases deducted")
	check(Stock.stock("hook",130)==408,"last hook shipment cutoff")
	check(Stock.stock("hook",5,1848,[{"day":6,"item":"hook","count":30}])==48,"future purchases ignored")
	check(Stock.stock("rod",35)==1 and Stock.stock("rod",36)==2,"single rod shipment")
	check(Stock.stock("rod",200,1848,[{"day":36,"item":"rod","count":2}])==0,"rod stays empty")
	check(Stock.stock("line",10,1848,[{"day":4,"item":"line","count":999}])==0,"stock floor")
	var independent:=Stock.catalogue(); independent[0].opening=999
	check(Stock.stock("hook",0)==24,"catalogue callers cannot mutate model")
	check(Prices.gold_price(30,1848)!=Prices.gold_price(30,1849),"seed changes gold")
	check(is_equal_approx(Prices.fish_price(67,1848),.12*Prices.index(67,1848,"smoked_fish")),"fish credit")
	print("M10 PRICE/STOCK MODELS ","PASS" if failures.is_empty() else str(failures),
		"; gold means %.3f / %.3f; maximum daily step %.3f" % [early,late,maximum_step])
	quit(0 if failures.is_empty() else 1)
