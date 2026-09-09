extends SceneTree
## Each action spends the same real seconds as its live counterpart.
const Calendar=preload("res://scripts/calendar.gd")
const Weather=preload("res://scripts/weather.gd")
const Fishery=preload("res://scripts/fishery.gd")
const Fight=preload("res://scripts/fight_model.gd")
const Rules=preload("res://scripts/fishing_rules.gd")
const Cooking=preload("res://scripts/cooking.gd")
const Condition=preload("res://scripts/condition_model.gd")
const Gold=preload("res://scripts/gold_map.gd")
const Pan=preload("res://scripts/pan_result.gd")
const Layout=preload("res://scripts/claim_layout.gd")
const Prices=preload("res://scripts/prices.gd")
const Pack=preload("res://scripts/pack.gd")
const SECONDS_PER_HOUR := 1200.0/(20.5-4.75)
var game: Node
var sack: Node
var counter: Node
var rows := ""
var seconds := 0.0
var point := Vector2(0,14)
var rng:=RandomNumberGenerator.new()
var catches: Array[Dictionary]=[]
var fire := 0.0
var smoking: Dictionary={}
var smoke_time := 0.0
var meals := 0
var dry_salt := false
func row(action: String,item := "",amount := 0.0,spot := "camp") -> void:
    assert(seconds<=1200.00001,"daily time budget exceeded")
    rows+='%d,"%s",%s,%.3f,%s,%s,%s,%.4f,%.5f,%.5f,%.1f\n' % [game.day,Calendar.date_string(game.day),game.weather(),4.75+seconds/SECONDS_PER_HOUR,action,spot,item,amount,sack.ounces,game.dollars,game.condition]
func spend(duration: float) -> bool:
    if seconds+duration>1200: return false
    seconds+=duration
    var lit:=minf(fire,duration/SECONDS_PER_HOUR)
    fire=maxf(0,fire-duration/SECONDS_PER_HOUR)
    if not smoking.is_empty():
        smoke_time+=lit
        if smoke_time>=4:
            smoking.state="smoked";game.inventory.fish.append(smoking);smoking={};row("smoked")
    return true
func walk(to: Vector2) -> bool:
    var duration:=point.distance_to(to)/2.4
    if not spend(duration): return false
    point=to;row("walk","",duration,str(to));return true
func food_portions() -> int:
    var count:=floori(game.inventory.goods.flour/.5)+floori(game.inventory.goods.pork/.5)+floori(game.inventory.goods.beans)*3
    for f in game.inventory.fish: count+=1 if f.state=="smoked" or f.get("cooked",false) else Cooking.portions(f.weight_lb)
    return count
func tend(required: float) -> bool:
    if fire>=required: return true
    if not walk(Vector2(0,14)): return false
    while fire<required:
        var cost:=1 if fire>0 else 3
        if game.inventory.firewood<cost or not spend(2): return false
        game.inventory.firewood-=cost;fire=minf(4,fire+1) if fire>0 else 2;row("tend","wood",cost)
    return true
func meal() -> bool:
    if not walk(Vector2(0,14)): return false
    for i in game.inventory.fish.size():
        var f: Dictionary=game.inventory.fish[i]
        if f.state=="smoked" or f.get("cooked",false):
            if not spend(3): return false
            game.inventory.fish.remove_at(i);game.condition=Condition.eat(game.condition,f.state=="smoked");meals+=1;row("eat",f.species);return true
        if fire>=1.0/3 and spend(SECONDS_PER_HOUR/3):
            game.inventory.fish.remove_at(i)
            if Cooking.portions(f.weight_lb)>1: f.cooked=true;game.inventory.fish.append(f)
            game.condition=Condition.eat(game.condition);meals+=1;row("fry",f.species);return true
    for recipe in ["pork","biscuits","beans"]:
        if Cooking.can_cook(recipe,game.inventory.goods,fire,4.75+seconds/SECONDS_PER_HOUR,false):
            if not spend(Cooking.RECIPES[recipe].hours*SECONDS_PER_HOUR): return false
            for item in Cooking.RECIPES[recipe].needs: game.inventory.goods[item]-=Cooking.RECIPES[recipe].needs[item]
            for i in int(Cooking.RECIPES[recipe].portions)-1: game.inventory.fish.append({"species":recipe,"weight_lb":.5,"day":game.day,"state":"fresh","cooked":true,"keeps_until":game.day+2})
            game.condition=Condition.eat(game.condition);meals+=1;row("cook",recipe);return true
    return false
