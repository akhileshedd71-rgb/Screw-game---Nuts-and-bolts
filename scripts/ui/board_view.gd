class_name BoardView
extends Control
## Presentation only: the reducer owns every removal, route and layer relationship.

signal screw_pressed(screw_id: String)
signal presentation_finished

const Art = preload("res://scripts/ui/craft_draw.gd")
const Reducer = preload("res://scripts/core/puzzle_reducer.gd")
const RELEASE_DURATION := 0.38
# These persisted IDs intentionally survive the Toybox Workshop art update.
const PALETTES := {
	"beech": [Color("ffe09a"),Color("a7e8ed"),Color("c7aff1"),Color("ffbbd4")],
	"walnut": [Color("ba96ed"),Color("d1b9f8"),Color("eca8d9"),Color("afddeb")],
	"rose": [Color("ffaecd"),Color("ffd0e1"),Color("e5b9f1"),Color("ffd2b6")],
	"sage": [Color("97e7e9"),Color("b0f0df"),Color("a8d5f8"),Color("fff0b4")]
}

var input_enabled: bool = true
var reduced_motion: bool = false
var external_screw_flights: bool = false
var skin: String = "beech":
	set(value):
		skin = value
		queue_redraw()
var _level: Dictionary = {}
var _state: Dictionary = {}
var _plates: Array = []
var _screws: Dictionary = {}
var _cache: Dictionary = {}
var _hint: String = ""
var _blueprint: bool = false
var _blueprint_positions: Dictionary = {}
var _released: Dictionary = {}
var _flights: Array = []
var _animation_time: float = RELEASE_DURATION
var _clock: float = 0.0
var _last_press: int = -200

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_process(false)

func configure(level: Dictionary, state: Dictionary) -> void:
	_level = level
	_state = state.duplicate(true)
	_plates = level.get("plates", []).duplicate()
	_plates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if int(a.get("layer",0)) == int(b.get("layer",0)):
			return str(a.id) < str(b.id)
		return int(a.get("layer",0)) < int(b.get("layer",0)))
	_screws.clear()
	_cache.clear()
	for screw in level.get("screws", []):
		_screws[str(screw.id)] = screw
	for plate in _plates:
		_cache[str(plate.id)] = _make_plate_cache(plate)
	_hint = ""
	_blueprint = false
	_released.clear()
	_flights.clear()
	_animation_time = RELEASE_DURATION
	set_process(false)
	queue_redraw()

func update_state(state: Dictionary) -> void:
	_released.clear()
	_flights.clear()
	if not reduced_motion:
		for id in state.get("removed_plate_ids", []):
			if not id in _state.get("removed_plate_ids", []):
				_released[id] = true
		for id in _state.get("remaining_screw_ids", []):
			if not id in state.get("remaining_screw_ids", []) and _screws.has(id):
				_flights.append(_screws[id])
	_state = state.duplicate(true)
	_hint = ""
	_animation_time = 0.0 if not _flights.is_empty() or not _released.is_empty() else RELEASE_DURATION
	set_process(is_animating())
	queue_redraw()

func set_hint(screw_id: String) -> void:
	_hint = screw_id
	set_process(not _hint.is_empty() or is_animating())
	queue_redraw()

func set_blueprint(enabled: bool) -> void:
	_blueprint = enabled
	if enabled:
		_layout_blueprint()
	queue_redraw()

func is_animating() -> bool:
	return _animation_time < RELEASE_DURATION

func _process(delta: float) -> void:
	_clock += delta
	if is_animating():
		_animation_time += delta
		if not is_animating():
			_released.clear()
			_flights.clear()
			presentation_finished.emit()
	queue_redraw()
	if not is_animating() and _hint.is_empty():
		set_process(false)

