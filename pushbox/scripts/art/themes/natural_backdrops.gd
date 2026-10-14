extends RefCounted
## Cached, palette-limited silhouette stamps. Nothing here runs per frame.
const Ops := preload("res://pushbox/scripts/art/canvas_ops.gd")
static func forest(size: Vector2i) -> Image:
	var image: Image = Ops.canvas(size,Color("193c3e"))
	for layer in 2:
		for i in 7:
			var x: int = (i*57+layer*29+(i%3)*13)%size.x
			var crown: int = 22+(i*17)%46
			var tone := Color("265c42") if layer == 0 else Color("3e2731")
			Ops.polygon(image,PackedVector2Array([Vector2(x-9,0),Vector2(x+8,0),Vector2(x+5,size.y-30),Vector2(x+27,size.y),Vector2(x-30,size.y),Vector2(x-6,size.y-40)]),tone)
			for branch in 3:
				var yy: int = crown+branch*29
				var dir: int = 1 if (i+branch)%2 else -1
				Ops.line(image,Vector2i(x,yy+15),Vector2i(x+dir*25,yy),tone)
				Ops.line(image,Vector2i(x+dir*25,yy),Vector2i(x+dir*39,yy-5),tone)
			for leaf in 5:
				Ops.ellipse(image,Vector2i(x+(leaf-2)*13,crown-14-absi(leaf-2)*5),Vector2i(22,12+leaf%3),Color("265c42") if layer else Color("3e8948"))
			Ops.line(image,Vector2i(x+3,crown+30),Vector2i(x+1,size.y-25),Color("733e39") if layer else tone)
	for i in 4:
		var x: int = 51+i*67
		for y in size.y:
			var left: int = x-y/3
			for xx in range(left,left+5+y/25):
				if (xx+y)%4 == 0:
					Ops.rect(image,xx,y,1,1,Color("3e8948"))
		for y in range(3,30+i*7):
			var vx: int = x+int(sin(y*0.25)*2)
			Ops.rect(image,vx,y,1,1,Color("63c74d") if y%6 == 0 else Color("265c42"))
	return image

static func sky(size: Vector2i) -> Image:
	var image: Image = Ops.canvas(size)
	var colors: Array[Color] = [Color("3a4466"),Color("68386c"),Color("b55088"),Color("f6757a"),Color("e8b796")]
	var bayer: Array[int] = [0,2,3,1]
	for y in size.y:
		var value: float = clampf(float(y)/size.y*4.4,0,4)
		var low: int = floori(value)
		for x in size.x:
			var chosen: int = mini(4,low+(1 if (value-low)*4>bayer[(y%2)*2+x%2] else 0))
			image.set_pixel(x,y,colors[chosen])
	Ops.ellipse(image,Vector2i(size.x*3/4,size.y/3),Vector2i(15,15),Color("ead4aa"))
	for i in 4:
		var x: int = (i*91+26)%size.x
		var y: int = size.y*3/4+(i%2)*19
		Ops.polygon(image,PackedVector2Array([Vector2(x-23,y),Vector2(x+28,y-3),Vector2(x+15,y+9),Vector2(x,y+24),Vector2(x-14,y+9)]),Color("68386c"))
	return image

static func ruins(size: Vector2i) -> Image:
	var image: Image = Ops.canvas(size,Color("3e2731"))
	for i in 5:
		var x: int = 21+i*(size.x-35)/4
		var top: int = 20+(i%2)*6
		Ops.polygon(image,PackedVector2Array([Vector2(x-14,top),Vector2(x+14,top),Vector2(x+9,top+14),Vector2(x+6,size.y-12),Vector2(x-9,size.y-12),Vector2(x-10,top+14)]),Color("733e39"))
		Ops.line(image,Vector2i(x-6,top+15),Vector2i(x-5,size.y-14),Color("b86f50"))
		Ops.line(image,Vector2i(x+4,top+15),Vector2i(x+4,size.y-14),Color("3e2731"))
		Ops.ellipse(image,Vector2i(x-10,top+3),Vector2i(5,4),Color("b86f50"))
		Ops.ellipse(image,Vector2i(x+10,top+3),Vector2i(5,4),Color("b86f50"))
		Ops.rect(image,x-12,top+9,24,2,Color("b86f50"))
		Ops.line(image,Vector2i(x-4,top+31),Vector2i(x+3,top+38),Color("b86f50"))
		Ops.line(image,Vector2i(x+3,top+38),Vector2i(x-4,top+45),Color("b86f50"))
		Ops.polygon(image,PackedVector2Array([Vector2(x-15,size.y-10),Vector2(x+13,size.y-10),Vector2(x+18,size.y),Vector2(x-20,size.y)]),Color("733e39"))
	for x in range(5,size.x,37):
		for y in range(12,size.y,8):
			if (x+y)%3 == 0:
				Ops.rect(image,x+y/5,y,1,1,Color("b86f50"))
	return image

