#!/usr/bin/env python3
"""Export the supplied character art to fixed, replaceable native-size PNGs."""
import importlib.util
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(__file__).with_name('reference_art.py')
spec = importlib.util.spec_from_file_location('pushbox_reference_art', SOURCE)
art = importlib.util.module_from_spec(spec)
spec.loader.exec_module(art)
OUT = ROOT / 'pushbox/assets/sprites'
OUT.mkdir(parents=True, exist_ok=True)
manifest = {}

def save(name, image, size=None, anchor='top_left', frames=1):
    if size and image.size != size:
        canvas = Image.new('RGBA', size)
        canvas.alpha_composite(image, ((size[0]-image.width)//2, size[1]-image.height))
        image = canvas
    image.save(OUT/f'{name}.png')
    manifest[name] = {'canvas': list(image.size), 'anchor': anchor, 'frames': frames, 'fps': 8}

save('miner_idle_0', art.MINER, (16, 16), 'bottom_center')
save('crate_static_0', art.CRATE, (16, 16))
save('ladder_static_0', art.LADDER, (16, 16))
for action, count in [('idle',4),('lit',2)]:
    for frame in range(count):
        image = art.TARGET.copy()
        if frame % 2:
            for y in range(16):
                for x in range(16):
                    if image.getpixel((x,y)) == art.rgb('gold'):
                        image.putpixel((x,y), art.rgb('sand_l' if action == 'idle' else 'white'))
        save(f'target_{action}_{frame}', image, (16,16))
save('lever_left_0', art.LEVER_UP, (16, 16))
save('lever_right_0', art.LEVER_DOWN, (16, 16))
save('icon_bomb', art.BOMB, (12, 12))
for i in range(8):
    save(f'icon_sandbag_{i}', art.sand_bag(i/7), (12, 12))
save('mouse_left', art.MOUSE_L, (11, 14))
save('mouse_right', art.MOUSE_R, (11, 14))
save('hand_point', art.HAND, (12, 13))
save('hand_drag', art.HAND, (12, 13))
save('cursor_shovel', art.SHOVEL, (11, 11))
for direction in ['UP', 'DOWN', 'LEFT', 'RIGHT']:
    save(f'keycap_{direction.lower()}', art.keycap(direction), (13, 13))
for letter in ['z', 'r']:
    image = art.sprite(art._KEY_BASE, art.L)
    d = ImageDraw.Draw(image)
    lines = ['11111','00010','00100','01000','11111'] if letter == 'z' else ['11110','10001','11110','10100','10010']
    for y, row in enumerate(lines):
        for x, value in enumerate(row):
            if value == '1': d.point((x+4,y+3), fill=art.rgb('ink'))
    save(f'keycap_{letter}', image, (13, 13))
panel = Image.new('RGBA', (9, 9))
art.panel(panel, 0, 0, 9, 9, border='grey')
save('panel_9slice', panel)
for state in ['up', 'down']:
    image = Image.new('RGBA', (16, 4)); d = ImageDraw.Draw(image)
    d.rectangle((1, 1 if state == 'up' else 2, 14, 3), fill=art.rgb('ink'))
    d.line((2, 1 if state == 'up' else 2, 13, 1 if state == 'up' else 2), fill=art.rgb('grey' if state == 'up' else 'yellow'))
    save(f'plate_{state}_0', image)
gate = Image.new('RGBA', (16, 32)); d = ImageDraw.Draw(gate)
for x in [2, 7, 12]:
    d.rectangle((x, 0, x+2, 31), fill=art.rgb('ink'))
    d.line((x, 0, x, 30), fill=art.rgb('grey'))
    d.line((x+1, 0, x+1, 31), fill=art.rgb('slate'))
for y in [1, 15, 29]:
    d.rectangle((1,y,14,y+2), fill=art.rgb('ink'))
    d.line((2,y,13,y), fill=art.rgb('grey'))
save('gate_closed_0', gate)
for i in range(6):
    image = Image.new('RGBA', (16,32))
    image.alpha_composite(gate, (0, -round((i+1)*32/6)))
    save(f'gate_open_{i}', image)
for i in range(2):
    image=art.sprite(['...kk...','..kggk..','..k..k..','.kkkkkk.','.kyllyk.','.kYllYk.','.kYllYk.','.kyllyk.','.kYYYYk.','.kkkkkk.','...kk...','........'], art.L)
    if i: image.putpixel((3,5),art.rgb('sand_l'))
    save(f'lantern_idle_{i}',image,(8,12),'top_center')

# Fixed poses derived from the reference miner, with limbs changing inside 16×16.
for action, count in {'idle':2,'walk':4,'push':4,'climb':2,'dig':3,'pour':3,'fall':1,'win':2}.items():
    for frame in range(count):
        image=art.MINER.copy(); d=ImageDraw.Draw(image)
        if action in ['walk','push']:
            d.rectangle((3,13,13,15), fill=(0,0,0,0))
            shift=[-1,0,1,0][frame]
            d.rectangle((5+shift,13,7+shift,15),fill=art.rgb('ink'))
            d.rectangle((10-shift,13,12-shift,15),fill=art.rgb('ink'))
        if action in ['push','dig','pour']:
            d.rectangle((11,9,14,10),fill=art.rgb('ink'))
            d.line((11,9,13,9),fill=art.rgb('skin'))
        if action == 'dig': image.alpha_composite(art.SHOVEL,(7,6+frame))
        if action == 'pour':
            for y in range(10,14): d.point((13+(y+frame)%2,y),fill=art.rgb('sand'))
        if action in ['climb','win']:
            d.line((3,7+frame,3,9+frame),fill=art.rgb('skin'))
            d.line((12,7-frame,12,9-frame),fill=art.rgb('skin'))
        save(f'miner_{action}_{frame}',image,(16,16),'bottom_center')
for variant in range(2):
    rock=Image.new('RGBA',(16,16),art.rgb('slate_d')); d=ImageDraw.Draw(rock)
    d.line((0,0,15,0),fill=art.rgb('navy'));d.line((0,0,0,15),fill=art.rgb('navy'))
    d.line((1,1,15,1),fill=art.rgb('slate'));d.line((1,1,1,15),fill=art.rgb('slate'))
    d.line((3+variant*4,9,7+variant*4,9),fill=art.rgb('navy'))
    save(f'tex_bedrock_{variant}',rock)
    cracked=Image.new('RGBA',(16,16),art.rgb('skin_d')); d=ImageDraw.Draw(cracked)
    d.line((0,0,15,0),fill=art.rgb('sand'));d.line((0,0,0,15),fill=art.rgb('sand'))
    d.line([(9,0),(7,4),(10,7),(6,10),(8,15)],fill=art.rgb('brown_d'),width=2)
    d.line([(8,5),(3,6),(0,4)],fill=art.rgb('brown_d'))
    d.line([(7,10),(12,11),(15,14)],fill=art.rgb('brown_d'))
    save(f'tex_cracked_{variant}',cracked)
background=Image.new('RGBA',(320,180),art.rgb('ink'));d=ImageDraw.Draw(background)
for y in range(0,180,16):
    for x in range(-16,320,32):
        offset=16 if (y//16)%2 else 0
        d.rectangle((x+offset,y,x+offset+30,y+14),fill=art.rgb('navy'))
# Quiet, broad masonry; sparse roots, never per-pixel noise.
for x in [88,218]:
    d.line([(x,36),(x+2,43),(x-1,48),(x+2,55)],fill=art.rgb('brown_d'))
save('cave_bg',background)
(OUT/'manifest.json').write_text(json.dumps({'source':str(SOURCE.relative_to(ROOT)),'placeholder':True,'palette':art.E,'sprites':manifest},ensure_ascii=False,indent=2)+'\n')
print(f'Exported {len(manifest)} fixed-canvas placeholder sprites')
