extends Node2D
## Visual clock/seed only. Anchors and native sprites are built once, never in SDK.
const Ops := preload("res://pushbox/scripts/art/canvas_ops.gd")
const Art := preload("res://pushbox/scripts/art/art_registry.gd")
static var _textures: Dictionary = {}

static func warm() -> void:
	if not _textures.is_empty():
		return
	for layer in 3:
		var size: Vector2i = [Vector2i(24,8),Vector2i(40,12),Vector2i(56,16)][layer]
		var cloud: Image = Ops.canvas(size)
		for i in 5:
			Ops.ellipse(cloud,Vector2i(size.x*(i+1)/6,size.y*2/3-(i%2)*2),Vector2i(size.x/5,size.y/3+(i%3)),Color("c0cbdc"))
			Ops.ellipse(cloud,Vector2i(size.x*(i+1)/6,size.y/2-(i%2)),Vector2i(size.x/6,size.y/3),Color("ffffff"))
		_textures["cloud%d"%layer] = ImageTexture.create_from_image(cloud)
	var asteroid: Image = Ops.canvas(Vector2i(9,9))
	Ops.polygon(asteroid,PackedVector2Array([Vector2(0,4),Vector2(2,1),Vector2(5,0),Vector2(8,3),Vector2(7,7),Vector2(3,8)]),Color("5a6988"))
	Ops.line(asteroid,Vector2i(2,2),Vector2i(5,1),Color("8b9bb4"))
	Ops.rect(asteroid,3,4,2,2,Color("3a4466"))
	_textures["asteroid"] = ImageTexture.create_from_image(asteroid)
	for f in 4:
		for kind in ["bird","dove","bat","drone","beetle","frog","snail","mouse","lizard","spirit"]:
			_textures[kind+str(f)] = ImageTexture.create_from_image(_creature(kind,f))
	for f in 2:
		for i in 3:
			var flower: Image = Ops.canvas(Vector2i(8,6))
			Ops.line(flower,Vector2i(3,5),Vector2i(3+f,2),Color("3e8948"))
			Ops.rect(flower,1,4,2,1,Color("63c74d"))
			Ops.rect(flower,5,3,2,1,Color("63c74d"))
			var color: Color = [Color("e43b44"),Color("fee761"),Color("2ce8f5")][i]
			Ops.rect(flower,2+f,0,3,3,color)
			Ops.rect(flower,1+f,1,5,1,color)
			Ops.rect(flower,3+f,1,1,1,Color("ffffff"))
			_textures["flower%d%d"%[i,f]] = ImageTexture.create_from_image(flower)
		var wing: Image = Ops.canvas(Vector2i(5,5))
		Ops.rect(wing,2,1,1,4,Color("181425"))
		for x in ([0,3] if f==0 else [1,3]):
			Ops.rect(wing,x,0,2 if f==0 else 1,3,Color("fee761"))
			Ops.rect(wing,x,3,1,1,Color("f6757a"))
		_textures["butterfly"+str(f)] = ImageTexture.create_from_image(wing)
		var moth: Image = Ops.canvas(Vector2i(6,6))
		moth.blit_rect(wing,Rect2i(Vector2i.ZERO,wing.get_size()),Vector2i.ZERO)
		for y in 5:
			for x in 5:
				if moth.get_pixel(x,y).a>0:
					moth.set_pixel(x,y,Color(Color("ffffff") if x%2 else Color("2ce8f5"),0.8))
		_textures["moth"+str(f)] = ImageTexture.create_from_image(moth)