func _gui_input(event: InputEvent) -> void:
	if not input_enabled or _blueprint or is_animating() or _state.get("status", "") != "ACTIVE":
		return
	var point := Vector2.ZERO
	if event is InputEventScreenTouch:
		if not event.pressed:
			return
		point = event.position
	elif event is InputEventMouseButton:
		if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
			return
		point = event.position
	else:
		return
	var now := Time.get_ticks_msec()
	if now - _last_press < 90:
		return
	var nearest := ""
	# Nearest exposed center disambiguates overlapping 48 dp targets at 360 dp width.
	var closest := 48.0
	for id in _state.get("remaining_screw_ids", []):
		if not _screws.has(id) or not Reducer.is_exposed(_level,_state,id):
			continue
		var screw: Dictionary = _screws[id]
		var distance := point.distance_to(_point(screw.position))
		if distance <= closest:
			nearest = str(id)
			closest = distance
	if nearest.is_empty():
		# A tap directly over a covered fastener can request the reducer's explanation.
		closest = 24.0
		for id in _state.get("remaining_screw_ids", []):
			if not _screws.has(id):
				continue
			var distance := point.distance_to(_point(_screws[id].position))
			if distance <= closest:
				nearest = str(id)
				closest = distance
	if not nearest.is_empty():
		_last_press = now
		accept_event()
		screw_pressed.emit(nearest)

func _draw() -> void:
	_draw_backing()
	if _level.is_empty():
		return
	if _blueprint:
		_draw_blueprint()
		return
	var progress := clampf(_animation_time / RELEASE_DURATION, 0.0, 1.0)
	for plate in _plates:
		var id := str(plate.id)
		var removed: bool = id in _state.get("removed_plate_ids", [])
		if removed and not _released.has(id):
			continue
		var offset := Vector2.ZERO
		var rotation := 0.0
		var opacity := 1.0
		if _released.has(id):
			var direction := -1.0 if id.hash()%2 == 0 else 1.0
			offset = Vector2(direction*progress*24.0, 70.0*progress*progress)
			rotation = direction*progress*0.12
			opacity = 1.0 - smoothstep(0.15,1.0,progress)
		var cache: Dictionary = _cache[id]
		var center: Vector2 = cache.center
		draw_set_transform(center+offset, rotation)
		_draw_plate(plate,cache,opacity)
		for screw_id in plate.get("screw_ids", []):
			if not _screws.has(screw_id):
				continue
			var screw: Dictionary = _screws[screw_id]
			var pos := _point(screw.position)-center
			_draw_hole(pos,opacity)
			if screw_id in _state.get("remaining_screw_ids", []):
				if screw_id == _hint:
					_draw_hint(pos)
				Art.screw(self,pos,str(screw.color_id),24.0,opacity)
		draw_set_transform(Vector2.ZERO)
	for flight in _flights:
		if external_screw_flights:
			continue
		var p := _point(flight.position) + Vector2(0,-82.0*progress)
		var opacity := 1.0-smoothstep(0.35,1.0,progress)
		Art.screw(self,p,str(flight.color_id),24.0*(1.0+sin(progress*PI)*0.18),opacity,progress*PI*1.7)
		for i in range(5):
			var vector := Vector2.from_angle(TAU*i/5.0-PI*0.5)
			draw_circle(p+vector*(20+progress*35),maxf(0.5,2.0*(1-progress)),Color(1.0,0.77,0.23,opacity*0.8),true,-1,true)