func fish_session(limit: float) -> void:
    var end:=minf(seconds+limit,1200)
    while seconds<end-8 and game.inventory.hooks>0 and game.inventory.line_m>=6:
        var hour:=4.75+seconds/SECONDS_PER_HOUR
        var bait: String="hellgrammite" if hour<8 else "grasshopper" if game.weather()!="rain" else "worm"
        if not spend(2): return
        if rng.randf()>.7: row("gather_failed",bait);continue
        row("gather",bait,1)
        var best: Dictionary={};var rate:=0.0
        for spot in Fishery.spots():
            var value:=Fishery.bite_rate("trout",spot,game.day,hour,bait,game.seed,"auto",catches)
            if roundi(Fishery.presence("trout",spot,game.day,hour,game.seed,"auto",catches))<1: continue
            if value>rate: rate=value;best=spot
        if best.is_empty(): return
        var bank:=Vector2(best.position.x,Layout.shore_z(best.position.x)+.3)
        if not walk(bank): return
        var cast:=Vector3(best.position.x,0,best.position.y)
        if rng.randf()<Rules.snag_chance(cast,bait):
            if not spend(2.7): return
            if rng.randf()<.5: game.inventory.hooks-=1;game.inventory.line_m=maxf(0,game.inventory.line_m-2);row("hook_lost")
            continue
        var wait: float=-log(maxf(.00001,rng.randf()))/maxf(.00001,rate)
        if seconds+wait+3.2>end: spend(maxf(0,end-seconds));return
        spend(wait+3.2)
        var weight:=Fishery.roll_weight("trout",rng)
        var fight:=Fight.begin(weight,5.5,rng.randi())
        for frame in 2000:
            var running: bool=fight.elapsed+.02>=fight.run_at and fight.elapsed+.02<fight.run_at+.8
            fight=Fight.step(fight,.02,not running)
            if fight.landed or fight.broken: break
        if not spend(fight.elapsed+4.5): return
        if fight.landed:
            var f:=Cooking.fresh("trout",weight,game.day)
            if Pack.weight(game.inventory)+weight<=40: game.inventory.fish.append(f)
            catches.append({"day":game.day,"spot_index":best.spot_index,"species":"trout"});row("fish","trout",weight,str(best.spot_index))
        else: game.inventory.hooks-=1;game.inventory.line_m=maxf(0,game.inventory.line_m-2);row("hook_lost")
func pan_one(policy: String) -> bool:
    var peaks:=Gold.peak_points()
    peaks.sort_custom(func(a,b):return Gold.density_at(a.x,a.y)>Gold.density_at(b.x,b.y))
    var next: Vector2=peaks[(int(seconds/250))%mini(2,peaks.size())] if policy=="careful" else Vector2(12,Layout.shore_z(12)-.5) if policy=="spendthrift" else peaks[0]
    if not walk(next): return false
    if not spend(11.0/Condition.speed(game.condition)): return false
    var result:=Pan.roll(Gold.density_at(point.x,point.y),rng)
    var tier:=Condition.demote(result.tier,game.condition,rng.randf())
    if tier<result.tier:
        result.ounces=0 if tier==0 else rng.randf_range(Pan.SPECKS.x,Pan.SPECKS.y) if tier==1 else rng.randf_range(Pan.COLOR.x,Pan.COLOR.y) if tier==2 else rng.randf_range(Pan.GOOD.x,Pan.GOOD.y)
    sack.ounces+=result.ounces;row("pan","gold",result.ounces,str(point));return true