static func _creature(kind: String, f: int) -> Image:
	var size := Vector2i(8,8)
	if kind == "drone": size = Vector2i(10,10)
	if kind == "dove": size = Vector2i(9,7)
	if kind == "bat": size = Vector2i(7,6)
	if kind == "beetle": size = Vector2i(6,5)
	var im: Image = Ops.canvas(size)
	var ink := Color("181425")
	match kind:
		"bird","dove":
			var y: int = 2+(1 if f==1 else (-1 if f==2 else 0))
			Ops.ellipse(im,Vector2i(3,y+1),Vector2i(3,2),ink)
			Ops.ellipse(im,Vector2i(3,y+1),Vector2i(2,1),Color("ffffff") if kind=="dove" else Color("0099db"))
			Ops.rect(im,4,y-1,2,2,Color("ffffff") if kind=="dove" else Color("2ce8f5"))
			Ops.rect(im,5,y,1,1,ink)
			Ops.rect(im,6,y+1,2,1,Color("feae34"))
			Ops.rect(im,2,y+3,3,1,Color("ead4aa") if kind=="dove" else Color("f77622"))
			Ops.rect(im,2,7-f/2,1,1,ink)
			Ops.rect(im,4,7-f/2,1,1,ink)
			if f==3: Ops.line(im,Vector2i(1,2),Vector2i(0,0),Color("2ce8f5"))
		"bat":
			Ops.line(im,Vector2i(3,3),Vector2i(0,1+f%2),Color("68386c"))
			Ops.line(im,Vector2i(3,3),Vector2i(6,1+f%2),Color("68386c"))
			Ops.rect(im,2,2,3,4,Color("68386c"))
			if f!=2:
				Ops.rect(im,2,3,1,1,Color("fee761"))
				Ops.rect(im,4,3,1,1,Color("fee761"))
		"drone":
			Ops.ellipse(im,Vector2i(4,4),Vector2i(4,3),ink)
			Ops.ellipse(im,Vector2i(4,4),Vector2i(3,2),Color("8b9bb4"))
			Ops.rect(im,3,3,4,2,Color("193c3e"))
			Ops.rect(im,4+f%2,3,1,2,Color("2ce8f5"))
			Ops.rect(im,3,8,3,1,Color("0099db"))
			Ops.rect(im,4,9,1,1,Color("2ce8f5"))
		"beetle":
			Ops.ellipse(im,Vector2i(3,2),Vector2i(2,2),Color("733e39"))
			Ops.rect(im,2,1,3,2,Color("feae34"))
			Ops.rect(im,2+f%2,1,1,1,Color("fee761"))
			for x in [0,5]: Ops.rect(im,x,1+f%2,1,3,Color("feae34"))
		"frog","spirit":
			Ops.ellipse(im,Vector2i(3,4),Vector2i(3,2),Color("63c74d") if kind=="frog" else Color("ffffff"))
			Ops.rect(im,1,1,2,2,Color("3e8948") if kind=="frog" else Color("ffffff"))
			Ops.rect(im,5,1,2,2,Color("3e8948") if kind=="frog" else Color("ffffff"))
			for x in [2,5]: Ops.rect(im,x,2,1,1,ink)
			Ops.rect(im,6,4,1,1+(f%2),Color("fee761"))
		"snail":
			Ops.ellipse(im,Vector2i(3,3),Vector2i(2,2),Color("68386c"))
			Ops.line(im,Vector2i(1,2),Vector2i(4,0),Color("2ce8f5"))
			Ops.rect(im,0,6,7,1,Color("8b9bb4"))
			Ops.rect(im,6,4,1,2,Color("c0cbdc"))
		"mouse","lizard":
			Ops.ellipse(im,Vector2i(3,4),Vector2i(3,2),Color("8b9bb4") if kind=="mouse" else Color("b86f50"))
			Ops.rect(im,5,3,1,1,Color("fee761"))
			Ops.line(im,Vector2i(0,5),Vector2i(1,7-f%2),Color("733e39"))
			Ops.rect(im,2,6,1,1,ink)
	return im

static func anchors(data: Dictionary, origin: Vector2 = Vector2.ZERO) -> Dictionary:
	warm()
	var result: Dictionary = {"floor":[],"ceiling":[],"liquid":[]}
	var rows: Array = data.get("map",[])
	for y in rows.size():
		for x in rows[y].length():
			var code: String = rows[y][x]
			var p: Vector2 = Vector2(x*16,y*16)+origin
			if code == "#":
				if y>0 and rows[y-1][x] == ".": result.floor.append(p)
				if y<rows.size()-1 and rows[y+1][x] == "." and (x*37+y*13)%3 == 0: result.ceiling.append(p+Vector2(8,16))
			elif code in ["w","a","m"] and (y==0 or rows[y-1][x] == "."):
				result.liquid.append({"at":p,"kind":code})
	return result