func _draw_backing() -> void:
	# A layered, bevelled toy tray frames a quiet play surface; decoration stays at the edge.
	Art.rounded(self,Rect2(4,13,632,585),Color(0.17,0.09,0.31,0.18),34)
	Art.rounded(self,Rect2(3,4,634,586),Color("513180"),34)
	Art.rounded(self,Rect2(5,3,630,578),Color("8051c7"),32)
	Art.rounded(self,Rect2(9,5,622,565),Color("b997f2"),29)
	Art.rounded(self,Rect2(14,9,612,555),Color("dfc8ff"),26)
	Art.rounded(self,Rect2(20,15,600,545),Color("8d62c5"),23)
	Art.rounded(self,Rect2(24,19,592,537),Color("d8c9ed"),20)
	Art.rounded(self,Rect2(27,24,586,527),Color("f5efff"),18)
	Art.rounded(self,Rect2(30,30,580,517),Color("f7f4ff"),16)
	# Subtle embossed polka dots and seams suggest a padded workshop play mat.
	for row in range(12):
		for column in range(13):
			var p := Vector2(48+column*45+(22 if row%2 else 0),47+row*42)
			if p.x < 597:
				draw_circle(p,1.5,Color(0.63,0.48,0.81,0.075),true,-1,true)
	for x in range(57,598,19):
		draw_line(Vector2(x,37),Vector2(x+7,37),Color(0.65,0.51,0.84,0.15),1,true)
		draw_line(Vector2(x,539),Vector2(x+7,539),Color(0.65,0.51,0.84,0.15),1,true)
	for y in range(57,527,19):
		draw_line(Vector2(39,y),Vector2(39,y+7),Color(0.65,0.51,0.84,0.15),1,true)
		draw_line(Vector2(601,y),Vector2(601,y+7),Color(0.65,0.51,0.84,0.15),1,true)
	# Candy enamel corner stars and pinstripe trim unite this with the game's toy scenery.
	for x in [48.0,592.0]:
		for y in [27.0,549.0]:
			Art.sparkle(self,Vector2(x,y+2),14.0,Color("674492"))
			Art.sparkle(self,Vector2(x,y),12.0,Color("ffda70"))
			Art.sparkle(self,Vector2(x-2,y-3),5.0,Color("fff4c4"))
	for x in [250.0,320.0,390.0]:
		draw_circle(Vector2(x,572),5.7,Color("5f389d"),true,-1,true)
		draw_circle(Vector2(x,570),4.6,Color("64e2e8") if x != 320 else Color("ff99c4"),true,-1,true)
		draw_circle(Vector2(x-1.0,568.8),1.7,Color("ffffff"),true,-1,true)
	for side in [0,1]:
		var x := 14.0 if side == 0 else 626.0
		for y in [141.0,288.0,435.0]:
			draw_circle(Vector2(x,y),4.8,Color("dfc8ff"),true,-1,true)
			draw_circle(Vector2(x,y-1),2.6,Color("f9f0ff"),true,-1,true)
	var family := str(_level.get("family","flower"))
	Art.motif(self,Vector2(320,282),family,112,Color(0.65,0.52,0.82,0.095))
	if _state.get("status", "") == "WON":
		draw_circle(Vector2(320,283),136,Color("e5d5fc"),true,-1,true)
		draw_circle(Vector2(320,276),126,Color("ffffff"),true,-1,true)
		Art.motif(self,Vector2(320,276),family,93,Color("9c67d9"))
		for i in range(8):
			var at := Vector2(320,276)+Vector2.from_angle(TAU*i/8.0)*159
			Art.sparkle(self,at,10 if i%2 else 15,Color("ef80b4") if i%2 else Color("fbc956"),PI*0.16*i)

func _draw_plate(plate: Dictionary, cache: Dictionary, opacity: float) -> void:
	var polygon: PackedVector2Array = cache.polygon
	var inset: PackedVector2Array = cache.inset
	var colors: Array = PALETTES.get(skin,PALETTES.beech)
	var col: Color = colors[posmod(int(plate.get("material",0)),4)]
	var edge := col.darkened(0.45).lerp(Color("624277"),0.45)
	_draw_shifted_polygon(polygon,Vector2(3,13),Color(0.22,0.12,0.37,0.07*opacity))
	_draw_shifted_polygon(polygon,Vector2(2,10),Color(0.22,0.12,0.37,0.12*opacity))
	_draw_shifted_polygon(polygon,Vector2(0,6),_alpha(edge,opacity))
	_draw_shifted_polygon(polygon,Vector2(0,3.5),_alpha(col.darkened(0.21),opacity))
	draw_colored_polygon(polygon,_alpha(col.darkened(0.10),opacity))
	if inset.size() >= 3:
		draw_colored_polygon(inset,_alpha(col,opacity))
	# Directional edge highlights are painted into the plate, not the model's geometry.
	for i in range(polygon.size()):
		var a := polygon[i]
		var b := polygon[(i+1)%polygon.size()]
		var edge_vector := b-a
		var highlight: bool = edge_vector.x > 0.01 or (absf(edge_vector.x)<0.01 and edge_vector.y<0)
		draw_line(a,b,_alpha(col.lightened(0.70) if highlight else edge,opacity),2.4,true)
	var outline := polygon.duplicate()
	outline.append(polygon[0])
	draw_polyline(outline,_alpha(edge,opacity*0.95),1.4,true)
	if inset.size() >= 3:
		var rim := inset.duplicate()
		rim.append(inset[0])
		draw_polyline(rim,_alpha(col.lightened(0.68),opacity*0.78),1.6,true)
	# Fine inlaid ribbons replace wood grain; clipped paths remain well inside the true polygon.
	var ribbon_index := 0
	for path in cache.grain:
		if ribbon_index%3 == 0:
			draw_polyline(path,_alpha(col.lightened(0.58),opacity*0.24),2.5,true)
		ribbon_index += 1
	for accent in cache.accents:
		Art.sparkle(self,accent+Vector2(0,1),7.3,_alpha(edge,opacity*0.20),0.18)
		Art.sparkle(self,accent,6.3,_alpha(Color.WHITE,opacity*0.50),0.18)

