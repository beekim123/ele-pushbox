# 调研：配送模式重做（2026-10-16）

状态：调研记录，只作依据；规则以 [delivery-puzzle-rules.md](../design/delivery-puzzle-rules.md) 为准，两张地图见 [delivery-dungeon.md](../design/delivery-dungeon.md)、[delivery-diyu.md](../design/delivery-diyu.md)。

来源：维基百科条目正文（API `action=query&prop=extracts&explaintext=1&redirects=1`，中文用 `variant=zh-cn`），2026-10-16 抓取，原文缓存在交接包的 `research_cache/`（`fetch.py`、`batch.sh`，不进仓库）。下文引用的英文原句都出自缓存；没有出处的推断写明"我们的做法"。链接格式 `https://en.wikipedia.org/wiki/<条目>`、`https://zh.wikipedia.org/wiki/<条目>`。

## 1 游戏参考：提示、镜头、移动的平台

| 游戏 | 原文要点 | 我们借什么 |
|---|---|---|
| [Professor Layton and the Curious Village](https://en.wikipedia.org/wiki/Professor_Layton_and_the_Curious_Village) | "Each puzzle has three hints available for it, but the player must spend one 'hint coin' to see each hint." | 提示分三级、越往后越明确；我们前两级（位置、走近）免费，只有第三级（一句话）要花一块零食，零食在驿站买（10 金币，每个驿站 3 块） |
| [Toki Tori 2](https://en.wikipedia.org/wiki/Toki_Tori_2) | 没有文字教学，主角只有两个技能 Whistle（"generally causes creatures to move closer"）和 Stomp，用来摆布环境和里面的生物 | 生物自己传递信息：提示动物前两级不说话，只靠待的位置和走向 |
| [Celeste](https://en.wikipedia.org/wiki/Celeste_(video_game)) | "divided into multiple single-screen challenges, with checkpoints in between screens"；有 "Assist Mode" 让游戏更宽容 | 一屏一个挑战仍是主力（23 间里 15 间是 1×1）；提示是可选的帮助，不喂零食也能全部解开 |
| [Animal Well](https://en.wikipedia.org/wiki/Animal_Well) | "an interconnected set of rooms, or flip-screens"；"an underground animal-filled labyrinth" | 房间之间照旧翻屏切换（v1 的 0.3 秒过场）；只有房间本身大于一屏时才在房间里跟随镜头；动物是迷宫的居民 |
| [Carto](https://en.wikipedia.org/wiki/Carto_(video_game)) | "By moving the pieces on the map, players also assist non-player characters" | 移动地块本身就是谜题：浮块整块推一格、站在上面撑过去 |
| [Monument Valley](https://en.wikipedia.org/wiki/Monument_Valley_(video_game)) | "manipulating the world around her to reach various platforms"；"a camera mode where the player can roam the level" | 平台载着人和箱子移动；Tab 看全图 = 观察模式，先看清整间房再动手 |
| [Baba Is You](https://en.wikipedia.org/wiki/Baba_Is_You) | "manipulation of rules—represented in the play area by movable tiles with words" | 规则全摆在画面上：机关都看得见，不藏规则；房名点出关键想法（「断桥 · 推浮石」） |
| [Spelunky](https://en.wikipedia.org/wiki/Spelunky) | "The caves are procedurally generated"；"grouped into four increasingly difficult 'areas'" | 程序拼图 + 手工房间（v1 已借鉴主路径）；v2 改成按角色顺序摆房间（起点 → 教 → 教 → 喘口气 → 发展 → 驿站 → 转折 → …），保证先教后用 |

## 2 地府资料

| 条目 | 原文要点 | 用在哪 |
|---|---|---|
| [Diyu](https://en.wikipedia.org/wiki/Diyu)、[地府](https://zh.wikipedia.org/wiki/地府) | 奈何桥 "Bridge of Helplessness, a bridge every soul has to cross before being reincarnated"，桥上喝孟婆汤；望乡台 "Home-Viewing Pavilion, a pavilion every soul passes by"；十殿各由一位判官 / 阎王掌管 | 房间「奈何桥」「望乡台」；收件人判官、阎王 |
| [丰都鬼城](https://zh.wikipedia.org/wiki/丰都鬼城)、[Fengdu Ghost City](https://en.wikipedia.org/wiki/Fengdu_Ghost_City)、[酆都](https://zh.wikipedia.org/wiki/酆都) | 鬼城"位于重庆市下游丰都县的长江北岸"，"鬼城内有哼哈祠、天子殿、枉死城、奈何桥、黄泉路、望乡台、药王殿等"；游客坐车上山（"visitors are transported partway up the mountain"）；酆都 = 罗酆山，"华人民间信仰中阴间的首都" | 地图名「地府·酆都」；房名鬼门关、黄泉路、奈何桥、望乡台都能在鬼城找到对应；背景画"名山夜色"的荒山 |
| [黄泉](https://zh.wikipedia.org/wiki/黄泉) | "典故出自郑伯克段的故事"（《左传》），"九泉之下" | 房间「黄泉路」（过道）、「黄泉沙」 |
| [Meng Po](https://en.wikipedia.org/wiki/Meng_Po)、[孟婆](https://zh.wikipedia.org/wiki/孟婆) | "the goddess of oblivion … who serves Meng Po Soup on the Bridge of Oblivion or Naihe Bridge" | 收件人孟婆（稀有）；驿站「桥头茶摊」 |
| [判官](https://zh.wikipedia.org/wiki/判官) | 消歧义页："阴间神明（如东岳大帝、酆都大帝、阎罗王、城隍爷等等）的幕僚神" | 收件人判官（稀有） |
| [Heibai Wuchang](https://en.wikipedia.org/wiki/Heibai_Wuchang)、[黑白无常](https://zh.wikipedia.org/wiki/黑白无常) | "in charge of escorting the spirits of the dead to the underworld"，"dressed in black and white respectively"；白无常名谢必安 | 收件人黑白无常（稀有，一张 24×16 的图左白右黑）；"两人分头收货"的规则暂缓 |
| [阎罗王](https://zh.wikipedia.org/wiki/阎罗王) | "婆罗门敬奉的阎魔罗阇也被佛教吸收，汉译为阎罗王" | 收件人阎王（传说）；按 worlds.json 的 `care`，不画佛教的菩萨与佛像 |
| [Ox Head and Horse Face](https://en.wikipedia.org/wiki/Ox_Head_and_Horse_Face) | "the first beings a dead soul encounters upon entering the underworld" | 鬼门关的守门人（worlds.md 3.2 的设想，v2 还没出场） |
| [Zhong Kui](https://en.wikipedia.org/wiki/Zhong_Kui)、[钟馗](https://zh.wikipedia.org/wiki/钟馗) | "traditionally regarded as a vanquisher of ghosts and evil beings" | 暂未用（可做以后的道具或收件人） |
| [Chenghuang](https://en.wikipedia.org/wiki/Chenghuang)、[城隍神](https://zh.wikipedia.org/wiki/城隍神) | "originally involved worship of a protective deity of a town's walls and moats" | 暂未用 |
| [紙紮](https://zh.wikipedia.org/wiki/紙紮)（重定向到「紮作」）、[Joss paper](https://en.wikipedia.org/wiki/Joss_paper)、[Hell money](https://en.wikipedia.org/wiki/Hell_money) | 扎作"是华人地区的一种传统工艺……包括纸灯笼（纸花灯）或纸扎祭品"；纸钱 "made into burnt offerings common in Chinese ancestral worship" | 货物纸扎小楼（稀有，只给先人和黑白无常）；纸扎的孔明灯台 |
| [孔明灯](https://zh.wikipedia.org/wiki/孔明燈)、[Kongming lantern](https://en.wikipedia.org/wiki/Kongming_lantern) | "天灯亦称孔明灯，相传为中国三国时期诸葛亮的发明" | 地府的浮块 = 孔明灯吊着的纸台（`mech.lantern_float`），房间「孔明灯台」 |
| [石蒜](https://zh.wikipedia.org/wiki/石蒜) | 曼珠沙华"接引之花"；"……的石蒜，自然就成为黄泉的象征了"；日本传说里带"死亡和分离的不祥色彩，较常用于丧礼" | 装饰彼岸花（`deco.diyu_lily`，画面里唯一大面积的亮红）、提示动物彼岸蝶 |
| [中元节](https://zh.wikipedia.org/wiki/中元节) | "在农历七月十五日举行" | 故事背景：阳间在清明、中元给亲人捎东西 |
| [Jiangshi](https://en.wikipedia.org/wiki/Jiangshi)、[殭屍](https://zh.wikipedia.org/wiki/殭屍) | "commonly represented as hopping or leaping"；"Holding one's breath … makes the jiangshi unable to find you as they are blind" | 怪物跳跳僵尸：一跳一格；站着不动（屏息）它就看不见你 |

缓存里是空的、只能当标题用的页：中文「冥币」「河灯」「纸扎」「奈何桥」「望乡台」「牛头马面」「名山风景区」、英文「Naihe Bridge」（这些事实改用上表的其他条目）；中文「鬼门关」重定向到了「五方鬼帝」，没有关于鬼门关本身的内容，房名「鬼门关」按民间通行说法使用。

**画风（用户 2026-10-16 决定）**：地府不画城砖和城楼，改成荒郊野岭（荒山、枯树、坟包和木牌、招魂幡、夜雾、幽蓝鬼火、引魂灯、彼岸花）。资料里的"酆都"是阴间的都城，路上的景色是荒野：地图名暂时保留「地府·酆都」，房名「酆都城 · 钟楼的锣」是否改名待用户定（[delivery-diyu.md](../design/delivery-diyu.md) 第 7 节）。

## 3 岩浆：SDK 里有没有现成的机制

- 机制目录里已经有 `lava`（熔岩，来自恐龙区，`owner: sdk`，`sdk: [liquid, thermal, burnable]`，风险"温度与燃烧联动要测"）。
- SDK v1.2 的液体、温度、可燃反应可以拼出"会流动、会点燃的液体"（[sdk-v1.2-verified.md](../reference/sdk-v1.2-verified.md)：thermal 有自己的唤醒位，液体按 `liquid_pressure` 找最低开口），但这要在 SDK 层定新规则并逐条验证，属于 SDK 新机制。
- 按用户决定（交接文档第 2 节第 7 条）**暂不做**。地府的"火"（阎罗殿外火很旺、纸扎怕火）以后先用不流动的热源做；v2 的 23 间房都不用岩浆。