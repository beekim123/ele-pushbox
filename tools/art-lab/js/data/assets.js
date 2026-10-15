const ASSET_CATALOG = [
  // -------------------- 【1. 角色 Characters】 --------------------
  {
    id: "miner_idle", name: "矿工 · 待机呼吸", category: "character", biome: "all", fps: 2,
    desc: "主角默认站立与呼吸姿态，头戴矿灯安全帽，1px #181425 深色轮廓描边。",
    frames: [
      [
        "................",".....zzzzz......","....zkkkkkzz....","...zkkkkkkklz...",
        "...zjjjjjjjjz...","....zEEEEzEz....","....zEEEEEEz....",".....zFFFFz.....",
        "....ziiiiiiz....","...zEiiiiiiEz...","...zFzhiihzFz...","....zhhhhhhz....",
        "....zxxxxxxz....","....zxxzzxxz....","....zffz.zffz...","....zzzz.zzzz..."
      ],
      [
        "................","................",".....zzzzz......","....zkkkkkzz....",
        "...zkkkkkkklz...","...zjjjjjjjjz...","....zEEEEzEz....","....zEEEEEEz....",
        ".....zFFFFz.....","...zEiiiiiiEz...","...zFzhiihzFz...","....zhhhhhhz....",
        "....zxxxxxxz....","....zxxzzxxz....","....zffz.zffz...","....zzzz.zzzz..."
      ]
    ]
  },
  {
    id: "miner_walk", name: "矿工 · 行走奔跑", category: "character", fps: 8, biome: "all",
    desc: "4 帧横向移动步伐循环，支持左右镜像翻转。",
    frames: [
      [
        "................",".....zzzzz......","....zkkkkkzz....","...zkkkkkkklz...",
        "...zjjjjjjjjz...","....zEEEEzEz....","....zEEEEEEz....",".....zFFFFz.....",
        "....ziiiiiiz....","...zEiiiiiiEz...","...zFzhiihzFz...","....zhhhhhhz....",
        "....zxxxxxxz....","....zzz....zzz..","....zzz....zzz..","....zzz....zzz.."
      ],
      [
        "................",".....zzzzz......","....zkkkkkzz....","...zkkkkkkklz...",
        "...zjjjjjjjjz...","....zEEEEzEz....","....zEEEEEEz....",".....zFFFFz.....",
        "....ziiiiiiz....","...zEiiiiiiEz...","...zFzhiihzFz...","....zhhhhhhz....",
        "....zxxxxxxz....",".....zzz..zzz...",".....zzz..zzz...",".....zzz..zzz..."
      ],
      [
        "................",".....zzzzz......","....zkkkkkzz....","...zkkkkkkklz...",
        "...zjjjjjjjjz...","....zEEEEzEz....","....zEEEEEEz....",".....zFFFFz.....",
        "....ziiiiiiz....","...zEiiiiiiEz...","...zFzhiihzFz...","....zhhhhhhz....",
        "....zxxxxxxz....","......zzzzzz....","......zzzzzz....","......zzzzzz...."
      ]
    ]
  },
  {
    id: "miner_dig", name: "矿工 · 挥铲挖沙", category: "character", fps: 8, biome: "all",
    desc: "向右前下方挥铲的 3 帧动作：蓄力、铲入、回收；双手握柄，铲头位于身体前方，左向可镜像。",
    frames: [
      [
        "................","....zzzzz.......","...zkkkkkzz.....","..zkkkkkkklz....",
        "..zjjjjjjjjz....","...zEEEEzEz.....","...zEEEEEEz.....","....zFFFFz......",
        "...ziEEEEz......","...ziFFFfE......","...zhhhhzFfzz...","....zhhhhzzzuvz.",
        "....zxxxxz.zuvvz","...zxxz.zxxzzvvz","...zffz.zffz.zz.","...zzzz.zzzz...."
      ],
      [
        "................","................",".....zzzzz......","....zkkkkkzz....",
        "...zkkkkkkklz...","...zjjjjjjjjz...","....zEEEEzEz....","....zEEEEEEz....",
        ".....zFFFFz.....",".....ziiiiiz....","....iEEEiEz.....","....zFFFffEzz...",
        "....zhhhzzFzuvz.","...zxxxzzxzzuvvz","..zffz..zffzzvvz","..zzzz..zzzz.zz."
      ],
      [
        "................",".....zzzzz......","....zkkkkkzz....","...zkkkkkkklz...",
        "...zjjjjjjjjz...","....zEEEEzEz....","....zEEEEEEz....",".....zFFFFz.....",
        "....ziiiiiz.....","....iEEEEiz.....","...zhFFFfEzz....","....zhhhzFzuvz..",
        "....zxxxxzzuvvz.","...zxxz.zxxzvvz.","...zffz.zffzzz..","...zzzz.zzzz...."
      ]
    ]
  },
  {
    id: "miner_pour", name: "矿工 · 倾倒沙袋", category: "character", fps: 6, biome: "all",
    desc: "右键向相邻格倾倒沙粒时的扬沙动作帧。",
    frames: [
      [
        "................",".....zzzzz......","....zkkkkkzz....","...zkkkkkkklz...",
        "...zjjjjjjjjz...","....zEEEEzEz....","....zEEEEEEz....",".....zFFFFz.....",
        "....ziiiiiiz....","...zEiiiiiiEEEz.","...zFzhiihzzzdz.","....zhhhhhhz..d.",
        "....zxxxxxxz.d..","....zxxzzxxz..d.","....zffz.zffz...","....zzzz.zzzz..."
      ],
      [
        "................",".....zzzzz......","....zkkkkkzz....","...zkkkkkkklz...",
        "...zjjjjjjjjz...","....zEEEEzEz....","....zEEEEEEz....",".....zFFFFz.....",
        "....ziiiiiiz....","...zEiiiiiiEEEz.","...zFzhiihzzzzd.","....zhhhhhhz.d..",
        "....zxxxxxxz..d.","....zxxzzxxz.d..","....zffz.zffz...","....zzzz.zzzz..."
      ]
    ]
  },
  {
    id: "miner_climb", name: "矿工 · 攀爬梯子/藤蔓", category: "character", fps: 6, biome: "all",
    desc: "上下攀爬木梯、藤蔓梯或磁吸导轨及过关欢呼动作。",
    frames: [
      [
        "................",".....zzzzz......","....zkkkkkzz....","...zkkkkkkklz...",
        "...zjjjjjjjjz...","....zEEEEzEz....","....zEEEEEEz....","...E.zFFFFz.E...",
        "...EziiiiiizE...","...EEiiiiiiEE...","...zFzhiihzFz...","....zhhhhhhz....",
        "....zxxxxxxz....","....zxxzzxxz....","....zffz.zffz...","....zzzz.zzzz..."
      ],
      [
        "................",".....zzzzz......","....zkkkkkzz....","...zkkkkkkklz...",
        "...zjjjjjjjjz...","....zEEEEzEz....","....zEEEEEEzE...",".....zFFFFz.E...",
        "...EziiiiiizE...","...EEiiiiiiEz...","...EFzhiihzFz...","....zhhhhhhz....",
        "....zxxxxxxz....","....zxxzzxxz....","....zffz.zffz...","....zzzz.zzzz..."
      ]
    ]
  },

  // -------------------- 【2. 怪物与生态小动物 Monsters & Critters】 --------------------
  {
    id: "forest_bird", name: "红胸知更鸟 (森林小动物)", category: "monster", biome: "forest", fps: 4,
    desc: "栖息在迷雾古森草皮边缘的小动物：包含站立张望、低头啄食花草、扇翅开心小跳 3 帧动态。",
    frames: [
      [
        "....zzzz..","...ziiiiz.","..ziitziiz",".ziiiiiikz","ziiiiiiizz",
        ".zzffffzz.","...z..z...","...z..z..."
      ],
      [
        "..........","....zzzz..","...ziiiiz.","..ziitziiz",".ziiiiiikz",
        "zffffffzzz","...z..z...","...z..z..."
      ],
      [
        "...zzzz...","..ziiiiz..",".ziitziiz.","zjjiiiiikz",".ziiiiiizz",
        "..zzfffz..","..z....z..",".........."
      ]
    ]
  },
  {
    id: "forest_butterfly", name: "翩跹双色彩蝶 (森林小动物)", category: "monster", biome: "forest", fps: 8,
    desc: "在森林野花簇上方沿正弦轨迹扇翅盘旋的彩蝶（金黄与粉红双翼开合）。",
    frames: [
      [
        "zll..llz","zkllzlkz","..zzzz..","zDkz.zkDz","zDD..DDz","........"
      ],
      [
        "...zz...","..zllz..","..zkkz..","..zDDz..","...zz...","........"
      ]
    ]
  },
  {
    id: "forest_frog", name: "荷叶碧玉小树蛙 (森林小动物)", category: "monster", biome: "forest", fps: 3,
    desc: "蹲在迷雾古森水潭岸边的翠绿小青蛙，白色肚皮鼓腮呼吸。",
    frames: [
      [
        "..zz..zz..",".zmtzzmtz.",".zmmmmmmz.","zmmttttmmz","zmnttttnmz",
        "znozzzzonz",".zz....zz."
      ],
      [
        "..zz..zz..",".zmtzzmtz.",".zmmmmmmz.","zmttttttmz","zmttttttmz",
        "znozzzzonz",".zz....zz."
      ]
    ]
  },
  {
    id: "sky_dove", name: "云海白鸽 (天空岛小动物)", category: "monster", biome: "sky_island", fps: 4,
    desc: "停驻在云端圣域大理石浮岛边缘理羽的纯白小鸟，带金色小喙。",
    frames: [
      [
        "....zzzz..","...zttttz.","..zttztklz",".zttttttz.","zttttttz..",
        ".zzzzzz...","...z.z...."
      ],
      [
        "...zzzz...","..zttttz..",".zttztklz.","zttttttz..",".zuutttz..",
        "..zzzz....","..z..z...."
      ]
    ]
  },
  {
    id: "cloud_sprite", name: "软萌小云灵 (天空岛生物)", category: "monster", biome: "sky_island", fps: 5,
    desc: "由浮云凝结而成的团子小精灵，带粉红脸颊，在浮云软垫旁一蹦一跳。",
    frames: [
      [
        "..zzzzzz..",".zttttttz.","zttzttzttz","zttttttttz","zDzttttzDz",
        ".zuuuuuuz.","..zzzzzz.."
      ],
      [
        "..........","..zzzzzz..",".zttttttz.","zttzttzttz","zDzttttzDz",
        "zuuuuuuuuz",".zzzzzzzz."
      ]
    ]
  },
  {
    id: "ruins_scarab", name: "黄金圣甲虫 (遗迹小动物)", category: "monster", biome: "ruins", fps: 6,
    desc: "在黄金神庙砂岩台面上爬行的甲虫，金色甲壳带动态高光闪烁。",
    frames: [
      [
        "..zzzzz..",".zklklkz.","zkkkkkkkz",".zfffffz.",".z.z.z.z."
      ],
      [
        "..zzzzz..",".zlkltlz.","zkkkkkkkz",".zfffffz.","z.z.z.z.."
      ]
    ]
  },
  {
    id: "cave_moth", name: "趋光水晶飞蛾 (洞穴小动物)", category: "monster", biome: "cave", fps: 8,
    desc: "围绕幽光晶窟的发光晶簇环形飞舞的半透明青紫双色飞蛾。",
    frames: [
      [
        "zss...ssz","zstszstsz","..zzzzz..","zCszzzCs.","zCC...CCz","........."
      ],
      [
        "...zzz...","..zstsz..","..zsssz..","..zCCCz..","...zzz...","........."
      ]
    ]
  },
  {
    id: "cosmos_drone", name: "球形微型巡检无人机 (星站生物)", category: "monster", biome: "cosmos", fps: 6,
    desc: "在深空星站背景桁架间上下悬停巡检的微型机器人，带单只青色电子眼与尾焰。",
    frames: [
      [
        "..zzzzzz..",".zwwwwwwz.","zwvzzzzvwz","zwzstsszwz","zwvzzzzvwz",
        ".zwwwwwwz.","..zzzzzz..","...zssz...","....ss...."
      ],
      [
        "..zzzzzz..",".zwwwwwwz.","zwvzzzzvwz","zwzssstzwz","zwvzzzzvwz",
        ".zwwwwwwz.","..zzzzzz..","...zAAz...","....ll...."
      ]
    ]
  },
  {
    id: "dungeon_bat", name: "倒挂眨眼小蝙蝠 (石牢小动物)", category: "monster", biome: "dungeon", fps: 3,
    desc: "倒挂在幽暗石牢拱券天花板上的紫色小蝙蝠，偶而眨动亮黄色眼睛。",
    frames: [
      [
        "..z..z..",".zzzzzz.","zByzzyBz","zBzlzlBz",".zByyBz.","..zzzz.."
      ],
      [
        "..z..z..",".zzzzzz.","zByzzyBz","zBzzzzBz",".zByyBz.","..zzzz.."
      ]
    ]
  },
  {
    id: "hazard_gargoyle", name: "巡逻石像鬼 (挑战模式怪物)", category: "monster", biome: "dungeon", fps: 6,
    desc: "第三阶段地狱挑战模式的网格巡逻怪物，可引诱其替玩家踩住远端死路压板。",
    frames: [
      [
        "..zz........zz..",".zvvz..zzzz.zvvz","zvvvvzzwwwwzzvvz","zvwvvwzwwwwzvwvz",
        ".zzzzzwwAAwwzzzz","...zwwwwwwwwz...","..zwwvwwwwvwwz..","..zwwwwwwwwwwz..",
        "...zxxxxxxxxz...","...zxxzzzzxxz...","...zwwz..zwwz...","...zzzz..zzzz..."
      ],
      [
        "................","..zz........zz..",".zvvz..zzzz.zvvz","zvvvvzzwwwwzzvvz",
        "zvwvvwzwwAAzvwvz",".zzzzzwwwwwwzzzz","...zwwwwwwwwz...","..zwwvwwwwvwwz..",
        "...zxxxxxxxxz...","....zxxzzxxz....","....zwwzzwwz....","....zzzzzzzz...."
      ]
    ]
  },
  {
    id: "hazard_mole", name: "掘地小鼹鼠 (怪物图鉴)", category: "monster", biome: "cave", fps: 6,
    desc: "钻地与涉水小怪，橙色毛皮配亮白门牙。",
    frames: [
      [
        "....zzzz....","..zzjjjjzz..",".zjjjjjjjjz.","zjjjjjjjtzzz",
        "zjajjjjjjjDz","zaajjjjjjzz.","zaaaaaaaaz..",".zczzczcz...","..z..z.z...."
      ],
      [
        "....zzzz....","..zzjjjjzz..",".zjjjjjjjjz.","zjjjjjjjtzzz",
        "zjajjjjjjjDz","zaajjjjjjzz.","zaaaaaaaaz..","..zczzczcz..","...z.z..z..."
      ]
    ]
  },

  // -------------------- 【3. 道具与箱体 Props & Crates】 --------------------
  {
    id: "crate_wood_dungeon", name: "铆钉松木箱 (地牢轻箱)", category: "prop", biome: "dungeon", fps: 1,
    desc: "标准可浮水轻木箱，当连通水体液面 >= 箱底时自动上浮。",
    frames: [[
      "gggggggggggggggg","gddddddddddddddg","gdfffffffffffedg","gdfeeeeeeeeeffdg",
      "gdfefeeeeeeeffdg","gdfeefeeeeeeefdg","gdfeeefeeeeeefdg","gdfeeeefeeeeefdg",
      "gdfeeeeefeeeefdg","gdfeeeeeefeeefdg","gdfeeeeeeefeefdg","gdfeeeeeeeefefdg",
      "gdffeeeeeeeeefdg","gdffffffffffffdg","gddddddddddddddg","gggggggggggggggg"
    ]]
  },
  {
    id: "crate_wood_forest", name: "翠藤绑扎木箱 (森林轻箱)", category: "prop", biome: "forest", fps: 2,
    desc: "迷雾古森专属木箱皮肤，外框缠绕翠绿青藤并点缀小红花。",
    frames: [
      [
        "zzzzzzzzzzzzzzzz","zmmnnnnnnnnnnmmz","zmnffffffffffenZ","znfeeeeeeeeeefnz",
        "znfefeeeeeeeffnz","znfeefmmmeeeefnz","znfeeemimmeeefnz","znfeeeemeeeefnz",
        "znfeeeeefeeeefnz","znfeeeeeefeeefnz","znfeeeeeeefeefnz","znfeeeeeeeeefenz",
        "znffeeeeeeeeefnz","zmnffffffffffnmz","zmmnnnnnnnnnnmmz","zzzzzzzzzzzzzzzz"
      ],
      [
        "zzzzzzzzzzzzzzzz","zmmnnnnnnnnnnmmz","zmnffffffffffenZ","znfeeeeeeeeeefnz",
        "znfefeeeeeeeffnz","znfeefmmmeeeefnz","znfeeemlmmeeefnz","znfeeeemeeeefnz",
        "znfeeeeefeeeefnz","znfeeeeeefeeefnz","znfeeeeeeefeefnz","znfeeeeeeeeefenz",
        "znffeeeeeeeeefnz","zmnffffffffffnmz","zmmnnnnnnnnnnmmz","zzzzzzzzzzzzzzzz"
      ]
    ]
  },
  {
    id: "crate_wood_ruins", name: "包金边圣物箱 (遗迹轻箱)", category: "prop", biome: "ruins", fps: 2,
    desc: "黄金神庙专属木箱，四角镶嵌太阳神黄金包角与宝石核心。",
    frames: [
      [
        "zzzzzzzzzzzzzzzz","zkkkkddddddkkkkz","zkdffffffffffdkz","zkdfeeeeeeeeedkz",
        "zdfefekkkkfeefdz","zdfeeekllkeeeefz","zdfeeekllkeeeefz","zdfeefkkkkfeefdz",
        "zdfeeeeeeeeeefdz","zdfeeeeeeeeeefdz","zdfeeeeeeeeeefdz","zdfeeeeeeeeeefdz",
        "zkdffffffffffdkz","zkdffffffffffdkz","zkkkkddddddkkkkz","zzzzzzzzzzzzzzzz"
      ],
      [
        "zzzzzzzzzzzzzzzz","zkkkkddddddkkkkz","zkdffffffffffdkz","zkdfeeeeeeeeedkz",
        "zdfefekkkkfeefdz","zdfeeekttkeeeefz","zdfeeekttkeeeefz","zdfeefkkkkfeefdz",
        "zdfeeeeeeeeeefdz","zdfeeeeeeeeeefdz","zdfeeeeeeeeeefdz","zdfeeeeeeeeeefdz",
        "zkdffffffffffdkz","zkdffffffffffdkz","zkkkkddddddkkkkz","zzzzzzzzzzzzzzzz"
      ]
    ]
  },
  {
    id: "crate_iron_all", name: "重铸沉水铁箱 / 引力重匣", category: "prop", biome: "all", fps: 2,
    desc: "M8 沉水铁箱（floats: false）：推入水中直沉水底压住水下开关并向上置换 1 格水位。",
    frames: [
      [
        "zzzzzzzzzzzzzzzz","zttttuuuuuuuuuuz","ztzzzzzzzzzzzzuz","ztzwwwwwwwwwwzuz",
        "ztzwtswwwwwwxzuz","ztzwwswwwwwxxzuz","ztzwwwwwwwwxxzuz","ztzwwwwsswwxxzuz",
        "ztzwwwwsswwxxzuz","ztzwwwwwwwwxxzuz","ztzxxwwwwwwxxzuz","ztzxxxwwwwtswzuz",
        "ztzxxxxxxxxxwzuz","ztzzzzzzzzzzzzuz","zuuuuuuuuuuuuuuz","zzzzzzzzzzzzzzzz"
      ],
      [
        "zzzzzzzzzzzzzzzz","zttttuuuuuuuuuuz","ztzzzzzzzzzzzzuz","ztzwwwwwwwwwwzuz",
        "ztzwtswwwwwwxzuz","ztzwwswwwwwxxzuz","ztzwwwwwwwwxxzuz","ztzwwwwttwwxxzuz",
        "ztzwwwwttwwxxzuz","ztzwwwwwwwwxxzuz","ztzxxwwwwwwxxzuz","ztzxxxwwwwtswzuz",
        "ztzxxxxxxxxxwzuz","ztzzzzzzzzzzzzuz","zuuuuuuuuuuuuuuz","zzzzzzzzzzzzzzzz"
      ]
    ]
  },
  {
    id: "icon_bomb", name: "十字爆破炸药 (HUD/拖拽道具)", category: "prop", biome: "all", fps: 4,
    desc: "从右上角拖拽到角色左、右、下相邻格松手引爆，引信火花动态闪烁。",
    frames: [
      [
        "........lj..",".......j....","......ef....","....zzfzz...","...zwwwyyz..",
        "..zwvwyyyyz.","..zwwyyyyyz.","..zyyyyyyyz.","..zyyyyyyyz.","...zyyyyyz..","....zzzzz...","............"
      ],
      [
        "........tl..",".......k....","......ef....","....zzfzz...","...zwwwyyz..",
        "..zwvwyyyyz.","..zwwyyyyyz.","..zyyyyyyyz.","..zyyyyyyyz.","...zyyyyyz..","....zzzzz...","............"
      ]
    ]
  },
  {
    id: "icon_sandbag", name: "沙袋容量指示器 (0..7 满度)", category: "prop", biome: "all", fps: 4,
    desc: "HUD 沙袋随挖沙/倒沙实时显示袋内沙位高度。",
    frames: [
      [
        "...zzzzzz...","..zfzzzzfz..","...zffffz...","..zfeeeefz..",".zfeeeeeefz.",
        "zfeeeeeeeefz","zfeeeeeeeefz","zfeeeeeeeefz","zfeeeeeeeefz","zfdcddcddcfz",".zffffffffz.","..zzzzzzzz.."
      ],
      [
        "...zzzzzz...","..zfzzzzfz..","...zffffz...","..zfeeeefz..",".zfeeeeeefz.",
        "zfeeeeeeeefz","zfdcddcddcfz","zfcddcddcdfz","zfddcddcddfz","zfdcddcddcfz",".zffffffffz.","..zzzzzzzz.."
      ],
      [
        "...zzzzzz...","..zfzzzzfz..","...zffffz...","..zfddcdfz..",".zfddcddcfz.",
        "zfddcddcddfz","zfdcddcddcfz","zfcddcddcdfz","zfddcddcddfz","zfdcddcddcfz",".zffffffffz.","..zzzzzzzz.."
      ]
    ]
  },

  // -------------------- 【4. 动态植物与机关 Plants & Mechanisms】 --------------------
  {
    id: "flower_sway", name: "三色摇曳林间野花簇 (森林植物)", category: "plant_mech", biome: "forest", fps: 3,
    desc: "自动生长在迷雾古森裸露 3px 草皮顶面，红瓣白心与金黄雏菊随风左右摇摆 1px。",
    frames: [
      [
        ".ziz..zlz.","zitz.zlzlt",".ziz..zlz.","..m....m..",".mm...mm..",".on...on.."
      ],
      [
        "..ziz..zlz",".zitz.zlzl","..ziz..zlz","...m....m.","..mm...mm.",".on...on.."
      ]
    ]
  },
  {
    id: "mushroom_glow", name: "呼吸发光蓝伞菇 (森林/晶窟植物)", category: "plant_mech", biome: "forest", fps: 2,
    desc: "生长在古树背阴处与洞穴岩壁的发光真菌，伞盖荧光周期呼吸。",
    frames: [
      [
        "..zzzz..",".zssssz.","zstssstz","zzzzzzzz","..zccz..","..zccz..","..zzzz.."
      ],
      [
        "..zzzz..",".zrrrrz.","zrsrrsrz","zzzzzzzz","..zddz..","..zddz..","..zzzz.."
      ]
    ]
  },
  {
    id: "vine_ladder", name: "吸水生长翠绿藤梯 (森林独特机关)", category: "plant_mech", biome: "forest", fps: 3,
    desc: "森林独特机制：当林泉水漫过枯藤种子格时，自动向上生长为带舒展叶片的可爬藤梯。",
    frames: [
      [
        "..zoz......zoz..","..zmoz....zomz..",".zzmnzzzzzznmzz.","zmmnnnnmmnnnnmmz",
        ".zznozzzzzzonzz.","..znoz....zonz..","..zoz......zoz..","..zmoz....zomz..",
        ".zzmnzzzzzznmzz.","zmmnnnnmmnnnnmmz",".zznozzzzzzonzz.","..znoz....zonz..",
        "..zoz......zoz..","..zmoz....zomz..",".zzmnzzzzzznmzz.","zmmnnnnmmnnnnmmz"
      ],
      [
        "..zoz......zoz..","...zmoz..zomz...",".zzmnzzzzzznmzz.","zmmnnnnmmnnnnmmz",
        ".zznozzzzzzonzz.","...znoz..zonz...","..zoz......zoz..","...zmoz..zomz...",
        ".zzmnzzzzzznmzz.","zmmnnnnmmnnnnmmz",".zznozzzzzzonzz.","...znoz..zonz...",
        "..zoz......zoz..","...zmoz..zomz...",".zzmnzzzzzznmzz.","zmmnnnnmmnnnnmmz"
      ]
    ]
  },
  {
    id: "wind_pinwheel", name: "旋转风向标风车 (天空岛独特机关)", category: "plant_mech", biome: "sky_island", fps: 8,
    desc: "天空岛独特机制：开启后风车叶片连续旋转，将倒下的云沙顺风吹偏 1 格或助推冰面箱滑行。",
    frames: [
      [
        "......zzzz......",".....zttttz.....",".....ztkltz.....",".zzzzztkltzzzzz.",
        "zttkkzzkkzzkkttz","ztkllkzzzzkllktz",".zzzzzztkzzzzzz.","......zkkz......",
        ".....zttttz.....",".....zttttz.....","......zwwz......","......zwwz......",
        ".....zwwwwz.....","....zkkkkkkz....","...zkkkkkkkkz...","...zzzzzzzzzz..."
      ],
      [
        "..zzz......zzz..",".ztttz....ztttz.",".ztkltz..ztkltz.","..ztklzzzzlklt..",
        "...zzzzkkzzzz...",".....zzkkzz.....","..zzzztkktzzzz..",".ztttz.zkz.ztttz",
        ".ztkltzzkzzztklt","..zzz.zwwz..zzz.","......zwwz......","......zwwz......",
        ".....zwwwwz.....","....zkkkkkkz....","...zkkkkkkkkz...","...zzzzzzzzzz..."
      ]
    ]
  },
  {
    id: "cloud_pad", name: "呼吸浮云弹性软垫 (天空岛独特机关)", category: "plant_mech", biome: "sky_island", fps: 3,
    desc: "天空岛独特机制：随微风上下呼吸浮动 1px；轻木箱与人物可安全通行，白金重铁箱推上直接压穿下坠。",
    frames: [
      [
        "................","....zzzzzzzz....","..zzttttttttzz..",".zttttttttttttz.",
        "zttttttttttttttz","ztttuutttttuuttz","zuuuuuuuuuuuuuuz",".zzuuuuuuuuuuzz.",
        "...zzzzzzzzzz...","................","................","................"
      ],
      [
        "....zzzzzzzz....","..zzttttttttzz..",".zttttttttttttz.","zttttttttttttttz",
        "ztttuutttttuuttz","zuuuuuuuuuuuuuuz",".zzuuuuuuuuuuzz.","...zzzzzzzzzz...",
        "................","................","................","................"
      ]
    ]
  },
  {
    id: "ruins_brazier", name: "神殿熊熊圣火盆 (遗迹动态灯饰)", category: "plant_mech", biome: "ruins", fps: 6,
    desc: "修复原本不动的死图挂灯，4 帧外焰/内焰/火芯跳跃闪烁。",
    frames: [
      [
        "......zz......",".....zllz.....","....zklttz....","...zjjllkjz...",
        "...zjklttkjz..","..zzzzzzzzzz..","..zkkkkkkkkz..","...zffffffz...","....zzzzzz...."
      ],
      [
        ".....zz.......","....zllz......","...zklttz.....","...zjllkjz....",
        "..zjjkttkjz...","..zzzzzzzzzz..","..zkkkkkkkkz..","...zffffffz...","....zzzzzz...."
      ]
    ]
  },
  {
    id: "cosmos_teleporter", name: "量子物质传送基座 (星站独特机关)", category: "plant_mech", biome: "cosmos", fps: 6,
    desc: "宇宙风格独特机制：成对布置（TP_A -> TP_B），上方能量环脉冲浮动，可跨封闭舱壁实时传送箱体与流沙。",
    frames: [
      [
        "....ssssssss....","..ss........ss..","................","....tttttttt....",
        "................","..zzzzzzzzzzzz..",".zwwwwwwwwwwwwz.","zwsssswwwwsssswz",
        "zttttttttttttttz",".zzzzzzzzzzzzzz."
      ],
      [
        "................","....tttttttt....","..ss........ss..","................",
        "....ssssssss....","..zzzzzzzzzzzz..",".zwwwwwwwwwwwwz.","zwttttwwwwttttwz",
        "zssssssssssssssz",".zzzzzzzzzzzzzz."
      ]
    ]
  },

  // -------------------- 【5. 地形与流体材质 Terrain & Fluids】 --------------------
  {
    id: "tile_forest_grass", name: "盘根褐土 + 3px 翠绿草皮 (森林基岩)", category: "terrain", biome: "forest", fps: 1,
    desc: "world.gdshader 跨像素探针自动在裸露顶面生成的 3px 翠绿草皮与垂草芽。",
    frames: [[
      "mmmmmmmmmmmmmmmm","nnnnmmmmnnnnmmmm","nnooonnnoooonnno","ffggffffffggffff",
      "fggffffffffggfff","fffffgggffffffff","ffffggffffffffff","fffffffgggffffff",
      "ffffffffggffffff","ggffffffffffggff","fggfffffffffggff","ffffffffffffffff",
      "fffgggffffffffff","ffffggffffffffff","ffffffffgggfffff","gggggggggggggggg"
    ]]
  },
  {
    id: "tile_sky_marble", name: "镶金大理石 + 3px 白云托底 (天空岛基岩)", category: "terrain", biome: "sky_island", fps: 1,
    desc: "圣白大理石嵌 1px 金丝腰线，悬空底面自动包裹 3px 圆润白云絮。",
    frames: [[
      "tttttttttttttttt","uuuuuuuuuuuuuuuu","kkkkkkkkkkkkkkkk","uuuuuuuuuuuuuuuu",
      "uuvvuuuuuuuuvvuu","uuuuuvvuuuuuuuuu","uuuuuuuuuuuuuuuu","uuuuuuuuvvuuuuuu",
      "uuuuuuuuuuuuuuuu","uuuuuuuuuuuuuuuu","uuuuuuuuuuuuuuuu","vvvvvvvvvvvvvvvv",
      "tttttttttttttttt","tttttttttttttttt","zuttttttttttttuz","zzzuttttttttuzzz"
    ]]
  },
  {
    id: "tile_cosmos_hull", name: "钛合金铆钉舱板 + 黄黑警示纹 (宇宙基岩)", category: "terrain", biome: "cosmos", fps: 1,
    desc: "四角带高光铆钉，裸露平台顶边自动渲染 2px 黄黑斜向工程警示条纹。",
    frames: [[
      "lllzzzlllzzzlllz","llzzzlllzzzlllzz","yyyyyyyyyyyyyyyy","ywwwwwwwwwwwwwwy",
      "ywuvwwwwwwwwvuwy","ywwwwwwwwwwwwwwy","ywwwwwwwwwwwwwwy","ywwwwxxxxxxwwwwy",
      "ywwwwxxxxxxwwwwy","ywwwwwwwwwwwwwwy","ywwwwwwwwwwwwwwy","ywuvwwwwwwwwvuwy",
      "ywwwwwwwwwwwwwwy","ywwwwwwwwwwwwwwy","yxxxxxxxxxxxxxxy","zzzzzzzzzzzzzzzz"
    ]]
  },
  {
    id: "tile_cave_sulfur", name: "亮黄硫磺矿脉裂岩 (洞穴可炸/可酸蚀)", category: "terrain", biome: "cave", fps: 2,
    desc: "深褐火山岩内嵌高对比亮黄硫磺裂隙，一眼可辨可爆破/可酸蚀。",
    frames: [
      [
        "kkkkkkkkkffkkkkk","kfffffffflkfffff","kffffffflkffffff","kfffffflkfffffff",
        "ffffffflkfffffff","fkkfffkllkffffff","kffkkkffkkkfffff","kffffffffllkffff",
        "kffffffkllkfffff","kfffffkllfffffff","kfffffkllkffffff","kfffffkkffkkkfff",
        "kffffffkkffffkff","kffffffkkfffffkf","kfffffffkkfffffk","kfffffffkkffffff"
      ]
    ]
  },

  // -------------------- 【6. 界面与图标 UI & Icons】 --------------------
  {
    id: "ui_campaign_screen", name: "闯关选关 UI · 营地路线", category: "ui", biome: "all", fps: 8,
    wide: true, renderType: "ui_campaign",
    desc: "六主题营地路线：关卡化为路边木牌，矿工站在所选路牌旁，旗帜记录通关；可放大预演、切换主题并检查解锁状态。"
  },
  {
    id: "ui_lobby_screen", name: "主大厅 UI · 矿井营地", category: "ui", biome: "all", fps: 8,
    wide: true, renderType: "ui_lobby",
    desc: "练习台、亮灯矿口与封闭矿道分别作为教学、闯关和挑战筹备入口；点阵字体、分层地景与克制生态动画统一在 320×180 中。"
  },
  {
    id: "ui_keycaps", name: "引导键帽与鼠标手势图标组", category: "ui", biome: "all", fps: 2,
    desc: "关内极简引导使用的方向键帽与鼠标左右键高亮精灵。",
    frames: [
      [
        ".zzzzzzzzzzz.","zcccccccccccz","zcccccccccccz","zccccczcccccz",
        "zcccczzzccccz","zccczzzzzcccz","zcczzzzzzzccz","zcccczzzccccz",
        "zcccczzzccccz","zcccczzzccccz","zvvvvvvvvvvvz","zwwwwwwwwwwwz",".zzzzzzzzzzz."
      ],
      [
        "...........","..zzzzzzz..",".zkkkkzttz.","zkkkkkztttz","zkkkkkztttz",
        "zkkkkkztttz","zzzzzzzzzzz","ztttttttttz","ztttttttttz","ztttttttttz",
        "zuuuuuuuuuz",".zuuuuuuuz.","..zzzzzzz.."
      ]
    ]
  },

  // -------------------- 【7. 六大风格地图 Maps (去火柴盒化 + 动态生态)】 --------------------
  {
    id: "map_forest", name: "地图 2 · 迷雾古森《巨木盘根水殿》", category: "map", biome: "forest", fps: 8,
    wide: true, renderType: "map", biomeIdx: 1,
    desc: "拱形树冠穹顶 + 阶梯草坡 + 3px 翠绿草皮 + 摇曳三色野花 + 啄食知更鸟 + 正弦飞舞彩蝶 + 丁达尔阳光束 + 吸水藤梯。"
  },
  {
    id: "map_sky_island", name: "地图 5 · 云端圣域《破晓云海风之圣域》", category: "map", biome: "sky_island", fps: 8,
    wide: true, renderType: "map", biomeIdx: 4,
    desc: "无外框纯悬空倒梯形浮岛 + 底面 3px 白云托底 + 2×2 抖动破晓霞光 + 远/中/近三层视差飘动白云海 + 旋转风车 + 理羽白鸽与小云灵。"
  },
  {
    id: "map_ruins", name: "地图 3 · 黄金神庙《日轮金字塔内殿》", category: "map", biome: "ruins", fps: 8,
    wide: true, renderType: "map", biomeIdx: 2,
    desc: "上窄下宽正金字塔阶梯斜坡 + 顶棚持续漏下 1px 动态金沙细流 + 爬行黄金圣甲虫 + 4 帧跳跃圣火盆。"
  },
  {
    id: "map_cave", name: "地图 4 · 幽光晶窟《幽光晶簇与熔脉》", category: "map", biome: "cave", fps: 8,
    wide: true, renderType: "map", biomeIdx: 3,
    desc: "锯齿钟乳石溶洞 + 滴酸溅花动画 + 4 帧呼吸发光青/紫晶簇 + 环绕飞舞的水晶飞蛾 + 鼓泡赤红熔岩。"
  },
  {
    id: "map_cosmos", name: "地图 6 · 深空星站《曲率反应舱》", category: "map", biome: "cosmos", fps: 8,
    wide: true, renderType: "map", biomeIdx: 5,
    desc: "四角 45° 斜切钛合金舱段 + 顶边 2px 黄黑警示斜纹 + 全景星云与闪烁十字星芒 + 上下悬停巡检的球形微型维修无人机。"
  },
  {
    id: "map_dungeon", name: "地图 1 · 幽暗石牢《深层矿井枢纽》", category: "map", biome: "dungeon", fps: 8,
    wide: true, renderType: "map", biomeIdx: 0,
    desc: "多层古典拱券顶矿井 + 随气流摆动的生锈铁链 + 洞顶倒挂眨眼小蝙蝠 + 防夹千斤闸与沉沙囊水道。"
  }
];

const BACKUP_CATALOG = JSON.parse(JSON.stringify(ASSET_CATALOG));