func _draw_hole(position: Vector2, opacity: float) -> void:
	draw_circle(position+Vector2(0,1.5),11,Color(1,1,1,0.75*opacity),true,-1,true)
	draw_circle(position,9.6,Color(0.32,0.20,0.49,0.7*opacity),true,-1,true)
	draw_circle(position+Vector2(0,1.4),6.8,Color(0.47,0.32,0.61,0.58*opacity),true,-1,true)
	draw_arc(position,8.8,PI,TAU,16,Color(0.24,0.14,0.36,0.4*opacity),2,true)

func _draw_hint(position: Vector2) -> void:
	var pulse := (sin(_clock*4.2)+1.0)*0.5 if not reduced_motion else 0.5
	draw_circle(position,37.0+pulse*4.0,Color(1,0.80,0.29,0.20-pulse*0.07),true,-1,true)
	draw_arc(position,32.0+pulse*3.0,0,TAU,48,Color("ffffff"),5.5,true)
	draw_arc(position,33.5+pulse*3.0,0,TAU,48,Color("f4ad38"),2.5,true)
	for i in range(3):
		var p := position+Vector2.from_angle(-PI*0.60+TAU*i/3.0)*(41.0+pulse*4)
		Art.sparkle(self,p,4.0+pulse*2,Color("ffd056"),_clock*0.2 if not reduced_motion else 0.0)

func _draw_blueprint() -> void:
	Art.rounded(self,Rect2(16,15,608,563),Color("e9edff"),22)
	for x in range(32,624,24):
		draw_line(Vector2(x,24),Vector2(x,570),Color(0.35,0.45,0.73,0.075),1,true)
	for y in range(28,574,24):
		draw_line(Vector2(24,y),Vector2(616,y),Color(0.35,0.45,0.73,0.075),1,true)
	for plate in _plates:
		if str(plate.id) in _state.get("removed_plate_ids", []):
			continue
		var cache: Dictionary = _cache[str(plate.id)]
		var polygon := PackedVector2Array()
		for p in cache.polygon:
			polygon.append(p+cache.center)
		draw_colored_polygon(polygon,Color(0.49,0.53,0.81,0.08))
		polygon.append(polygon[0])
		draw_polyline(polygon,Color(0.49,0.36,0.72,0.42),2,true)
	for screw in _screws.values():
		if not str(screw.id) in _state.get("remaining_screw_ids", []):
			continue
		var point: Vector2 = _blueprint_positions.get(str(screw.id),_point(screw.position))
		var original := _point(screw.position)
		if point.distance_to(original) > 8:
			draw_line(original,point,Color(0.49,0.36,0.72,0.25),1.2,true)
			draw_circle(original,3,Color(0.49,0.36,0.72,0.4),true,-1,true)
		for blocker in screw.get("blocker_plate_ids", []):
			if blocker in _state.get("removed_plate_ids", []) or not _cache.has(blocker):
				continue
			var target: Vector2 = _cache[blocker].center
			var direction := (target-point).normalized()
			var length := (target-point).length()
			for step in range(int(length/10.0)):
				var start := point+direction*step*10
				draw_line(start,start+direction*5,Color(0.47,0.29,0.68,0.65),1.5,true)
			Art.rounded(self,Rect2(target-Vector2(4,4),Vector2(8,8)),Color("9567cf"),2)
	for screw in _screws.values():
		if not str(screw.id) in _state.get("remaining_screw_ids", []):
			continue
		var point: Vector2 = _blueprint_positions.get(str(screw.id),_point(screw.position))
		var exposed := Reducer.is_exposed(_level,_state,str(screw.id))
		draw_circle(point,27,Color(1.0,0.99,1.0,0.96),true,-1,true)
		Art.screw(self,point,str(screw.color_id),22,1.0,0.0,not exposed)
		if not exposed:
			Art.rounded(self,Rect2(point+Vector2(10,12),Vector2(18,18)),Color("e9edff"),5)
			Art.icon(self,point+Vector2(19,20),"lock",9,Color("644690"))