static func backdrop(canvas: CanvasItem, theme: String, clock: float, size: Vector2 = Vector2(320,180), seed: int = 1) -> void:
	var phase: float = seed*0.31
	if theme == "sky_island":
		for layer in 3:
			for i in 4:
				var x: float = fposmod(i*(size.x+64)/4+clock*[2,5,10][layer]+layer*39,size.x+64)-32
				var y: float = size.y*(0.22+layer*0.27)+sin(i+phase)*11
				canvas.draw_texture(_textures["cloud%d"%layer],Vector2(x,y).floor(),Color(1,1,1,0.65+layer*0.15))
		var flight: float = fposmod(clock*13+seed*17,size.x+40)-20
		for i in 5:
			var p := Vector2(flight-i*6,27+absi(i-2)*3).floor()
			var flap: int = 1 if int(clock*4+i)%2 else -1
			canvas.draw_line(p+Vector2(-2,flap),p,Color("c0cbdc"))
			canvas.draw_line(p,p+Vector2(2,flap),Color("c0cbdc"))
	elif theme == "cosmos":
		for i in 5:
			var angle: float = i*1.1+clock*0.035+phase
			var orbit := Vector2(size.x/2+cos(angle)*size.x*0.38,size.y/2+sin(angle)*size.y*0.27).floor()
			canvas.draw_texture(_textures.asteroid,orbit)
		for i in 17:
			var p := Vector2(Ops.h32(i,seed)%int(size.x),Ops.h32(i,seed+1)%int(size.y))
			var bright: bool = sin(clock*1.8+i)>0.3
			canvas.draw_line(p-Vector2(0,2),p+Vector2(0,2),Color("ffffff") if bright else Color("5a6988"))
			canvas.draw_line(p-Vector2(2,0),p+Vector2(2,0),Color("ffffff") if bright else Color("5a6988"))
		var p := Vector2(fposmod(clock*7+seed*33,size.x+24)-12,size.y*0.55+sin(clock*1.3)*9).floor()
		canvas.draw_texture(_textures["drone%d"%(int(clock*4)%4)],p)
	else:
		if theme=="forest":
			for i in 4:
				var p := Vector2(26+i*83+sin(clock*1.7+i)*9,39+i%2*86+cos(clock*2.3+i)*5).round()
				canvas.draw_texture(_textures["butterfly"+str(int(clock*6+i)%2)],p)
		elif theme=="dungeon":
			for i in 3:
				var p := Vector2(20+i*131,30+i%2*5)
				canvas.draw_texture(_textures["bat"+str(int(clock*2+i)%4)],p)
				var drop: int = int(fposmod(clock*21+i*17,73))
				canvas.draw_rect(Rect2(p+Vector2(2,8+drop),Vector2(1,2)),Color("0099db"))
		elif theme=="cave":
			for i in 3:
				var p := Vector2(5+i*151+cos(clock*1.5+i)*4,41+i%2*80+sin(clock*2+i)*5).round()
				canvas.draw_texture(_textures["moth"+str(int(clock*4)%2)],p)
		elif theme=="ruins":
			for i in 3:
				var x: float = 13+i*146
				var y: float = fposmod(clock*17+i*19,52)
				canvas.draw_rect(Rect2(x,20+y,1,3),Color("fee761"))
		for i in 12:
			var x: float = fposmod(i*31+clock*(3 if theme=="forest" else 1)+seed*9,size.x)
			var y: float = fposmod(i*23+clock*(7 if theme=="forest" else 2),size.y)
			var color: Color = {"forest":Color("63c74d"),"ruins":Color("feae34"),"cave":Color("2ce8f5"),"dungeon":Color("5a6988")}.get(theme,Color.WHITE)
			canvas.draw_rect(Rect2(Vector2(x,y).floor(),Vector2(2 if theme=="forest" and i%3==0 else 1,1)),color)

