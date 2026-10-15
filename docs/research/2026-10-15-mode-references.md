# 参考资料：配送模式、地狱模式、局外养成与名称（2026-10-15）

为 [总纲](../design/vision.md)、[配送模式](../design/mode-delivery.md)、[地狱模式](../design/mode-hell.md)、[局外养成](../design/progression.md) 收集的参考。来源以评测、开发者分享和社区 wiki 为主，不是官方文档；具体数字以原作为准，本文只提取可借鉴的**设计做法**。

## 1 多个小地图拼成大地图

| 参考 | 做法 | 我们怎么用 |
|---|---|---|
| Spelunky | 每层是 4×4 共 16 个房间的网格。先从顶行随机选入口，向左、右、下随机走出一条到底行的主路径；主路径上的房间保证相通，不用绳子和炸弹也能走完；再按"房间在路径上的角色"（落点、通道、侧房等）从对应的手工模板池里各挑一个模板，每类通常 8–16 个。有开发者的做法是生成后再检查入口能否到出口，不行就重来。 | 配送模式的地图 = 房间网格 + 保证可通的主路径 + 按角色取手工房间模板；生成后用格子模型验证主路径。 |
| Noita | 世界由 "Wang 砖"（按边缘颜色匹配的预制矩形块）拼接成地形，再叠加手工"像素场景"；另有一张生物群系图决定每个区块用哪种群系。 | 房间模板的边缘出入口标准化（像 Wang 砖的边缘约束），让任意两个模板能对接；区域（主题）由一张小地图决定。 |