func shop(policy: String) -> Dictionary:
    counter.begin_visit()
    # Pack a real lunch, paying for both skillet batches if none is carried.
    if policy=="careful" and not game.inventory.fish.any(func(f):return f.state=="smoked" or f.get("cooked",false)) and game.inventory.goods.flour>=1 and game.inventory.goods.salt>=.04:
        if tend(.5) and spend(.5*SECONDS_PER_HOUR):
            game.inventory.goods.flour-=1;game.inventory.goods.salt-=.04;game.condition=Condition.eat(game.condition);meals+=1
            game.inventory.fish.append({"species":"biscuits","weight_lb":.5,"day":game.day,"state":"fresh","cooked":true,"keeps_until":game.day+2});row("cook","biscuits",2)
    var trail_ate:=false
    for i in game.inventory.fish.size():
        var f: Dictionary=game.inventory.fish[i]
        if f.state=="smoked" or f.get("cooked",false):
            game.inventory.fish.remove_at(i);game.condition=Condition.eat(game.condition,f.state=="smoked");meals+=1;trail_ate=true;row("trail_meal",f.species);break
    # Travel is twelve game hours; no smoking advances while unattended.
    seconds+=12*SECONDS_PER_HOUR;fire=0
    if policy=="careful" and Prices.gold_price(game.day,game.seed)>=15.5:
        var ounces: float=sack.ounces;sack.ounces=0;counter.credit_pour(ounces);row("sell","gold",ounces,"store")
    var wanted: Dictionary={"flour":maxi(0,30-floori(game.inventory.goods.flour)),"salt":maxi(0,3-floori(game.inventory.goods.salt)),"hook":maxi(0,12-game.inventory.hooks),"coffee":1} if policy=="careful" else {"pork":maxi(0,20-floori(game.inventory.goods.pork)),"coffee":maxi(0,10-floori(game.inventory.goods.coffee))}
    var sold_out:=false;var hook_affordable:=false
    for item in wanted:
        for i in int(wanted[item]):
            var message: String=counter.select(item)
            if message=="Sold out": sold_out=true;row("sold_out",item,0,"store")
            if message!="": break
            var funds: float=game.dollars+sack.ounces*Prices.gold_price(game.day,game.seed)*.92
            if counter.total()>funds+.000001: counter.return_last();break
            if item=="hook": hook_affordable=true
    if counter.settle():
        for item in counter.visit.bought: row("buy",item.item,item.count,"store")
    counter.abandon();game.ledger.append(counter.visit.duplicate(true));row("trip","",1,"store")
    return {"trail":trail_ate,"sold_out":sold_out,"hook_affordable":hook_affordable}
func simulate(seed: int,policy: String) -> Dictionary:
    game.seed=seed;game.day=0;game.condition=85;game.dollars=0;game.weather_override="auto"
    game.inventory={"hooks":4,"line_m":20.0,"rod":false,"goods":{"flour":0.0,"beans":0.0,"pork":0.0,"coffee":0.0,"salt":2.0},"fish":[],"bait":{},"firewood":0}
    game.purchases.clear();game.ledger.clear();sack.ounces=0;catches.clear();rng.seed=seed;point=Vector2(0,14);smoking={};fire=0
    rows="day,date,weather,hour,action,spot,item,amount,ounces,dollars,condition\n"
    var trips: Array=[];var trail_meals:=0;var sold_out:=0;var hook_buys:=0;var october_meals:=0;var salt_empty_before_buy:=false;var second_hooks:=false
    for day in 132:
        game.day=day;seconds=0;meals=0
        if policy!="careless":
            if spend(20): game.inventory.firewood+=10;row("gather","wood",10)
            tend(4)
            fish_session(80 if policy=="careful" else 25)
            meal()
            if game.inventory.goods.coffee>=.1 and 4.75+seconds/SECONDS_PER_HOUR<10 and tend(1.0/6) and spend(SECONDS_PER_HOUR/6):
                game.inventory.goods.coffee-=.1;game.condition=minf(100,game.condition+5);row("coffee","coffee",.1)
            var need: bool=game.inventory.hooks<3 or food_portions()<4 or game.inventory.goods.salt<.3
            if (policy=="careful" and need) or (policy=="spendthrift" and day%7==0):
                var visit:=shop(policy);trips.append({"day":day,"flour":Prices.price("flour",day,seed)})
                trail_meals+=1 if visit.trail else 0;sold_out+=1 if visit.sold_out else 0
                if trips.size()==2: second_hooks=visit.hook_affordable or game.inventory.hooks>=3
                for bought in counter.visit.bought:
                    if bought.item=="hook": hook_buys+=1
            if game.inventory.goods.salt<.1 and not game.purchases.any(func(p):return p.item=="salt"): salt_empty_before_buy=true
            if smoking.is_empty() and game.inventory.goods.salt>=.1:
                for i in game.inventory.fish.size():
                    var f: Dictionary=game.inventory.fish[i]
                    if f.state=="fresh" and not f.get("cooked",false):
                        smoking=game.inventory.fish.pop_at(i);smoke_time=0;game.inventory.goods.salt-=.1;row("hang","trout",1);break
        while seconds<1000:
            if not smoking.is_empty() and fire<.5: tend(2)
            if not pan_one(policy): break
        if policy!="careless":
            tend(1)
            fish_session(minf(100,1200-seconds-30))
            meal()
        if meals<1: game.condition=Condition.missed(game.condition)
        if meals<2: game.condition=Condition.missed(game.condition)
        if day>=97 and day<=127 and meals>=2: october_meals+=1
        game.inventory.fish=game.inventory.fish.filter(func(f):return not Cooking.spoiled(f,day))
        smoking={};row("end_day")
    return {"rows":rows,"value":game.dollars+sack.ounces*Prices.gold_price(132,seed),"ounces":sack.ounces,"dollars":game.dollars,"condition":game.condition,"trips":trips,"hook_buys":hook_buys,"second_hooks":second_hooks,"salt_empty_before_buy":salt_empty_before_buy,"sold_out":sold_out,"trail_meals":trail_meals,"october_meals":october_meals}
