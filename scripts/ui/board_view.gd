class_name BoardView
extends Control
## Presentation only: the reducer owns every removal, route and layer relationship.

signal screw_pressed(screw_id: String)
signal presentation_finished

const Art = preload("res://scripts/ui/craft_draw.gd")
const Reducer = preload("res://scripts/core/puzzle_reducer.gd")
const RELEASE_DURATION := 0.38
const PALETTES := {
	"beech": [Color("dab27a"),Color("ebd1a0"),Color("c49360"),Color("efdcb6")],
	"walnut": [Color("986944"),Color("bd956a"),Color("80573e"),Color("d2b185")],
	"rose": [Color("cf9f8e"),Color("e5bfa8"),Color("b98170"),Color("edd7bf")],
	"sage": [Color("a9b28d"),Color("cbd0ad"),Color("91a082"),Color("dfd9b7")]
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
			draw_circle(p+vector*(20+progress*35),maxf(0.5,2.0*(1-progress)),Color(0.90,0.71,0.34,opacity*0.8),true,-1,true)

func _draw_backing() -> void:
	var bounds := Rect2(4,4,632,588)
	Art.rounded(self,Rect2(4,10,632,588),Color(0.21,0.24,0.18,0.12),30)
	Art.rounded(self,bounds,Color("d0b588"),30)
	Art.rounded(self,Rect2(6,5,628,582),Color("e9d9b9"),29)
	Art.rounded(self,Rect2(10,9,620,574),Color("efdfbf"),26,Color("f5e9ce"),1)
	Art.rounded(self,Rect2(16,15,608,563),Color("edddbd"),22,Color(0.61,0.44,0.24,0.12),1)
	for i in range(24):
		var points := PackedVector2Array()
		for j in range(45):
			var y := 26+j*12.2
			var x := 26+i*25+sin(y*0.012+i*1.1)*5.5+sin(y*0.037+i*2.7)*1.0
			points.append(Vector2(x,y))
		draw_polyline(points,Color(0.49,0.34,0.16,0.037),1.0,true)
	var family := str(_level.get("family","flower"))
	Art.motif(self,Vector2(320,286),family,117,Color(0.55,0.40,0.22,0.09))
	for point in [Vector2(30,29),Vector2(610,29),Vector2(30,561),Vector2(610,561)]:
		draw_circle(point,3,Color(0.66,0.51,0.30,0.26),true,-1,true)
		draw_circle(point+Vector2(0,-0.8),1.5,Color(1.0,0.96,0.80,0.7),true,-1,true)
	if _state.get("status", "") == "WON":
		Art.motif(self,Vector2(320,285),family,124,Color("748d65"))
		draw_arc(Vector2(320,285),168,0,TAU,100,Color(0.44,0.56,0.37,0.22),2,true)

func _draw_plate(plate: Dictionary, cache: Dictionary, opacity: float) -> void:
	var polygon: PackedVector2Array = cache.polygon
	var inset: PackedVector2Array = cache.inset
	var colors: Array = PALETTES.get(skin,PALETTES.beech)
	var col: Color = colors[posmod(int(plate.get("material",0)),4)]
	_draw_shifted_polygon(polygon,Vector2(2,12),Color(0.22,0.16,0.08,0.08*opacity))
	_draw_shifted_polygon(polygon,Vector2(1,8),Color(0.29,0.21,0.12,0.12*opacity))
	_draw_shifted_polygon(polygon,Vector2(0,4),_alpha(col.darkened(0.24),opacity))
	draw_colored_polygon(polygon,_alpha(col.darkened(0.10),opacity))
	if inset.size() >= 3:
		draw_colored_polygon(inset,_alpha(col.lightened(0.06),opacity))
	for path in cache.grain:
		draw_polyline(path,Color(0.36,0.23,0.10,0.075*opacity),1.1,true)
	for pore in cache.pores:
		draw_line(pore,pore+Vector2(2.4,0).rotated(cache.angle),Color(0.35,0.20,0.09,0.08*opacity),0.6,true)
	for i in range(polygon.size()):
		var a := polygon[i]
		var b := polygon[(i+1)%polygon.size()]
		var edge := b-a
		var highlight: bool = edge.x > 0.01 or (absf(edge.x)<0.01 and edge.y<0)
		draw_line(a,b,Color(1,0.96,0.81,0.52*opacity) if highlight else Color(0.40,0.25,0.10,0.27*opacity),1.6,true)
	if inset.size() >= 3:
		var outline := inset.duplicate()
		outline.append(inset[0])
		draw_polyline(outline,Color(1,0.97,0.84,0.17*opacity),1.0,true)

func _draw_hole(position: Vector2, opacity: float) -> void:
	draw_circle(position+Vector2(0,1),10,Color(1,0.96,0.80,0.47*opacity),true,-1,true)
	draw_circle(position,8,Color(0.40,0.27,0.14,0.65*opacity),true,-1,true)
	draw_circle(position+Vector2(0,1),5.4,Color(0.24,0.18,0.11,0.64*opacity),true,-1,true)
	draw_arc(position,8,PI,TAU,16,Color(0.32,0.22,0.12,0.24*opacity),1.5,true)

func _draw_hint(position: Vector2) -> void:
	var pulse := (sin(_clock*4.2)+1.0)*0.5 if not reduced_motion else 0.5
	draw_circle(position,34.0+pulse*4.0,Color(1,1,0.93,0.45-pulse*0.15),true,-1,true)
	draw_arc(position,31.0+pulse*3.0,0,TAU,48,Color("64805a"),2.5,true)

func _draw_blueprint() -> void:
	Art.rounded(self,Rect2(16,15,608,563),Color("e5eddf"),22)
	for x in range(32,624,24):
		draw_line(Vector2(x,24),Vector2(x,570),Color(0.35,0.48,0.36,0.055),1,true)
	for y in range(28,574,24):
		draw_line(Vector2(24,y),Vector2(616,y),Color(0.35,0.48,0.36,0.055),1,true)
	for plate in _plates:
		if str(plate.id) in _state.get("removed_plate_ids", []):
			continue
		var cache: Dictionary = _cache[str(plate.id)]
		var polygon := PackedVector2Array()
		for p in cache.polygon:
			polygon.append(p+cache.center)
		draw_colored_polygon(polygon,Color(0.50,0.63,0.46,0.07))
		polygon.append(polygon[0])
		draw_polyline(polygon,Color(0.35,0.48,0.36,0.40),2,true)
	for screw in _screws.values():
		if not str(screw.id) in _state.get("remaining_screw_ids", []):
			continue
		var point: Vector2 = _blueprint_positions.get(str(screw.id),_point(screw.position))
		var original := _point(screw.position)
		if point.distance_to(original) > 8:
			draw_line(original,point,Color(0.35,0.48,0.36,0.2),1.2,true)
			draw_circle(original,3,Color(0.35,0.48,0.36,0.35),true,-1,true)
		for blocker in screw.get("blocker_plate_ids", []):
			if blocker in _state.get("removed_plate_ids", []) or not _cache.has(blocker):
				continue
			var target: Vector2 = _cache[blocker].center
			var direction := (target-point).normalized()
			var length := (target-point).length()
			for step in range(int(length/10.0)):
				var start := point+direction*step*10
				draw_line(start,start+direction*5,Color(0.34,0.47,0.35,0.55),1.5,true)
			Art.rounded(self,Rect2(target-Vector2(4,4),Vector2(8,8)),Color("668160"),2)
	for screw in _screws.values():
		if not str(screw.id) in _state.get("remaining_screw_ids", []):
			continue
		var point: Vector2 = _blueprint_positions.get(str(screw.id),_point(screw.position))
		var exposed := Reducer.is_exposed(_level,_state,str(screw.id))
		draw_circle(point,27,Color(0.98,0.99,0.95,0.91),true,-1,true)
		Art.screw(self,point,str(screw.color_id),22,1.0,0.0,not exposed)
		if not exposed:
			Art.rounded(self,Rect2(point+Vector2(10,12),Vector2(18,18)),Color("e5eddf"),5)
			Art.icon(self,point+Vector2(19,20),"lock",9,Color("526b50"))

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
	return {"polygon":polygon,"inset":inset,"center":center,"angle":angle,"grain":grain,"pores":pores}

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
