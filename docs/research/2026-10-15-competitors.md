# 市面上有没有类似的游戏（2026-10-15）

问题：《渡界人 / PORTITOR》的思路——**按格推箱解谜 + 真实的落沙物理（ele-base-cpp SDK）+ 双滚轮决定"送什么、送给谁"的肉鸽配送 + 融合世界各地文化的地区**——市面上有没有类似的？

结论先说：**没有找到把这几样放在一起的游戏**。但每一样单独都有先例，其中几款很值得借鉴，也提醒了我们要避开的坑。检索只覆盖英文和中文网页、Steam 与 itch.io 的公开信息，不是完整的市场调研。

## 1 逐项对照

| 我们的要素 | 最接近的游戏 | 它怎么做 | 和我们的区别 / 借鉴 |
|---|---|---|---|
| 一开局用滚轮定下整局内容 | **Fate Machine**（Gin Drinkers Studio，2025 年 12 月） | 每局开始拉一次三轴老虎机，决定地牢的房间布局、战利品和敌人 | 最接近"开局滚轮"的先例。它滚的是地牢结构，我们滚的是**货物 × 收件人**，并且两者有缘分组合 |
| 滚轮贯穿全程 | **RP7**、**Slots & Daggers**、**Spin Hero**、**Luck be a Landlord** | 用老虎机决定每一步的事件或战斗 | 我们只在开局和连送时转，不让随机性主导解谜 |
| 送货本身就是规则 | **Mika and the Witch's Mountain**（类《魔女宅急便》） | 包裹有搬运要求：易碎、不能沾水、限时；报酬看送达表现 | 和我们的货物规则几乎一样。但评测批评它**送货重复、内容太短**——我们靠缘分组合、地区机制、事件和连送来避免重复 |
| 肉鸽 + 送货 | **Adventure Delivery Service**（2018，小众）；**Delivery Survivors**（计划 2026 年第四季度） | 前者：去地牢找回被怪物抢走的包裹；后者：送货题材的割草类肉鸽（自称 Brotato 加 Slay the Spire） | 都是动作向，没有物理解谜，也没有"送给谁" |
| 物理送货 | **Mars First Logistics**（Steam 好评如潮）、**Totally Reliable Delivery Service**、**Death Stranding** | 用物理载具或身体平衡运货 | 3D 物理、动作操作；我们是 2D 按格、可预测的格子规则 + 材料模拟 |
| 落沙物理 | **Noita**（肉鸽动作）、**Sandustry**（自动化工厂，Demo 好评 97%）、**Pixel Sand**（落沙解谜平台） | 每个像素都是模拟的材料 | 证明落沙物理有市场；但它们都不是按格推箱解谜 |
| 按格推箱 + 重力 | **Simple Block Pushing Platform Game**（PuzzleScript 小作品）、**Void Stranger**、**Helltaker**、**Stephen's Sausage Roll** | 侧视推箱带重力，或纯推箱 | 推箱解谜很多，但带真实材料模拟的几乎没有 |
| 推箱肉鸽 | **Crypt of Sokoban**（2025 年游戏节作品）、**Sokorogue**（itch.io 抢先体验） | 随机生成的推箱房间 + 局外养成 | 规模很小，验证了"推箱 + 肉鸽"这个组合能成立 |
| 给亡灵送东西、地府题材 | **Courier of the Dead**（给亡灵送信、躲开游荡的鬼魂）；国产《地府有点忙》（动作肉鸽）、《百夜地府》（模拟经营）、《地府打工魂》（放置） | 地府在国产独立游戏里很受欢迎 | 我们的地府只是众多地区之一，玩法是送货解谜 |
| 摆渡人 | **《灵魂摆渡者》（Spiritfarer）** | 摆渡亡灵、经营船只 | 名字上要和"摆渡"拉开距离；"渡界人"不用"摆渡"二字，正好避开 |

## 2 我们的独特之处

1. **真实材料 + 按格推箱**：别人的推箱是抽象方块，我们的沙会流、水会涨、火会烧，而且规则可预测。
2. **送什么 × 送给谁**：货物和收件人各自带规则，组合起来产生新的玩法（缘分组合），比单纯"运到终点"更有故事。
3. **关卡模式就是机制实验室**：每个新机制先做成关卡验证，再进入配送和地狱模式，内容可以一层层安全地加。
4. **世界各地文化的地区**：中国风（含地府）、日本、韩国、印度、北欧、希腊、玛雅……一个摆渡人走遍万界。