func _initialize() -> void: run.call_deferred()
func run() -> void:
    game=root.get_node("GameState");sack=root.get_node("Sack");counter=preload("res://scripts/counter.gd").new();root.add_child(counter)
    var results: Dictionary={}
    var summary:="| Policy | Value | Condition | Trips | Hook purchases | Trail meals | October two meals |\n| --- | ---: | ---: | ---: | ---: | ---: | ---: |\n"
    for policy in ["careful","careless","spendthrift"]:
        var result:=simulate(1848,policy);results[policy]=result
        print("SIMULATED ",policy," value=",result.value," trips=",result.trips.size())
        FileAccess.open("res://artifacts/season-"+policy+".csv",FileAccess.WRITE).store_string(result.rows)
        summary+="| %s | $%.2f | %.0f | %d | %d | %d | %d/31 |\n" % [policy,result.value,result.condition,result.trips.size(),result.hook_buys,result.trail_meals,result.october_meals]
    var careful: Dictionary=results.careful
    var failures: Array[String]=[]
    if careful!=simulate(1848,"careful"): failures.append("nondeterministic output")
    if careful==simulate(1849,"careful"): failures.append("seed has no effect")
    if careful.value<=results.careless.value: failures.append("Careful does not end ahead of careless")
    if not careful.second_hooks: failures.append("Careful cannot afford hooks by second trip")
    if results.careless.condition!=5: failures.append("Careless condition not 5")
    if careful.trips.size()<3 or careful.trips.size()>9: failures.append("Careful trips outside 3-9")
    if careful.trips.size()<2 or careful.trips[1].day-careful.trips[0].day<30: failures.append("First two trips less than 30 days apart")
    if careful.trips.size()<2 or absf(careful.trips[1].flour/careful.trips[0].flour-1)<.2: failures.append("First two flour prices differ by less than 20 percent")
    if careful.hook_buys<2: failures.append("Hooks not bought twice")
    if not careful.salt_empty_before_buy: failures.append("Starting salt never exhausted before purchase")
    if results.spendthrift.sold_out==0: failures.append("Spendthrift never encounters sold-out stock")
    if careful.trail_meals*2<careful.trips.size(): failures.append("Trail meals on fewer than half the trips")
    if careful.october_meals<27: failures.append("October two-meal days below 85 percent")
    summary+="\nFindings: "+str(failures)+"\n\nCareful trip dates and flour: "+str(careful.trips)+"\n"
    FileAccess.open("res://artifacts/season-summary.md",FileAccess.WRITE).store_string(summary)
    print(summary)
    print("SEASON ","PASS" if failures.is_empty() else "DESIGN FINDINGS")
    quit(0 if failures.is_empty() else 2)
