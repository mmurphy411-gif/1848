extends RefCounted
const MONTHS := ["June", "July", "August", "September", "October", "November", "December"]
const LENGTHS := [30,31,31,30,31,30,31]
static func date(day: int) -> Vector2i:
	var d := maxi(0,day)+26
	var m := 0
	while m<6 and d>LENGTHS[m]:
		d-=LENGTHS[m]
		m+=1
	return Vector2i(m+6,d)
static func month(day: int) -> int: return date(day).x
static func day_of_month(day: int) -> int: return date(day).y
static func date_string(day: int) -> String:
	var d := date(day)
	return "%s %d, 1848" % [MONTHS[d.x-6],d.y]
static func weekday(day: int) -> String:
	return ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"][posmod(day,7)]
static func salmon_run(day: int) -> bool: return day>=81 and day<=127
static func salmon_intensity(day: int) -> float:
	if not salmon_run(day): return 0.0
	return lerpf(.15,1.0,1.0-absf(float(day-99))/(18.0 if day<=99 else 28.0))