## 3 要避开的坑（来自评测）

| 坑 | 来源 | 我们的对策 |
|---|---|---|
| 送货重复、跑腿感强 | Mika 的评测 | 每单的货物 × 收件人 × 地区都不同；缘分组合；事件；连送 |
| 内容太短 | Mika 的评测 | 内容分层持续加；关卡模式 + 配送模式 + 地狱模式 |
| 物理不可控、令人沮丧 | Totally Reliable Delivery Service 的评测 | SDK 结果可重复；关卡模式先验证；按格操作 |
| 随机结果太差、无法补救 | Luck be a Landlord 玩家的抱怨 | 重转、锁定、推一格 |
| 难度陡、教程含糊 | Mars First Logistics 的评测 | 关卡模式循序渐进地教每个机制 |

## 来源

- [Fate Machine（PlayPile）](https://playpile.gg/games/fate-machine)、[RP7（Game Developer）](https://www.gamedeveloper.com/press-release/cute-and-cuddly-slot-managing-roguelike-rp7-reveals-an-all-new-gameplay-trailer)、[Slots & Daggers 评测](https://www.useapotion.com/2025/11/slots-daggers-review-a-clever-spin-on-roguelites/)、[Spin Hero](https://vaporlens.app/app/2917350/spin_hero.md)
- [Mika and the Witch's Mountain：Shacknews 评测](https://www.shacknews.com/article/142812/mika-and-the-witchs-mountain-review-score)、[Siliconera 评测](https://www.siliconera.com/review-mika-and-the-witchs-mountain-channels-kikis-delivery-service/)、[CGMagazine 评测](https://www.cgmagonline.com/review/mika-and-the-witchs-mountain/)、[OpenCritic](https://opencritic.com/game/17178/-)
- [Adventure Delivery Service（itch.io）](https://miller-tinkerhess.itch.io/adventure-delivery-service)、[SteamSpy](https://steamspy.com/app/867010)、[Delivery Survivors（Steam）](https://store.steampowered.com/app/4467940)
- [Mars First Logistics（Steam）](https://store.steampowered.com/app/1532200)、[Roundtable Co-Op 评测](https://roundtablecoop.com/reviews/mars-first-logistics-early-access-review/)、[Totally Reliable Delivery Service：Checkpoint 评测](https://checkpointgaming.net/reviews/2020/04/totally-reliable-delivery-service-review-bright-colourful-and-hilarious)、[COGconnected 评测](https://cogconnected.com/review/working-totally-reliable-delivery-service-review/)
- [Sandustry（PCGamesN）](https://www.pcgamesn.com/sandustry/steam-hooded-horse)、[GamingOnLinux](https://www.gamingonlinux.com/2025/06/in-the-side-scroller-automation-game-sandustry-every-single-pixel-is-a-simulated-resource/page=1/)、[Pixel Sand（itch.io）](https://kongroth.itch.io/pixelsand)、[Sandspiel](https://linuxlinks.com/sandspiel-pixel-physics-simulation-sandbox)
- [Simple Block Pushing Platform Game](https://yergicol.itch.io/simple-block-pushing-platform-game)、[Crypt of Sokoban（7DRL 2025）](https://itch.io/jam/7drl-challenge-2025/rate/3376640)、[Sokorogue](https://icely.itch.io/sokorogue/purchase)、[Roboggled 与 Void Stranger（GamingOnLinux 评论区）](https://www.gamingonlinux.com/2021/02/roboggled-is-a-nice-casual-sokoban-inspired-block-pushing-puzzler-out-now/comment_id=198419)
- [Courier of the Dead（Epic）](https://store.epicgames.com/p/courier-of-the-dead-a4dcd9)、[《百夜地府》（IT 之家）](https://www.ithome.com/0/968/379.htm)、[《地府有点忙》（IT 之家）](https://www.ithome.com/0/979/849.htm)、[《灵魂摆渡者》（机核）](https://www.gcores.com/articles/216965)
