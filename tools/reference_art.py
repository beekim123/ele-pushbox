"""样稿用的公共美术：调色板、像素精灵、文字、噪声。只用于画样稿，不是游戏代码。

调色板 ENDESGA 32（Lospec）。精灵用字符画定义，一个字符一个像素，'.' 透明。
"""
from PIL import Image, ImageDraw, ImageFont

E = {  # ENDESGA 32
    'rust': '#be4a2f', 'orange_d': '#d77643', 'sand_l': '#ead4aa', 'sand': '#e4a672', 'clay': '#b86f50',
    'brown': '#733e39', 'brown_d': '#3e2731', 'red_d': '#a22633', 'red': '#e43b44', 'orange': '#f77622',
    'gold': '#feae34', 'yellow': '#fee761', 'green': '#63c74d', 'green_d': '#3e8948', 'green_dd': '#265c42',
    'teal_dd': '#193c3e', 'blue_d': '#124e89', 'blue': '#0099db', 'cyan': '#2ce8f5', 'white': '#ffffff',
    'grey_l': '#c0cbdc', 'grey': '#8b9bb4', 'slate': '#5a6988', 'slate_d': '#3a4466', 'navy': '#262b44',
    'ink': '#181425', 'magenta': '#ff0044', 'plum': '#68386c', 'pink_d': '#b55088', 'pink': '#f6757a',
    'skin': '#e8b796', 'skin_d': '#c28569',
}


def rgb(name, a=255):
    h = E[name] if name in E else name
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), a)