来源：[Spelunky Generator Lessons（Darius Kazemi）](https://tinysubversions.com/spelunkyGen2/)、[GMTK：How and Why Spelunky Makes its Own Levels（字幕）](https://amara.org/subtitles/p6MHlmreohsY/en-gb/1/download/How%20and%20Why%20Spelunky%20Makes%20its%20Own%20Levels%20%20Game%20Makers%20Toolkit.en-gb.txt)、[Steam 开发者讨论](https://steamcommunity.com/app/1363680/discussions/0/2968398218084242375/)、[Noita Wiki：World generation](https://noita.wiki.gg/wiki/World_generation)、[Noita Wiki：Biomes](https://noita.wiki.gg/wiki/Biomes)。

## 2 货物本身就是规则

| 参考 | 做法 | 我们怎么用 |
|---|---|---|
| Death Stranding | 负重越大越慢、越难保持平衡；货物摆放影响重心。有的货物要特殊对待（如披萨必须平放），会因跌落、浸水、敌人粗暴对待、"时间雨"而损坏；部分订单有时限；距离越远、货越重，报酬越高；背、挂、手提、上车各有取舍。 | 每种货物只加**一条**清楚的规则（限时、减速、怕摔、怕水、怕火……），送达时按完好度和用时给小费。 |
| Spelunky 的偶像和少女 | 偶像拿到时不给钱，必须一路带到出口（或卖给商店）才结算；少女带到出口奖励一颗心。带着它们穿过陷阱很紧张，还可能因为爬下边缘而脱手。 | "带着东西走到终点才算数"正是配送模式的核心张力；拿着大件时某些动作受限。 |

来源：[TechRadar：Death Stranding cargo management](https://www.techradar.com/how-to/death-stranding-cargo-management-how-to-efficiently-spread-your-cargo-weight)、[Push Square 评测](https://pushsquare.com/reviews/ps4/death_stranding)、[505 Games 新手指南](https://deathstrandingpc.505games.com/en/?p=16955)、[Spelunky Wiki：Idol](https://spelunky.fandom.com/wiki/Idol_(Classic))、[Spelunky Wiki：Damsel](https://spelunky.fandom.com/wiki/Damsel_(Classic))。

## 3 在挖掘解谜里对付怪物

| 参考 | 做法 | 我们怎么用 |
|---|---|---|
| Lode Runner | 玩家没有攻击手段，只能在身旁挖坑；坑过一会儿自动填回，困在坑里的守卫被吞掉后在顶部重生；玩家自己掉进去也会死。有的金块只能靠困住守卫才能拿到。 | 怪物用"困住、压住、淹没、烧掉"等环境手段处理，不加战斗系统；挖坑困怪与我们的"挖"天然契合。 |
| Hyper Lode Runner | 被挖掉的砖块重新出现时，压死还困在里面的机器人。 | 箱子、沙、碎石落下可以压倒怪物。 |

来源：[Wikipedia：Lode Runner](https://en.wikipedia.org/wiki/Lode_Runner)、[Nintendo Life：Hyper Lode Runner](https://www.nintendolife.com/games/gameboy/hyper_lode_runner/review)。

## 4 高难纯解谜

| 参考 | 做法 | 我们怎么用 |
|---|---|---|
| Stephen's Sausage Roll | 没有教程、没有提示，新机制靠关卡布局让玩家"偶然"发现；公认极难但不被认为不公平；撤销与重开让试错成本很低。 | 地狱模式不给提示，每关一个关键想法，用布局引导发现；撤销、重开不限。 |
| Helltaker | 推石头和骷髅兵的推箱玩法，加上每关步数上限；来回推浪费步数就会失败。早期只教推箱，后期同时处理多种危险。 | 步数上限做成**附加挑战**（拿额外奖励），不作为过关条件，避免逼玩家背最优解。 |
| A Monster's Expedition | 开放的岛屿网络，常常同时有多条路可走，卡住可以先去别处；也有人觉得因此缺少方向。 | 地狱模式每层同时开放多关，可以跳着做；用"层"给出方向感。 |

来源：[Destructoid 评测](https://destructoid.com/reviews/review-stephens-sausage-roll)、[Slant Magazine 评测](https://www.slantmagazine.com/games/stephens-sausage-roll/)、[Critic 评测](https://www.critic.co.nz/culture/article/5926/stephens-sausage-roll)、[Wikipedia：Helltaker](https://en.wikipedia.org/wiki/Helltaker)、[Escapist 评测](https://www.escapistmagazine.com/helltaker-is-a-demonically-delightful-and-free-puzzler/)、[Wikipedia：A Monster's Expedition](https://en.wikipedia.org/wiki/A_Monster%27s_Expedition)、[Push Square 评测](https://www.pushsquare.com/reviews/ps5/a-monsters-expedition)、[攻略中关于多条路线的建议](https://www.appunwrapper.com/2020/09/10/a-monsters-expedition-walkthrough-guide/)。

## 5 局外养成的分寸

| 参考 | 做法 | 风险 |
|---|---|---|
| Hades | 用局内货币在"夜之镜"购买永久强化，同时推动剧情；续作改为卡牌式的多货币系统。 | 有玩家认为强化让游戏明显变简单，初学者不靠强化几乎打不通。 |
| Dead Cells | 解锁新的起始装备和武器，永久数值提升较少；"细胞"难度反而让游戏变难。 | 有评论认为真正的进步主要在玩家自己的熟练度。 |
| Slay the Spire | 解锁很少，很快解锁完，主要靠一局内的构筑。 | 养成层很薄。 |

共识：养成太弱没有意义，太强会把单局挑战变得太简单；它应当增强以技巧为核心的玩法，而不是取代它。我们的做法：**以解锁多样性为主、数值为辅**；关卡模式和地狱模式完全不受养成数值影响（见 [局外养成](../design/progression.md)）。

来源：[Bugnet：How to design a roguelite meta progression](https://bugnet.io/blog/how-to-design-a-roguelite-meta-progression)、[GameBrief：meta progression](https://www.gamebrief.net/glossary/meta-progression)、[Steam 讨论：Hades 夜之镜](https://steamcommunity.com/app/1145350/discussions/0/4358999171576511867)、[Steam 讨论：Hades II](https://steamcommunity.com/app/2106670/discussions/0/4342111331714355103)、[社区讨论：养成开始让人觉得没有回报](https://lonestarpiefed.duckdns.org/post/24798)。

## 6 名称用到的拉丁词

| 词 | 含义 | 出处 |
|---|---|---|
| *perfer* | 动词 *perferō*（per + ferō）的命令式：把东西一路带到、送达（消息、信件），也指忍受到底。奥维德三次用 *perfer et obdura*（"坚持，挺住"）。 | 短语用法见 [Greece & Rome 论文](https://resolve.cambridge.org/core/journals/greece-and-rome/article/abs/difficile-est-longvm-svbito-deponere-amorem/E5443AB59780FF94A3493AAC90CE9446)；"送达"义取自 Lewis & Short 等标准拉丁词典（本次在线词典无法访问，未能在线复核原文） |
| *cursus* | 奔跑、路线；*cursus publicus* 是奥古斯都设立的罗马国家驿传，沿路有换马站（*mutationes*）和住宿站（*mansiones*）。 | [Wikipedia：Cursus publicus](https://en.wikipedia.org/wiki/Cursus_publicus) |
| *capsarius* | 由 *capsa*（书匣）而来：替上学的孩子背书匣的奴仆，也指管书匣的人。 | [Cambridge Latin Course 词汇](https://www.dl.cambridgescp.com/weblink/1419)、[Smith 古典辞典](https://digi.ub.uni-heidelberg.de/diglit/smith1871/0079) |
| *baiulus* / *gerulus* | 搬运工、挑夫。 | [latindictionary.io：gerulus](https://www.latindictionary.io/word/gerulo)、[Wiktionary：baiulus](https://en.wiktionary.com/wiki/baiulus) |
| *portitor* | 搬运者、摆渡人；维吉尔《埃涅阿斯纪》第 6 卷用它称呼冥河渡夫卡戎。 | 标准拉丁词典与《埃涅阿斯纪》6.298（未能在线复核） |
| *sarcina* | 包裹、行囊（士兵随身的背包）。 | 标准拉丁词典（未能在线复核） |

重名检索（2026-10-15，网页搜索，仅作初筛，最终需查商标和各商店）：没有找到名为 Perfer、Cursus、Portitor、Sarcina 的游戏；Capsarius 是《RuneScape》中一个首领的名字（[Prima Games](https://primagames.com/gaming/runescape-capsarius-soul-guide)）；最接近 Portitor 的是解谜游戏 *Portarius*（[GamingOnLinux](https://www.gamingonlinux.com/2018/05/portal-puzzler-portarius-is-now-available-on-linux)）。搜索结果里都是拼写相近的其他作品，没有同名游戏。

## 7 局外养成如何影响局内又不破坏平衡（GD-4 补充）

| 参考 | 做法 | 我们怎么用 |
|---|---|---|
| 吸血鬼幸存者（PowerUps） | 每购买一次，下一次价格按基础价加 10%；可以随时一键退款重新分配，开发者说明退款没有损失 | 工坊属性逐级加价；随时免费重置 |
| Rogue Legacy 2（庄园升级） | 每次升级都让其他升级变贵，同样的属性加成越来越贵；也有评论批评重复加属性的节点太多 | 每级加价，并且每项都有上限，避免无聊的"堆数值" |
| Hades II（Arcana 与 Grasp） | 用 Grasp 上限限制同时生效的卡牌，上限远低于全部卡牌的总花费，所以每局都要取舍 | 徽章点上限 |
| 空洞骑士（护符槽） | 开局 3 个护符槽，最多 11 个；每个护符占 1 个以上的槽 | 徽章占 1–3 点 |
| 死亡细胞（收藏家） | 血瓶次数是永久升级，高级升级要先解锁足够多的物品；细胞死亡即失去 | 高级属性设前置条件；失败只带回一半金币 |
| 挺进地牢（Hegemony Credits） | 用局外货币在大本营购买新物品，买下后它们才会出现在之后的局里；局内另有商人用局内金币交易 | 解锁进奖池；局内驿站与局外商店分开 |
| Hades（惩罚契约） | 首次逃出后开放，叠加修正项提高 Heat，热度越高奖励越多 | 加急令 |
| 炸弹人 | 加速、炸弹数、火力范围都是拾取强化，各有上限，堆太多速度反而难控制 | 局内增益有上限；移动速度上限 +25% |
| Boulder Dash | 按格挖掘的实时游戏；落石会压扁敌人，也会压到自己；每个洞穴有时限，越往后越短 | 配送模式采用网格实时；压怪 |
| Luck be a Landlord | 以老虎机为核心的肉鸽游戏，用重转令、移除令改变随机结果；有玩家抱怨选项不能重转 | 双滚轮的重转、锁定、推一格 |

来源：[吸血鬼幸存者 PowerUps 价格与顺序](https://gamerjournalist.com/vampire-survivors-powerups/)、[Steam 指南（加价与退款）](https://steamah.com/vampire-survivors-optimal-powerup-selection-order-guide/)、[Vampire Survivors Wiki：PowerUp](https://vampire-survivors.fandom.com/wiki/PowerUp?oldid=5168)、[Steam 讨论（退款无损）](https://steamcommunity.com/app/1794680/discussions/0/3201493834358639726)、[Game Informer：Rogue Legacy 2 评测](https://gameinformer.com/review/rogue-legacy-2/generations-of-greatness)、[GGRecon：Rogue Legacy 2 技能树](https://www.ggrecon.com/guides/rogue-legacy-2-skill-tree/)、[Maxroll：Hades 2 Arcana](https://maxroll.gg/hades-2/guides/hades-2-arcana-guide)、[RogueRanker：Hades 2 Arcana](https://rogueranker.com/hades-2-arcana/)、[Team Cherry：Charm Collection](https://teamcherry.com.au/revealing-the-power-of-the-charms)、[TrueAchievements：Hollow Knight 基础](https://www.trueachievements.com/game/Hollow-Knight/walkthrough/2)、[Dead Cells Wiki：Health Flask](https://deadcells.wiki.gg/wiki/Health_Flask)、[Dead Cells Wiki：Cells](https://deadcells.wiki.gg/wiki/Cells)、[Enter the Gungeon Wiki：Hegemony Credit](https://enterthegungeon.wiki.gg/wiki/Hegemony_Credit)、[Enter the Gungeon Wiki：Ox and Cadence](https://enterthegungeon.wiki.gg/wiki/Ox_and_Cadence)、[RPG Site：Hades 惩罚契约](https://www.rpgsite.net/feature/10287-hades-pact-of-punishment-heat-modifiers-and-how-to-maximize-your-rewards)、[Bomberman Wiki：Power-Ups](https://bomberman.fandom.com/wiki/Power-Ups?oldid=3938)、[Saturn Bomberman（Sega Retro）](https://segaretro.org/Bomberman_SS)、[Giant Bomb：Boulder Dash](https://www.giantbomb.com/boulder-dash/3030-2991/)、[Sinclair User：Boulder Dash 评测](https://everygamegoing.com/larticle/Boulder-Dash-1-000/37039)、[Twinfinite：Luck be a Landlord 移除令](https://twinfinite.net/guides/how-remove-symbols-luck-be-a-landlord/)、[Steam 讨论：Luck be a Landlord 选项重转](https://steamcommunity.com/app/1404850/discussions/0/3128289956327877528)。

## 8 中文名检索

搜索"万物摆渡人""渡界人"没有找到同名游戏或小说；相近题材有《灵魂摆渡者》（Spiritfarer 的中文名，见[机核](https://www.gcores.com/articles/216965)）。