func _layout_blueprint() -> void:
	# Separate coincident stack fasteners so inspection always reveals every identity.
	_blueprint_positions.clear()
	var occupied: Array[Vector2] = []
	var ordered: Array = _screws.values()
	ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		var ae := Reducer.is_exposed(_level,_state,str(a.id))
		var be := Reducer.is_exposed(_level,_state,str(b.id))
		return str(a.id) < str(b.id) if ae == be else ae)
	for screw in ordered:
		if not str(screw.id) in _state.get("remaining_screw_ids", []):
			continue
		var origin := _point(screw.position)
		var chosen := origin
		var candidates: Array[Vector2] = [origin]
		for ring in range(1,8):
			for i in range(8*ring):
				candidates.append(origin+Vector2.from_angle(TAU*i/float(8*ring))*ring*52.0)
		for candidate in candidates:
			if candidate.x<42 or candidate.x>598 or candidate.y<42 or candidate.y>550:
				continue
			var clear := true
			for used in occupied:
				if used.distance_to(candidate)<49:
					clear = false
					break
			if clear:
				chosen = candidate
				break
		occupied.append(chosen)
		_blueprint_positions[str(screw.id)] = chosen

func _make_plate_cache(plate: Dictionary) -> Dictionary:
	var polygon := PackedVector2Array()
	var center := Vector2.ZERO
	for raw in plate.get("polygon", []):
		var p := _point(raw)
		polygon.append(p)
		center += p
	center /= maxf(1,polygon.size())
	for i in range(polygon.size()):
		polygon[i] -= center
	var inset := polygon.duplicate()
	var offsets := Geometry2D.offset_polygon(polygon,-3.5)
	if not offsets.is_empty():
		inset = offsets[0]
	var longest := 0.0
	var angle := 0.0
	for i in range(polygon.size()):
		var edge := polygon[(i+1)%polygon.size()]-polygon[i]
		if edge.length() > longest:
			longest = edge.length()
			angle = edge.angle()
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for p in polygon:
		var rotated := p.rotated(-angle)
		min_x = minf(min_x,rotated.x)
		max_x = maxf(max_x,rotated.x)
		min_y = minf(min_y,rotated.y)
		max_y = maxf(max_y,rotated.y)
	var grain: Array = []
	var pores: Array = []
	var seed_offset := float(posmod(str(plate.id).hash(),100))/10.0
	for row in range(int((max_y-min_y)/12.0)+1):
		var path := PackedVector2Array()
		var y := min_y+row*12.0+5
		for column in range(int((max_x-min_x)/7)+2):
			var x := min_x+column*7.0
			var wobble := sin(x*0.019+row+seed_offset)*2.3+sin(x*0.046+row*2.2)*0.7
			var p := Vector2(x,y+wobble).rotated(angle)
			if Geometry2D.is_point_in_polygon(p,inset):
				path.append(p)
			elif path.size() >= 2:
				grain.append(path)
				path = PackedVector2Array()
			else:
				path = PackedVector2Array()
		if path.size() >= 2:
			grain.append(path)
	for i in range(24):
		var p := Vector2(lerpf(min_x,max_x,fposmod(i*0.618+seed_offset,1)),lerpf(min_y,max_y,fposmod(i*0.391+seed_offset,1))).rotated(angle)
		if Geometry2D.is_point_in_polygon(p,inset):
			pores.append(p)
	var accents: Array[Vector2] = []
	for p in pores:
		var clear := true
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			if not Geometry2D.is_point_in_polygon(p+direction*9,inset):
				clear = false
		for screw_id in plate.get("screw_ids", []):
			if _screws.has(screw_id) and p.distance_to(_point(_screws[screw_id].position)-center) < 38:
				clear = false
		for previous in accents:
			if p.distance_to(previous) < 65:
				clear = false
		if clear and accents.size() < 3:
			accents.append(p)
	return {"polygon":polygon,"inset":inset,"center":center,"angle":angle,"grain":grain,"pores":pores,"accents":accents}

func _draw_shifted_polygon(polygon: PackedVector2Array, offset: Vector2, color: Color) -> void:
	var shifted := PackedVector2Array()
	for p in polygon:
		shifted.append(p+offset)
	draw_colored_polygon(shifted,color)

func _point(raw: Variant) -> Vector2:
	if raw is Vector2:
		return raw
	return Vector2(float(raw[0]),float(raw[1]))

func _alpha(color: Color, opacity: float) -> Color:
	return Color(color.r,color.g,color.b,color.a*opacity)
