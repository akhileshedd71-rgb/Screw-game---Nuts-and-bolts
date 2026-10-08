class_name CraftDraw
extends RefCounted
## Original resolution-independent art. All identity symbols remain visible in every skin.

const INK := Color("34473e")
const IVORY := Color("fffbed")
const COLORS := {
	"red": Color("d65353"), "blue": Color("477acc"),
	"green": Color("5a8c45"), "yellow": Color("d5a026"),
	"purple": Color("8564b0"), "teal": Color("168c96")
}

static func color_for(color_id: String) -> Color:
	return COLORS.get(color_id, Color("a5aaa0"))

static func rounded(canvas: CanvasItem, rect: Rect2, color: Color, radius: float = 16.0, border: Color = Color.TRANSPARENT, border_width: float = 0.0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	style.border_color = border
	style.set_border_width_all(int(border_width))
	style.anti_aliasing = true
	canvas.draw_style_box(style, rect)

static func screw(canvas: CanvasItem, center: Vector2, color_id: String, radius: float = 24.0, opacity: float = 1.0, angle: float = 0.0, muted: bool = false) -> void:
	var col := color_for(color_id)
	if muted:
		col = col.lerp(Color("adb4a5"), 0.32)
	canvas.draw_circle(center + Vector2(1, radius * 0.17), radius * 1.10, Color(0.17, 0.17, 0.12, 0.14 * opacity), true, -1.0, true)
	canvas.draw_circle(center + Vector2(0, radius * 0.08), radius, _alpha(col.darkened(0.35), opacity), true, -1.0, true)
	canvas.draw_circle(center, radius, _alpha(col.darkened(0.22), opacity), true, -1.0, true)
	canvas.draw_circle(center + Vector2(0, -radius * 0.055), radius * 0.91, _alpha(col, opacity), true, -1.0, true)
	canvas.draw_arc(center + Vector2(0, -radius * 0.01), radius * 0.75, PI * 1.18 + angle, PI * 1.81 + angle, 24, Color(1.0, 0.98, 0.87, 0.45 * opacity), maxf(1.5, radius * 0.065), true)
	canvas.draw_arc(center, radius * 0.84, 0.12, PI * 0.82, 24, _alpha(col.darkened(0.10), opacity), maxf(1.0, radius * 0.035), true)
	var glyph_tint := INK if color_id == "yellow" else IVORY
	symbol(canvas, center + Vector2(0, -radius * 0.03), color_id, radius * 0.42, _alpha(glyph_tint, opacity), angle)

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

static func socket(canvas: CanvasItem, center: Vector2, radius: float = 21.0, tint: Color = Color("bac0af")) -> void:
	canvas.draw_circle(center + Vector2(0, 1), radius + 2.0, Color(1, 0.99, 0.94, 0.85), true, -1.0, true)
	canvas.draw_circle(center, radius, tint.darkened(0.13), true, -1.0, true)
	canvas.draw_circle(center + Vector2(0, 2), radius - 2.0, tint, true, -1.0, true)
	canvas.draw_arc(center, radius - 1.0, PI * 1.12, PI * 1.88, 16, tint.darkened(0.20), 1.5, true)

static func icon(canvas: CanvasItem, center: Vector2, id: String, size: float = 28.0, tint: Color = INK) -> void:
	var w := maxf(2.0, size * 0.085)
	match id:
		"home":
			_line(canvas, center, [Vector2(-0.85,-0.12),Vector2(0,-0.84),Vector2(0.85,-0.12)], size, tint, w)
			_line(canvas, center, [Vector2(-0.60,-0.18),Vector2(-0.60,0.72),Vector2(-0.17,0.72),Vector2(-0.17,0.19),Vector2(0.20,0.19),Vector2(0.20,0.72),Vector2(0.61,0.72),Vector2(0.61,-0.18)], size, tint, w)
		"undo", "restart":
			var arc := PackedVector2Array([center+Vector2(-0.65,-0.42)*size])
			for i in range(28):
				var theta := -PI*0.5+PI*float(i)/27.0
				arc.append(center+(Vector2(0.04,0.09)+Vector2.from_angle(theta)*0.51)*size)
			canvas.draw_polyline(arc,tint,w,true)
			_line(canvas,center,[Vector2(-0.28,-0.77),Vector2(-0.65,-0.42),Vector2(-0.28,-0.07)],size,tint,w)
		"hint":
			canvas.draw_arc(center + Vector2(0,-0.23)*size,size*0.57,PI*0.17,PI*2.83,32,tint,w,true)
			_line(canvas,center,[Vector2(-0.50,0.03),Vector2(-0.29,0.46),Vector2(0.29,0.46),Vector2(0.50,0.03)],size,tint,w)
			_line(canvas,center,[Vector2(-0.26,0.70),Vector2(0.26,0.70)],size,tint,w)
		"blueprint", "album", "queue":
			rounded(canvas,Rect2(center-size*Vector2(0.62,0.79),size*Vector2(1.24,1.58)),Color.TRANSPARENT,size*0.10,tint,w)
			for i in range(3):
				_line(canvas,center,[Vector2(-0.31,-0.37+i*0.36),Vector2(0.31 if i<2 else 0.08,-0.37+i*0.36)],size,tint,w*0.85)
		"settings":
			canvas.draw_circle(center,size*0.52,tint,false,w,true)
			canvas.draw_circle(center,size*0.18,tint,false,w,true)
			for i in range(8):
				var vec := Vector2.from_angle(TAU/8*i)
				canvas.draw_line(center+vec*size*0.56,center+vec*size*0.78,tint,w,true)
		"close":
			_line(canvas,center,[Vector2(-0.5,-0.5),Vector2(0.5,0.5)],size,tint,w)
			_line(canvas,center,[Vector2(-0.5,0.5),Vector2(0.5,-0.5)],size,tint,w)
		"check":
			_line(canvas,center,[Vector2(-0.64,0),Vector2(-0.16,0.49),Vector2(0.68,-0.48)],size,tint,w)
		"arrow", "next":
			_line(canvas,center,[Vector2(-0.3,-0.6),Vector2(0.3,0),Vector2(-0.3,0.6)],size,tint,w)
		"back":
			_line(canvas,center,[Vector2(0.3,-0.6),Vector2(-0.3,0),Vector2(0.3,0.6)],size,tint,w)
		"lock":
			rounded(canvas,Rect2(center+Vector2(-0.55,-0.07)*size,Vector2(1.1,0.88)*size),tint,size*0.13)
			canvas.draw_arc(center+Vector2(0,-0.14)*size,size*0.35,PI,TAU,24,tint,w,true)
		"sound":
			_line(canvas,center,[Vector2(-0.68,-0.21),Vector2(-0.36,-0.21),Vector2(0.10,-0.63),Vector2(0.10,0.63),Vector2(-0.36,0.21),Vector2(-0.68,0.21),Vector2(-0.68,-0.21)],size,tint,w)
			canvas.draw_arc(center,size*0.62,-0.65,0.65,18,tint,w,true)
		"coin":
			canvas.draw_circle(center,size*0.72,Color("ddb050"),true,-1,true)
			canvas.draw_circle(center,size*0.55,Color("f1ca6b"),false,w,true)
			symbol(canvas,center,"yellow",size*0.30,Color("9d6e27"))
		_:
			symbol(canvas,center,id,size*0.65,tint)

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
			icon(canvas,center,"home",scale,tint)
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