def h32(x, y, s=0):
    """确定性整数噪声。"""
    n = (x * 374761393 + y * 668265263 + s * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return n ^ (n >> 16)


def sprite(rows, legend):
    w, h = max(len(r) for r in rows), len(rows)
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = im.load()
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c != '.' and c != ' ':
                px[x, y] = rgb(legend[c])
    return im


def paste(base, spr, x, y, flip=False):
    if flip:
        spr = spr.transpose(Image.FLIP_LEFT_RIGHT)
    base.alpha_composite(spr, (int(x), int(y)))


FONT_PATH = '/System/Library/Fonts/STHeiti Light.ttc'  # 样稿替身；正式用缝合像素字体 12px
_font = {}


def font(size=12):
    if size not in _font:
        _font[size] = ImageFont.truetype(FONT_PATH, size)
    return _font[size]


def text_size(s, size=12):
    d = ImageDraw.Draw(Image.new('RGBA', (1, 1)))
    d.fontmode = '1'
    b = d.textbbox((0, 0), s, font=font(size))
    return b[2] - b[0], b[3] - b[1]


def text(img, x, y, s, color='white', outline='ink', size=12, center=False):
    """像素字：不抗锯齿，1 像素描边（8 方向）。"""
    if center:
        w, _ = text_size(s, size)
        x -= w // 2
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.fontmode = '1'
    if outline:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if dx or dy:
                    d.text((x + dx, y + dy - 1), s, font=font(size), fill=rgb(outline))
    d.text((x, y - 1), s, font=font(size), fill=rgb(color))
    img.alpha_composite(layer)


def blend(c1, c2, t):
    return tuple(int(c1[i] * (1 - t) + c2[i] * t) for i in range(3)) + (255,)


def panel(img, x, y, w, h, fill='navy', border='slate', light='grey'):
    """像素九宫格面板：1 像素描边、圆角缺一个像素、左上亮边、右下暗边。"""
    d = ImageDraw.Draw(img)
    d.rectangle([x + 1, y + 1, x + w - 2, y + h - 2], fill=rgb(fill))
    d.line([x + 1, y, x + w - 2, y], fill=rgb('ink'))
    d.line([x + 1, y + h - 1, x + w - 2, y + h - 1], fill=rgb('ink'))
    d.line([x, y + 1, x, y + h - 2], fill=rgb('ink'))
    d.line([x + w - 1, y + 1, x + w - 1, y + h - 2], fill=rgb('ink'))
    d.line([x + 2, y + 1, x + w - 3, y + 1], fill=rgb(light))
    d.line([x + 1, y + 2, x + 1, y + h - 3], fill=rgb(border))
    d.line([x + 2, y + h - 2, x + w - 3, y + h - 2], fill=rgb('ink'))


# ---------------------------------------------------------------- 精灵
L = dict(k='ink', y='gold', Y='orange', l='yellow', s='skin', S='skin_d', r='red', R='red_d', b='slate_d', B='navy',
         h='brown', w='white', e='ink', o='clay', O='brown', p='sand', P='brown_d', g='grey', G='slate', c='cyan',
         C='blue', d='blue_d', m='pink_d', M='plum', n='pink', q='sand_l', x='green', X='green_d', z='green_dd',
         t='orange_d', u='rust', v='grey_l', a='magenta')

MINER = sprite([
    '................',
    '.....kkkkk......',
    '....kyyyyykk....',
    '...kyyyyyyylk...',
    '...kYYYYYYYYk...',
    '....kssssesk....',
    '....kssssssk....',
    '.....kSSSSk.....',
    '....krrrrrrk....',
    '...ksrrrrrrsk...',
    '...kSkRrrRkSk...',
    '....kRRRRRRk....',
    '....kbbbbbbk....',
    '....kbbkkbbk....',
    '....khhk.khhk...',
    '....kkkk.kkkk...',
], L)

CRATE = sprite([
    'PPPPPPPPPPPPPPPP',
    'PppppppppppppppP',
    'PpOOOOOOOOOOOopP',
    'PpOoooooooooOOpP',
    'PpOoOoooooooOOpP',
    'PpOooOoooooooOpP',
    'PpOoooOooooooOpP',
    'PpOooooOoooooOpP',
    'PpOoooooOooooOpP',
    'PpOooooooOoooOpP',
    'PpOoooooooOooOpP',
    'PpOooooooooOoOpP',
    'PpOOoooooooooOpP',
    'PpOOOOOOOOOOOOpP',
    'PppppppppppppppP',
    'PPPPPPPPPPPPPPPP',
], dict(L, p='sand', o='clay', O='brown', P='brown_d'))

LADDER = sprite([
    '..OO........OO..',
    '..Oo........oO..',
    '..OoOOOOOOOOoO..',
    '..OoppppppppoO..',
    '..Oo........oO..',
    '..Oo........oO..',
    '..OoOOOOOOOOoO..',
    '..OoppppppppoO..',
    '..Oo........oO..',
    '..Oo........oO..',
    '..OoOOOOOOOOoO..',
    '..OoppppppppoO..',
    '..Oo........oO..',
    '..Oo........oO..',
    '..OoOOOOOOOOoO..',
    '..OoppppppppoO..',
], dict(L, p='skin_d', o='clay', O='brown'))

TARGET = sprite([
    'lll..........lll',
    'l..............l',
    'l..............l',
    '................',
    '................',
    '.......ll.......',
    '......lyyl......',
    '.....lyyyyl.....',
    '.....lyyyyl.....',
    '......lyyl......',
    '.......ll.......',
    '................',
    '................',
    'l..............l',
    'l..............l',
    'lll..........lll',
], L)

LEVER_UP = sprite([
    '................', '................', '................', '................',
    '..........kk....', '.........krrk...', '.........krRk...', '........kok.....',
    '.......kok......', '......kok.......', '.....kok........', '....kok.........',
    '..kkkkkkkkkkk...', '..kgggggggggk...', '..kGGGGGGGGGk...', '..kkkkkkkkkkk...',
], L)
LEVER_DOWN = LEVER_UP.transpose(Image.FLIP_LEFT_RIGHT)

_KEY_BASE = [
    '.kkkkkkkkkkk.', 'kqqqqqqqqqqqk', 'kqqqqqqqqqqqk', 'kqqqqqqqqqqqk', 'kqqqqqqqqqqqk', 'kqqqqqqqqqqqk',
    'kqqqqqqqqqqqk', 'kqqqqqqqqqqqk', 'kqqqqqqqqqqqk', 'kqqqqqqqqqqqk', 'kgggggggggggk', 'kGGGGGGGGGGGk', '.kkkkkkkkkkk.',
]
_ARROW_UP = ['.....k.....', '....kkk....', '...kkkkk...', '..kkkkkkk..', '....kkk....', '....kkk....', '....kkk....']


def keycap(glyph):
    """键帽 13×13。glyph: 'UP' 'DOWN' 'LEFT' 'RIGHT' 或一个字母。"""
    im = sprite(_KEY_BASE, L)
    if glyph in ('UP', 'DOWN', 'LEFT', 'RIGHT'):
        a = sprite(_ARROW_UP, L)
        a = {'UP': a, 'DOWN': a.rotate(180), 'LEFT': a.rotate(90, expand=True), 'RIGHT': a.rotate(-90, expand=True)}[glyph]
        im.alpha_composite(a, ((13 - a.width) // 2 + 1 - 1, (11 - a.height) // 2 + 1))
    else:
        d = ImageDraw.Draw(im)
        d.fontmode = '1'
        d.text((3, 0), glyph, font=font(11), fill=rgb('ink'))
    return im


MOUSE_L = sprite([
    '..kkkkkkk..', '.kyyyykwwk.', 'kyyyyykwwwk', 'kyyyyykwwwk', 'kyyyyykwwwk', 'kkkkkkkkkkk',
    'kwwwwwwwwwk', 'kwwwwwwwwwk', 'kwwwwwwwwwk', 'kwwwwwwwwwk', 'kvvvvvvvvvk', '.kvvvvvvvk.', '..kkkkkkk..',
], L)
MOUSE_R = MOUSE_L.transpose(Image.FLIP_LEFT_RIGHT)

HAND = sprite([
    '....kk......', '...kwwk.....', '...kwwk.....', '...kwwkkk...', '...kwwkwwkk.', '.kkkwwkwwkwk',
    'kwwkwwwwwkwk', 'kwwwwwwwwwwk', '.kwwwwwwwwwk', '.kwwwwwwwwk.', '..kwwwwwwwk.', '..kvvvvvvk..', '...kkkkkk...',
], L)

BOMB = sprite([
    '........lY..', '.......Y....', '......oO....', '....kkOkk...', '...kGGGBBk..', '..kGgGBBBBk.',
    '..kGGBBBBBk.', '..kBBBBBBBk.', '..kBBBBBBBk.', '...kBBBBBk..', '....kkkkk...', '............',
], L)


def sand_bag(fill):
    """沙袋图标 12×12，fill 0..1 画出袋里沙的高度。"""
    im = sprite([
        '...kkkkkk...', '..kOkkkkOk..', '...kOOOOk...', '..kOooooOk..', '.kOooooooOk.', 'kOooooooooOk',
        'kOooooooooOk', 'kOooooooooOk', 'kOooooooooOk', 'kOooooooooOk', '.kOOOOOOOOk.', '..kkkkkkkk..',
    ], dict(L, o='clay', O='brown'))
    px = im.load()
    top = 10 - int(round(fill * 7))
    for y in range(top, 10):
        for x in range(12):
            if px[x, y] == rgb('clay'):
                px[x, y] = rgb('sand') if (x + y) % 3 else rgb('sand_l')
    return im


HEART = sprite(['.kk.kk..', 'krrkrrk.', 'krnrrrrk', 'krrrrrrk', '.krrrrk.', '..krrk..', '...kk...'], L)
COIN = sprite(['.kkkk.', 'kllyyk', 'klyyYk', 'kyyyYk', 'kyYYYk', '.kkkk.'], L)
FLAG_ICON = sprite(['kkkkk..', 'kRrrrk.', 'kRrrrrk', 'kRrrrk.', 'kkkkk..', 'k......', 'k......', 'k......'], L)
LOCK = sprite(['.kkk.', 'k...k', 'kkkkk', 'kgggk', 'kgGgk', 'kkkkk'], L)
PAUSE = sprite(['kkk.kkk', 'kwk.kwk', 'kwk.kwk', 'kwk.kwk', 'kwk.kwk', 'kwk.kwk', 'kkk.kkk'], L)
FAST = sprite(['kk..kk...', 'kwk.kwk..', 'kwwkkwwk.', 'kwwwkwwwk', 'kwwkkwwk.', 'kwk.kwk..', 'kk..kk...'], L)
SHOVEL = sprite([
    '.......kk', '......kok', '.....kok.', '....kok..', '.kkkok...', 'kgggk....', 'kgvgk....', 'kggk.....', '.kk......',
], L)

# 塔防单位
MOLE = sprite([
    '....kkkk....', '..kkttttkk..', '.kttttttttk.', 'ktttttttwekk', 'ktutttttttnk', 'kuuttttttkk.',
    'kuuuuuuuuk..', '.kqkkqkqk...', '..k..k.k....',
], dict(L, t='orange', u='rust'))
BEETLE = sprite([
    '...kkkkkk...', '.kkxxxxxxkk.', 'kxxXxxxxxxkk', 'kXXXXxxxxwek', 'kzzzzzzzzzkk', '.kkkkkkkkkk.', '.k.k..k.k...',
], L)
BRUTE = sprite([
    '...q......q.......', '..qq......qq......', '..kkkkkkkkkkk.....', '.kmmmmmmmmmmmk....', 'kmmnmmmmmmmmmmkk..',
    'kmMMmmmmmmmmwekk..', 'kMMMMmmmmmmmmmmk..', 'kMMMMMMmmmmmmmk...', 'kgMMMMMMMMMMMMk...', 'kggMMMMMMMMMMk....',
    '.kgggggggggggk....', '.kkkGkkkkGkkk.....', '..kGk...kGk.......', '..kkk...kkk.......',
], L)
CROSSBOW = sprite([
    'kkkkkkkkkkkkkkkk', 'kGGGGGGGGGGGGGGk', '.kkkkkkGkkkkkkk.', '......kGk.......', '......kok.......',
    '..kkk.kok.kkk...', '.kOOOkkokkOOOk..', 'kO...kooook...Ok', 'k....kooook....k', '.....kooook.....',
    '......kook......', '......kqqk......', '.......kk.......',
], L)
FROSTT = sprite([
    'kkkkkkkkkkkkkkkk', 'kGGGGGGGGGGGGGGk', '.kkkkkGGGGkkkkk.', '.....kGggGk.....', '......kcck......',
    '.....kcwcck.....', '....kcwccCck....', '....kccccCck....', '....kcccCCdk....', '.....kcCCdk.....',
    '......kCdk......', '.......kk.......',
], L)
CORE = sprite([
    '.........kk.........', '........kwnk........', '.......kwnnmk.......', '......kwnnnmmk......', '......kwnnnmmk......',
    '.....kwnnnnmmMk.....', '.....kwnnnnmmMk.....', '....kwnnnnnmmMMk....', '....kwnnnnnmmMMk....', '....kwnnnnmmmMMk....',
    '...kwnnnnnmmmMMMk...', '...kwnnnnnmmmMMMk...', '...kwnnnnmmmmMMMk...', '...kwnnnnmmmmMMMk...', '..kwnnnnnmmmmMMMMk..',
    '..kwnnnnnmmmmMMMMk..', '..kwnnnnmmmmmMMMMk..', '..kwnnnnmmmmmMMMMk..', '..kwnnnnmmmmmMMMMk..', '...kwnnnmmmmMMMMk...',
    '...kwnnnmmmmMMMk....', '....kwnnmmmMMMk.....', '....kgGGGGGGGGGk....', '...kgGGGGGGGGGGGk...', '..kggGGGGGGGGGGGGk..',
    '..kkkkkkkkkkkkkkkk..',
], L)
BANNER = sprite([
    'kk..........', 'kgkkkkkkkkk.', 'kgkRRRRRRRRk', 'kgkRrrrrrrRk', 'kgkRrqqqqrRk', 'kgkRrqkqkrRk', 'kgkRrqqqqrRk',
    'kgkRrrqqrrRk', 'kgkRrrrrrrRk', 'kgkRRrRRrRRk', 'kgkkRk.kRkk.', 'kgk.k...k...', 'kgk.........', 'kgk.........',
    'kgk.........', 'kgk.........', 'kgk.........', 'kgk.........', 'kgk.........', 'kgk.........', 'kgk.........',
    'kgk.........', 'kgk.........', 'kgk.........', 'kGk.........', 'kGk.........', 'kGk.........', 'kGk.........',
    'kkkk........',
], L)