static func cave(size: Vector2i) -> Image:
	var image: Image = Ops.canvas(size,Color("181425"))
	for layer in 3:
		var points := PackedVector2Array([Vector2(0,0)])
		for x in range(0,size.x+16,16):
			points.append(Vector2(x,18+layer*12+Ops.h32(x,layer)%38))
		points.append(Vector2(size.x,0))
		Ops.polygon(image,points,[Color("262b44"),Color("193c3e"),Color("3a4466")][layer])
	for i in 17:
		var x: int = (i*43+19)%size.x
		var length: int = 15+Ops.h32(i,4)%44
		Ops.polygon(image,PackedVector2Array([Vector2(x-8,0),Vector2(x+10,0),Vector2(x+2,length)]),Color("262b44"))
		Ops.line(image,Vector2i(x-4,2),Vector2i(x+2,length-3),Color("5a6988"))
		var y: int = size.y-5-Ops.h32(i,7)%25
		Ops.polygon(image,PackedVector2Array([Vector2(x-18,size.y),Vector2(x,y-28),Vector2(x+18,size.y)]),Color("262b44"))
		if i%3 == 0:
			for k in 3:
				Ops.polygon(image,PackedVector2Array([Vector2(x+k*5,y+4),Vector2(x+k*5-2,y-8-k*5),Vector2(x+k*5+2,y-13-k*3),Vector2(x+k*5+4,y+4)]),Color("124e89") if k%2 else Color("68386c"))
				Ops.line(image,Vector2i(x+k*5+2,y-12-k*3),Vector2i(x+k*5+1,y+1),Color("0099db") if k%2 else Color("b55088"))
	return image

static func cosmos(size: Vector2i) -> Image:
	var image: Image = Ops.canvas(size,Color("181425"))
	for y in size.y:
		for x in size.x:
			var distance: float = absf(y-x*0.4-size.y*0.15+sin(x*0.033)*12)
			if distance < 29 and (x+y)%3 != 0:
				image.set_pixel(x,y,Color("262b44"))
			if distance < 11 and (x+y)%4 == 0:
				image.set_pixel(x,y,Color("68386c"))
	for i in 23:
		var x: int = (i*67+23)%size.x
		var y: int = (x*2/5+size.y/3+Ops.h32(i,4)%39)%size.y
		var r: int = 2+i%4
		Ops.ellipse(image,Vector2i(x,y),Vector2i(r,r-1),Color("3a4466"))
		Ops.line(image,Vector2i(x-r+1,y-1),Vector2i(x,y-r+1),Color("5a6988"))
	for i in 52:
		Ops.rect(image,Ops.h32(i,1)%size.x,Ops.h32(i,2)%size.y,1,1,Color("8b9bb4"))
	for x in [0,size.x-1]:
		Ops.line(image,Vector2i(x,0),Vector2i(x+(36 if x==0 else -36),36),Color("3a4466"))
		Ops.line(image,Vector2i(x,size.y-1),Vector2i(x+(36 if x==0 else -36),size.y-37),Color("3a4466"))
	return image

static func dungeon(size: Vector2i) -> Image:
	var image: Image = Ops.canvas(size,Color("181425"))
	for i in 4:
		var x: int = 33+i*(size.x-55)/3
		Ops.ellipse(image,Vector2i(x,47),Vector2i(30,35),Color("3a4466"))
		Ops.ellipse(image,Vector2i(x,48),Vector2i(24,28),Color("262b44"))
		Ops.polygon(image,PackedVector2Array([Vector2(x-23,47),Vector2(x+23,47),Vector2(x+20,size.y),Vector2(x-24,size.y)]),Color("262b44"))
		for y in range(73,size.y,19):
			Ops.line(image,Vector2i(x-22,y),Vector2i(x+21,y-2),Color("181425"))
			Ops.line(image,Vector2i(x+((y/19)%2)*18-9,y),Vector2i(x+((y/19)%2)*18-9,y+17),Color("181425"))
		for y in range(0,27+i*5,4):
			Ops.rect(image,x+17,y,2,3,Color("5a6988"))
	return image