static func surface(canvas: CanvasItem, theme: String, clock: float, points: Dictionary, occupied: Array = []) -> void:
	var floors: Array = points.get("floor",[])
	for i in floors.size():
		var at: Vector2 = floors[i]
		var hash: int = (int(at.x/16)*37+int(at.y/16)*13)%7
		if hash>3: continue
		var sway: int = int(clock*2+at.x/16)%2
		var f: int = int(clock*3+i)%4
		var blocked: bool = Vector2i(at/16)+Vector2i.UP in occupied
		if theme in ["forest","sky_island"]:
			canvas.draw_texture(_textures["flower%d%d"%[hash%3,sway]],at+Vector2(3,-6+(1 if blocked else 0)))
			if hash==0:
				var hop: int = -1 if f==2 else 0
				canvas.draw_texture(_textures[("dove" if theme=="sky_island" else "bird")+str(f)],at+Vector2(7,-8+hop-(8 if blocked else 0)))
			if hash==1:
				var flutter := Vector2(sin(clock*2.2+i)*6,cos(clock*3.5+i)*3).round()
				canvas.draw_texture(_textures["butterfly"+str(int(clock*6)%2)],at+Vector2(4,-17)+flutter)
			if hash==2 and theme=="forest":
				canvas.draw_rect(Rect2(at+Vector2(11,-3),Vector2(1,3)),Color("ead4aa"))
				canvas.draw_line(at+Vector2(8,-4),at+Vector2(14,-4),Color("b55088") if f%2 else Color("f6757a"))
				canvas.draw_rect(Rect2(at+Vector2(10,-5),Vector2(3,1)),Color("c0cbdc"))
			if hash==3 and theme=="sky_island":
				canvas.draw_texture(_textures["spirit"+str(f)],at+Vector2(5,-9-roundf(sin(clock*3+i))))
		elif theme == "ruins":
			if hash==0:
				canvas.draw_texture(_textures["beetle"+str(f)],at+Vector2(3+int(sin(clock*0.8+i)*4),-5))
			elif hash==1:
				canvas.draw_texture(Art.themed_texture("lantern_idle_%d"%f,theme),at+Vector2(1,-21))
			elif hash==2:
				canvas.draw_texture(_textures["lizard"+str(f)],at+Vector2(3,-8))
		elif theme == "cave":
			var glow: Color = Color("2ce8f5") if f<2 else Color("b55088")
			canvas.draw_line(at+Vector2(4,0),at+Vector2(3,-7),glow)
			canvas.draw_line(at+Vector2(8,0),at+Vector2(10,-10),glow)
			if hash==1:
				var p: Vector2 = at+Vector2(7+cos(clock*2+i)*9,-14+sin(clock*2+i)*6).round()
				canvas.draw_texture(_textures["moth"+str(f%2)],p)
			if hash==0: canvas.draw_texture(_textures["snail"+str(f)],at+Vector2(6,-8))
		elif theme == "cosmos":
			canvas.draw_rect(Rect2(at+Vector2(3,-2),Vector2(2,1)),[Color("ff0044"),Color("2ce8f5"),Color("fee761"),Color("2ce8f5")][f])
			canvas.draw_line(at+Vector2(8,-1),at+Vector2(13,-1),Color("0099db"))
		elif theme == "dungeon" and hash==1:
			canvas.draw_texture(_textures["mouse"+str(f)],at+Vector2(4,-8))
	for i in points.get("ceiling",[]).size():
		var at: Vector2 = points.ceiling[i]
		if theme in ["cave","dungeon","ruins"]:
			var y: int = int(fposmod(clock*26+i*17,43))
			var color := Color("fee761") if theme=="ruins" else Color("63c74d") if theme=="cave" and i%2 else Color("2ce8f5")
			canvas.draw_rect(Rect2(at+Vector2(0,y),Vector2(1,2)),color)
			if theme=="ruins": canvas.draw_line(at,at+Vector2(0,37),Color(color,0.35))
			if y>37:
				canvas.draw_rect(Rect2(at+Vector2(-2,41),Vector2(1,1)),color)
				canvas.draw_rect(Rect2(at+Vector2(2,40),Vector2(1,1)),color)
		if theme=="dungeon":
			canvas.draw_texture(_textures["bat"+str(int(clock*2+i)%4)],at+Vector2(-4,1))
		elif theme=="forest":
			var tip := at+Vector2(sin(clock*2+i),22+i%3*8).round()
			canvas.draw_line(at,tip,Color("265c42"))
			canvas.draw_line(tip-Vector2(0,7),tip+Vector2(3,-4),Color("3e8948"))
	for pool in points.get("liquid",[]):
		var at: Vector2 = pool.at
		if theme=="cave" and pool.kind in ["m","a"]:
			var f: int = int(clock*4+at.x)%4
			canvas.draw_arc(at+Vector2(8,1),float(1+f),PI,TAU,7,Color("f77622") if pool.kind=="m" else Color("63c74d"))
		elif theme in ["forest","ruins"]:
			canvas.draw_line(at+Vector2(3,1),at+Vector2(11,1),Color("3e8948"))
			if theme=="forest":
				canvas.draw_texture(_textures["frog"+str(int(clock*2)%4)],at+Vector2(5,-6))
			else:
				canvas.draw_line(at+Vector2(2,1),at+Vector2(2+roundf(sin(clock*2)), -6),Color("63c74d"))
				canvas.draw_line(at+Vector2(4,1),at+Vector2(4+roundf(cos(clock*2)),-8),Color("3e8948"))
				canvas.draw_rect(Rect2(at+Vector2(9,-1),Vector2(3,1)),Color("fee761"))

static func prop_name(name: String, clock: float) -> String:
	if name.begins_with("lantern_idle_") or name.begins_with("wind_emitter_"):
		return name.substr(0,name.rfind("_")+1)+str(int(clock*4)%4)
	return name

static func prop_offset(name: String, clock: float, at: Vector2) -> Vector2:
	return Vector2(0,roundf(sin(clock*3+at.x))) if name=="cloud_pad_0" else Vector2.ZERO

var theme_id: String = "dungeon"
var clock: float = 0.0
var extent := Vector2(320,180)
var seed: int = 1
var draw_us: int = 0
func _ready() -> void:
	warm()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	clock += delta
	queue_redraw()
func _draw() -> void:
	var start: int = Time.get_ticks_usec()
	backdrop(self,theme_id,clock,extent,seed)
	draw_us = Time.get_ticks_usec()-start
