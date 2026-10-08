class_name CraftDraw
extends RefCounted
## Original resolution-independent art. All identity symbols remain visible in every skin.

const INK := Color("36235f")
const IVORY := Color("fff9ff")
const COLORS := {
	"red": Color("ef4b95"), "blue": Color("2eaeed"),
	"green": Color("31bd94"), "yellow": Color("ffcb43"),
	"purple": Color("9957e8"), "teal": Color("21c9d4")
}

static func color_for(color_id: String) -> Color:
	return COLORS.get(color_id, Color("b7aad5"))

static func rounded(canvas: CanvasItem, rect: Rect2, color: Color, radius: float = 16.0, border: Color = Color.TRANSPARENT, border_width: float = 0.0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	style.border_color = border
	style.set_border_width_all(int(border_width))
	style.anti_aliasing = true
	canvas.draw_style_box(style, rect)

static func screw(canvas: CanvasItem, center: Vector2, color_id: String, radius: float = 24.0, opacity: float = 1.0, angle: float = 0.0, muted: bool = false) -> void:
	# The bevel and inset symbol make a screw read as a chunky toy fastener at phone scale.
	var col := color_for(color_id)
	if muted:
		col = col.lerp(Color("a998c9"), 0.28)
	canvas.draw_circle(center + Vector2(0, radius * 0.24), radius * 1.13, _alpha(INK, 0.18 * opacity), true, -1.0, true)
	canvas.draw_circle(center + Vector2(0, radius * 0.13), radius * 1.035, _alpha(INK, opacity), true, -1.0, true)
	canvas.draw_circle(center + Vector2(0, radius * 0.11), radius * 0.945, _alpha(col.darkened(0.35), opacity), true, -1.0, true)
	canvas.draw_circle(center + Vector2(0, -radius * 0.065), radius, _alpha(INK.lightened(0.05), opacity), true, -1.0, true)
	canvas.draw_circle(center + Vector2(0, -radius * 0.095), radius * 0.925, _alpha(col, opacity), true, -1.0, true)
	canvas.draw_circle(center + Vector2(-radius * 0.075, -radius * 0.19), radius * 0.765, _alpha(col.lightened(0.085), opacity), true, -1.0, true)
	canvas.draw_arc(center + Vector2(0, -radius * 0.075), radius * 0.785, PI * 1.13, PI * 1.79, 24, _alpha(col.lightened(0.69), opacity), maxf(2.0, radius * 0.095), true)
	canvas.draw_arc(center + Vector2(0, -radius * 0.075), radius * 0.77, 0.15, PI * 0.76, 24, _alpha(col.darkened(0.18), 0.7 * opacity), maxf(1.5, radius * 0.07), true)
	canvas.draw_circle(center + Vector2(-radius * 0.48, -radius * 0.51), radius * 0.10, _alpha(Color.WHITE, 0.74 * opacity), true, -1.0, true)
	var glyph_tint := INK if color_id == "yellow" else IVORY
	var glyph_center := center + Vector2(0, -radius * 0.045)
	symbol(canvas, glyph_center + Vector2(0, radius * 0.065), color_id, radius * 0.425, _alpha(col.darkened(0.49), opacity), angle)
	symbol(canvas, glyph_center, color_id, radius * 0.41, _alpha(glyph_tint, opacity), angle)

static func symbol(canvas: CanvasItem, center: Vector2, color_id: String, radius: float, tint: Color = IVORY, angle: float = 0.0) -> void:
	var points := PackedVector2Array()
	match color_id:
		"red":
			canvas.draw_circle(center, radius * 0.77, tint, true, -1.0, true)
		"blue":
			for i in range(4):
				points.append(center + Vector2.from_angle(angle + PI * 0.5 * i) * radius)
			canvas.draw_colored_polygon(points, tint)
		"green":
			for i in range(3):
				points.append(center + Vector2.from_angle(angle - PI * 0.5 + TAU / 3.0 * i) * radius * 1.08)
			canvas.draw_colored_polygon(points, tint)
		"yellow":
			for i in range(10):
				var r := radius * (1.08 if i % 2 == 0 else 0.46)
				points.append(center + Vector2.from_angle(angle - PI * 0.5 + TAU / 10.0 * i) * r)
			canvas.draw_colored_polygon(points, tint)
		"purple":
			for i in range(4):
				points.append(center + Vector2.from_angle(angle + PI * 0.25 + PI * 0.5 * i) * radius)
			canvas.draw_colored_polygon(points, tint)
		"teal":
			for i in range(3):
				var a := Vector2(-radius * 0.83, (i - 1) * radius * 0.62).rotated(angle)
				var b := Vector2(radius * 0.83, (i - 1) * radius * 0.62).rotated(angle)
				canvas.draw_line(center + a, center + b, tint, radius * 0.30, true)
		_:
			canvas.draw_circle(center, radius * 0.5, tint, true, -1.0, true)

static func socket(canvas: CanvasItem, center: Vector2, radius: float = 21.0, tint: Color = Color("c3b4df")) -> void:
	canvas.draw_circle(center + Vector2(0, 2.5), radius + 3.0, Color(1, 1, 1, 0.94), true, -1.0, true)
	canvas.draw_circle(center, radius + 1.0, tint.darkened(0.33), true, -1.0, true)
	canvas.draw_circle(center + Vector2(0, 2), radius - 1.7, tint, true, -1.0, true)
	canvas.draw_arc(center, radius - 1.0, PI * 1.1, PI * 1.9, 20, tint.darkened(0.30), 2.5, true)
	canvas.draw_arc(center + Vector2(0, 1), radius, 0.1, PI * 0.89, 20, Color(1,1,1,0.65), 1.5, true)

static func icon(canvas: CanvasItem, center: Vector2, id: String, size: float = 28.0, tint: Color = INK) -> void:
	# Original illustrated tools. Navigation remains a readable silhouette, with toy-like depth.
	var w := maxf(2.0, size * 0.105)
	var edge := INK
	var pink := Color("ef4b95")
	var aqua := Color("35d3dc")
	var purple := Color("9c6ae7")
	var yellow := Color("ffce57")
	match id:
		"home":
			rounded(canvas,Rect2(center+Vector2(-0.63,-0.12)*size,Vector2(1.26,0.94)*size),edge,size*0.14)
			rounded(canvas,Rect2(center+Vector2(-0.54,-0.15)*size,Vector2(1.08,0.86)*size),Color("bfeff6"),size*0.10)
			_poly(canvas,center+Vector2(0,size*0.06),[Vector2(-0.96,-0.08),Vector2(-0.02,-0.93),Vector2(0.98,-0.08),Vector2(0.79,0.12),Vector2(0,-0.52),Vector2(-0.79,0.12)],size,edge)
			_poly(canvas,center,[Vector2(-0.88,-0.11),Vector2(-0.02,-0.87),Vector2(0.89,-0.11),Vector2(0.77,0.02),Vector2(0,-0.62),Vector2(-0.75,0.02)],size,pink)
			_line(canvas,center,[Vector2(-0.62,-0.22),Vector2(-0.05,-0.72),Vector2(0.48,-0.28)],size,pink.lightened(0.5),w*0.58)
			rounded(canvas,Rect2(center+Vector2(-0.19,0.16)*size,Vector2(0.40,0.54)*size),edge,size*0.10)
			rounded(canvas,Rect2(center+Vector2(-0.10,0.23)*size,Vector2(0.23,0.45)*size),purple,size*0.07)
			canvas.draw_circle(center+Vector2(0.08,0.44)*size,size*0.035,yellow,true,-1,true)
		"undo", "restart":
			var arc := PackedVector2Array()
			for i in range(35):
				var theta := -PI*0.67+PI*1.56*float(i)/34.0
				arc.append(center+(Vector2(0.035,0.01)+Vector2.from_angle(theta)*0.53)*size)
			canvas.draw_polyline(arc,edge,size*0.34,true)
			canvas.draw_polyline(arc,aqua,size*0.22,true)
			var glint := arc.slice(4,14)
			canvas.draw_polyline(glint,aqua.lightened(0.6),size*0.055,true)
			_poly(canvas,center,[Vector2(-0.94,-0.43),Vector2(-0.23,-0.88),Vector2(-0.23,0.02)],size,edge)
			_poly(canvas,center,[Vector2(-0.78,-0.43),Vector2(-0.33,-0.70),Vector2(-0.33,-0.16)],size,aqua)
			canvas.draw_circle(arc[-1],size*0.11,aqua,true,-1,true)
		"hint":
			var bulb_center := center+Vector2(0,-0.25)*size
			for i in range(5):
				var ray := Vector2.from_angle(PI*1.10+i*PI*0.20)
				_stroke(canvas,bulb_center+ray*size*0.82,bulb_center+ray*size*1.03,yellow,size*0.09)
			canvas.draw_circle(bulb_center+Vector2(0,2),size*0.61,edge,true,-1,true)
			canvas.draw_circle(bulb_center,size*0.52,yellow,true,-1,true)
			canvas.draw_arc(bulb_center,size*0.40,PI*1.12,PI*1.72,20,Color("fff6bd"),size*0.10,true)
			_poly(canvas,center,[Vector2(-0.38,0.08),Vector2(-0.28,0.48),Vector2(0.28,0.48),Vector2(0.38,0.08)],size,edge)
			_poly(canvas,center,[Vector2(-0.29,0.07),Vector2(-0.20,0.40),Vector2(0.20,0.40),Vector2(0.29,0.07)],size,yellow)
			_line(canvas,center,[Vector2(-0.15,0.02),Vector2(0,0.18),Vector2(0.15,0.02)],size,Color("d49731"),w*0.72)
			rounded(canvas,Rect2(center+Vector2(-0.30,0.40)*size,Vector2(0.60,0.39)*size),edge,size*0.1)
			_stroke(canvas,center+Vector2(-0.19,0.47)*size,center+Vector2(0.19,0.47)*size,purple,w)
			_stroke(canvas,center+Vector2(-0.16,0.65)*size,center+Vector2(0.16,0.65)*size,purple.lightened(0.2),w*0.8)
		"blueprint", "album", "queue":
			rounded(canvas,Rect2(center+Vector2(-0.60,-0.70)*size,Vector2(1.23,1.53)*size),edge,size*0.16)
			rounded(canvas,Rect2(center+Vector2(-0.49,-0.68)*size,Vector2(1.0,1.39)*size),aqua,size*0.11)
			rounded(canvas,Rect2(center+Vector2(-0.38,-0.51)*size,Vector2(0.79,1.0)*size),Color("ecffff"),size*0.03)
			if id == "album":
				symbol(canvas,center+Vector2(0,-0.02)*size,"yellow",size*0.29,pink)
			else:
				for i in range(3):
					_stroke(canvas,center+Vector2(-0.22,-0.31+i*0.26)*size,center+Vector2(0.24 if i<2 else 0.03,-0.31+i*0.26)*size,purple,w*0.70)
			_stroke(canvas,center+Vector2(-0.46,-0.68)*size,center+Vector2(0.47,-0.68)*size,edge,size*0.25)
			_stroke(canvas,center+Vector2(-0.43,-0.72)*size,center+Vector2(0.45,-0.72)*size,Color("b899f4"),size*0.16)
			_stroke(canvas,center+Vector2(-0.32,0.62)*size,center+Vector2(0.31,0.62)*size,Color("98f3f4"),w*0.65)
		"settings":
			var gear := PackedVector2Array()
			for i in range(40):
				gear.append(center+Vector2.from_angle(TAU*i/40.0)*size*(0.81 if i%5 in [1,2,3] else 0.63))
			var depth := PackedVector2Array()
			for p in gear:
				depth.append(p+Vector2(0,size*0.08))
			canvas.draw_colored_polygon(depth,edge)
			canvas.draw_colored_polygon(gear,purple)
			gear.append(gear[0])
			canvas.draw_polyline(gear,edge,w*0.66,true)
			canvas.draw_arc(center,size*0.47,PI*1.15,PI*1.85,18,purple.lightened(0.6),size*0.085,true)
			canvas.draw_circle(center,size*0.32,edge,true,-1,true)
			canvas.draw_circle(center+Vector2(0,-size*0.025),size*0.20,Color("fff9ff"),true,-1,true)
		"close":
			_stroke(canvas,center+Vector2(-0.43,-0.43)*size,center+Vector2(0.43,0.43)*size,tint,w*1.5)
			_stroke(canvas,center+Vector2(-0.43,0.43)*size,center+Vector2(0.43,-0.43)*size,tint,w*1.5)
		"check":
			_line(canvas,center,[Vector2(-0.64,0),Vector2(-0.16,0.49),Vector2(0.68,-0.48)],size,tint,w*1.4)
		"arrow", "next":
			_line(canvas,center,[Vector2(-0.3,-0.6),Vector2(0.3,0),Vector2(-0.3,0.6)],size,tint,w*1.3)
		"back":
			_line(canvas,center,[Vector2(0.3,-0.6),Vector2(-0.3,0),Vector2(0.3,0.6)],size,tint,w*1.3)
		"lock":
			canvas.draw_arc(center+Vector2(0,-0.18)*size,size*0.38,PI,TAU,24,tint,w*1.2,true)
			rounded(canvas,Rect2(center+Vector2(-0.57,-0.13)*size,Vector2(1.14,0.96)*size),tint,size*0.18)
			rounded(canvas,Rect2(center+Vector2(-0.42,-0.02)*size,Vector2(0.84,0.67)*size),yellow,size*0.10)
			canvas.draw_circle(center+Vector2(0,0.22)*size,size*0.115,tint,true,-1,true)
			_stroke(canvas,center+Vector2(0,0.25)*size,center+Vector2(0,0.40)*size,tint,w*0.72)
		"sound":
			_poly(canvas,center,[Vector2(-0.72,-0.25),Vector2(-0.37,-0.25),Vector2(0.14,-0.67),Vector2(0.14,0.67),Vector2(-0.37,0.25),Vector2(-0.72,0.25)],size,purple)
			canvas.draw_arc(center,size*0.60,-0.67,0.67,18,tint,w,true)
			canvas.draw_arc(center,size*0.85,-0.68,0.68,18,tint,w,true)
		"coin":
			canvas.draw_circle(center+Vector2(0,size*0.1),size*0.77,Color("aa622a"),true,-1,true)
			canvas.draw_circle(center,size*0.75,Color("d58d22"),true,-1,true)
			canvas.draw_circle(center+Vector2(0,-size*0.035),size*0.67,yellow,true,-1,true)
			canvas.draw_arc(center,size*0.57,PI*1.1,PI*1.87,22,Color("fff4b5"),size*0.09,true)
			canvas.draw_arc(center,size*0.56,0.1,PI*0.88,22,Color("eba732"),size*0.085,true)
			symbol(canvas,center+Vector2(0,size*0.04),"yellow",size*0.35,Color("d89126"))
			symbol(canvas,center+Vector2(0,-size*0.025),"yellow",size*0.33,Color("fff5bf"))
		_:
			symbol(canvas,center,id,size*0.65,tint)

static func sparkle(canvas: CanvasItem, center: Vector2, radius: float, tint: Color = Color("ffce57"), angle: float = 0.0) -> void:
	var path := PackedVector2Array()
	for i in range(8):
		path.append(center+Vector2.from_angle(angle+PI*0.25*i)*radius*(1.0 if i%2 == 0 else 0.30))
	canvas.draw_colored_polygon(path,tint)

static func _stroke(canvas: CanvasItem, start: Vector2, end: Vector2, tint: Color, width: float) -> void:
	canvas.draw_line(start,end,tint,width,true)
	canvas.draw_circle(start,width*0.5,tint,true,-1,true)
	canvas.draw_circle(end,width*0.5,tint,true,-1,true)

static func _poly(canvas: CanvasItem, center: Vector2, points: Array, scale: float, tint: Color) -> void:
	var path := PackedVector2Array()
	for point in points:
		path.append(center+point*scale)
	canvas.draw_colored_polygon(path,tint)

static func motif(canvas: CanvasItem, center: Vector2, family: String, scale: float, tint: Color) -> void:
	## Tiny original workshop stamps, also used as the craft board's revealed engraving.
	var width := maxf(2.0,scale*0.065)
	match family:
		"flower":
			for i in range(6):
				canvas.draw_circle(center+Vector2.from_angle(TAU*i/6.0)*scale*0.49,scale*0.30,tint,false,width,true)
			canvas.draw_circle(center,scale*0.23,tint,false,width,true)
		"sailboat", "boat":
			_line(canvas,center,[Vector2(-0.88,0.37),Vector2(-0.55,0.80),Vector2(0.54,0.80),Vector2(0.87,0.37),Vector2(-0.88,0.37)],scale,tint,width)
			_line(canvas,center,[Vector2(-0.08,0.27),Vector2(-0.08,-0.88),Vector2(-0.80,0.19),Vector2(-0.08,0.19)],scale,tint,width)
			_line(canvas,center,[Vector2(0.08,-0.64),Vector2(0.71,0.18),Vector2(0.08,0.18)],scale,tint,width)
		"bird":
			_line(canvas,center,[Vector2(-0.82,0.14),Vector2(-0.20,0.11),Vector2(0.06,-0.69),Vector2(0.46,-0.61),Vector2(0.63,-0.36),Vector2(0.86,-0.19),Vector2(0.60,-0.10),Vector2(0.45,0.40),Vector2(0.0,0.70),Vector2(-0.82,0.14)],scale,tint,width)
			canvas.draw_circle(center+Vector2(0.40,-0.36)*scale,width,tint,true,-1,true)
			_line(canvas,center,[Vector2(-0.28,0.13),Vector2(0.15,0.37),Vector2(0.25,-0.11)],scale,tint,width)
		"windmill":
			for i in range(4):
				var a := TAU*i/4.0
				_line(canvas,center,[Vector2(0,0).rotated(a),Vector2(-0.25,-0.75).rotated(a),Vector2(0.36,-0.83).rotated(a),Vector2(0.36,-0.22).rotated(a),Vector2(0,0)],scale,tint,width)
		"butterfly":
			for side in [-1,1]:
				_line(canvas,center,[Vector2(0,-0.07),Vector2(side*0.49,-0.78),Vector2(side*0.86,-0.60),Vector2(side*0.68,-0.06),Vector2(side*0.82,0.44),Vector2(side*0.42,0.76),Vector2(0,0.10)],scale,tint,width)
			_line(canvas,center,[Vector2(-0.23,-0.86),Vector2(0,-0.47),Vector2(0,0.67)],scale,tint,width)
			_line(canvas,center,[Vector2(0,-0.47),Vector2(0.23,-0.86)],scale,tint,width)
		"house":
			_line(canvas,center,[Vector2(-0.84,-0.1),Vector2(0,-0.85),Vector2(0.84,-0.1)],scale,tint,width)
			_line(canvas,center,[Vector2(-0.59,-0.1),Vector2(-0.59,0.72),Vector2(-0.17,0.72),Vector2(-0.17,0.19),Vector2(0.20,0.19),Vector2(0.20,0.72),Vector2(0.61,0.72),Vector2(0.61,-0.1)],scale,tint,width)
		"tree":
			_line(canvas,center,[Vector2(-0.63,0.31),Vector2(-0.36,-0.05),Vector2(-0.64,-0.05),Vector2(0,-0.90),Vector2(0.64,-0.05),Vector2(0.36,-0.05),Vector2(0.63,0.31),Vector2(0.14,0.31),Vector2(0.14,0.83),Vector2(-0.14,0.83),Vector2(-0.14,0.31),Vector2(-0.63,0.31)],scale,tint,width)
		"lantern":
			rounded(canvas,Rect2(center+Vector2(-0.49,-0.51)*scale,Vector2(0.98,1.15)*scale),Color.TRANSPARENT,scale*0.22,tint,width)
			canvas.draw_arc(center+Vector2(0,-0.51)*scale,scale*0.27,PI,TAU,16,tint,width,true)
			_line(canvas,center,[Vector2(-0.53,0.74),Vector2(0.53,0.74)],scale,tint,width)
			_line(canvas,center,[Vector2(0,-0.24),Vector2(-0.18,0.20),Vector2(0,0.42),Vector2(0.18,0.20),Vector2(0,-0.24)],scale,tint,width)
		"signpost":
			_line(canvas,center,[Vector2(0,-0.85),Vector2(0,0.85)],scale,tint,width)
			_line(canvas,center,[Vector2(-0.62,-0.52),Vector2(0.54,-0.52),Vector2(0.79,-0.24),Vector2(0.54,0.02),Vector2(-0.62,0.02),Vector2(-0.62,-0.52)],scale,tint,width)
		"fish":
			_line(canvas,center,[Vector2(-0.52,0),Vector2(-0.84,-0.50),Vector2(-0.84,0.50),Vector2(-0.52,0),Vector2(-0.22,-0.43),Vector2(0.31,-0.51),Vector2(0.84,0),Vector2(0.31,0.51),Vector2(-0.22,0.43),Vector2(-0.52,0)],scale,tint,width)
			canvas.draw_circle(center+Vector2(0.45,-0.10)*scale,width,tint,true,-1,true)
			_line(canvas,center,[Vector2(0.12,-0.39),Vector2(-0.01,0),Vector2(0.12,0.39)],scale,tint,width)
		"keepsake":
			var heart := PackedVector2Array()
			for i in range(65):
				var t := TAU*float(i)/64.0
				var x := 16.0*pow(sin(t),3)/20.0
				var y := -(13*cos(t)-5*cos(2*t)-2*cos(3*t)-cos(4*t))/20.0
				heart.append(center+Vector2(x,y)*scale)
			canvas.draw_polyline(heart,tint,width,true)
		_:
			var star := PackedVector2Array()
			for i in range(11):
				star.append(center+Vector2.from_angle(-PI*0.5+TAU*i/10.0)*scale*(0.83 if i%2==0 else 0.39))
			canvas.draw_polyline(star,tint,width,true)

static func _line(canvas: CanvasItem, center: Vector2, points: Array, scale: float, tint: Color, width: float) -> void:
	var path := PackedVector2Array()
	for point in points:
		path.append(center + point * scale)
	canvas.draw_polyline(path,tint,width,true)

static func _alpha(color: Color, opacity: float) -> Color:
	return Color(color.r,color.g,color.b,color.a*opacity)
