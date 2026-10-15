# 推箱子：沙与水 · 美术工程化管理与多风格地图设计方案（经代码级审核与大图玩法扩展版）

> 专题范围：本文件保留旧阶段的美术架构与实施依据；其中指向关卡设计第 0、2.1–2.6 节的旧 36 关规格引用已失效，不能按这些章节号解释新版方案。当前玩法与难度以 [横版重设计草案](mode-and-level-design.md) 为准，实际完成情况见 [进度看板](../v2/status.md)。

更新日期：2026-10-14（Asia/Shanghai）
关联文档：[项目目标与需求记录](project-goals.md) · [界面与美术规范](../reference/ui-art-direction.md) · [阶段演进与 36 关关卡池设计方案](mode-and-level-design.md) · [三大阶段开发总规划](../archive/plans/2026-10-14-three-modes-and-mechanisms.md)

> **阶段定位说明**：当前项目已完成**第一阶段（教学关卡 `T01–T04` 与纯代码美术基线）**验收，并拆分为：
> 1. **阶段 1.5**：美术资源目录模块化改造 + 六大风格大地图实机预览器（即**观察池 Observation Pool** 雏形）；
> 2. **第二阶段 A（优先执行 · 零改 C++ 引擎）**：100% 基于现有 `ele-base-cpp v1.2.0` 引擎落地 **6 大地图 × 每图 6 关 = 36 关 100% 有解关卡池 + 观察池 + 通关 3 关解锁下一地图**，先供外部玩家试玩；
> 3. **第二阶段 B（试玩反馈后启动）**：根据外部试玩反馈再去 C++ SDK 仓库扩展底层新特性。

## 0. 方案深度审核结论与 6 项底层代码防坑修正（Code-Level Audit）

对照仓库内现有的自动化测试（[`tests/procedural_art.gd`](../../tests/procedural_art.gd)、[`tests/bugfix.gd`](../../tests/bugfix.gd)、[`tests/v03_render.gd`](../../tests/v03_render.gd)、[`tests/performance.gd`](../../tests/performance.gd)）与渲染实现（[`board_view.gd`](../../pushbox/scripts/ui/board_view.gd)、[`world.gdshader`](../../pushbox/scripts/render/world.gdshader)、[`game.gd`](../../pushbox/scripts/game.gd)），对初版美术方案进行了逐行对抗审核，查出并修正了 **6 处会导致测试挂死或画面穿帮的底层隐患**：

| 审核发现隐患 | 现有代码与测试约束根因 | 修订后强制执行规范 |
| :--- | :--- | :--- |
| **1. `tests/procedural_art.gd` 的 SHA-256 逐字节锁死与源码全文字符串扫描** | [`tests/procedural_art.gd`](../../tests/procedural_art.gd) 会将 `Style.texture(name)` 生成的图像与 [`tests/fixtures/art_rgba_v03.json`](../../tests/fixtures/art_rgba_v03.json) 做 **RGBA 字节级 SHA-256 比对**，检查 `Style.texture(name) == texture` 引用恒等，并用 `source.contains(".png")`、`shader.contains("bedrock_tex")` 扫描源码全文。 | 1. **基线矩阵零像素改动**：收录在 `art_rgba_v03.json` 中的所有默认精灵在拆分文件时必须 100% 保持原矩阵像素，禁止对基线精灵做会导致哈希变化的算法重写；参数化生成仅用于新风格变体与新资产。<br>2. **API 双轨隔离**：`Style.texture(name)` 永远返回默认地牢基线贴图（确保测试与 [`tests/bugfix.gd`](../../tests/bugfix.gd) 第 100 行人物朝左逐像素比对 100% 通过）；场景渲染层改调新增的 `Style.themed_texture(name, theme_id)`。<br>3. **注释禁词令**：`pixel_style.gd` 与 `world.gdshader` **连注释中都严禁出现** `.png`、`Image.load_from_file`、`bedrock_tex`、`cracked_tex` 字符串。 |
| **2. `board_view.gd` 闸门动画并非播放序列帧，而是裁剪 `gate_closed_0`** | [`board_view.gd`](../../pushbox/scripts/ui/board_view.gd) 第 155 行实际并未调用 `gate_open_0..5`，而是对 `16×32` 的 `gate_closed_0` 执行 `draw_texture_rect_region(..., Rect2(0, i * 16 + height, 16, 16 - height))` 平移裁剪（且 `i >= 2` 时会越界）。 | 1. 修正采样纵坐标为 `(i % 2) * 16 + height`，兼容任意高度闸门。<br>2. 区分两类闸门动画协议：**机械升降型**（地牢/森林/遗迹/洞穴）沿用平移裁剪；**能量消散型**（天空岛光羽门、宇宙激光力场门）固定绘制顶底发射器底座，中间光束按 `1.0 - lerpf(before, after, _gate_age)` 做 Alpha 衰减与宽度收缩，避免发射器底座随开门一起向上悬空平移。 |
| **3. `board_view.gd` 箱体渲染未区分 `box.kind`，且悬停预演存在第二处硬编码** | [`board_view.gd`](../../pushbox/scripts/ui/board_view.gd) 在第 164 行（实机箱体）与第 207 行（`preview.boxes` 悬停虚影）两处均硬编码了 `_sprite("crate_static_0", ...)`。 | 在 `board_view.gd` 中统一封装 `_box_sprite(box: Dictionary) -> String`（按 `box.get("kind", "wood")` 映射 `"crate_iron_0"` 或 `"crate_static_0"`），并在实机绘制与 `preview.boxes` 虚影绘制两处同步接入 `Style.themed_texture()`。 |
| **4. `world.gdshader` 逐像素坐标限制导致“3px 森林草皮 / 天空岛云托底”无法仅靠 `px ± (0,1)` 实现，且新材质会漏出底色** | 在 [`world.gdshader`](../../pushbox/scripts/render/world.gdshader) 中，`px` 是 cell（像素）级坐标而非 16×16 格坐标：只查 `px - ivec2(0,1)` 仅能让最顶上 1 行像素变色；且 `mat != crate_id` 未排除第二阶段的 `iron_crate_id`，会导致铁箱背后的 SDK 占位色块被渲染出来。 | 1. **跨像素深度探针**：在 `world.gdshader` 中查询整格顶边外侧像素 `material_at(TEXTURE, px - ivec2(0, int(tile_pixel.y) + 1))` 与底边外侧像素 `material_at(TEXTURE, px + ivec2(0, 16 - int(tile_pixel.y)))`，从而在 `tile_pixel.y` 的 `0..2` 或 `13..15` 范围内完整绘制 3px 厚的森林草皮、天空岛底面云絮与宇宙平台警示条纹（底面云絮同时排除 `room_rect` 最底行外框）。<br>2. **补齐占位与暴露 ID**：将 `iron_crate_id` 加入透明排除条件，并将 `iron_crate_id`、`acid_id` 加入 `exposed` 受光边判定。 |
| **5. `game.gd` 局内背景 `region_rect` 裁剪导致靠边构图在中小房间被裁没** | [`game.gd`](../../pushbox/scripts/game.gd) 第 117 行将 `background.region_rect` 设为房间实际尺寸（如 `10×6` 格仅截取画布中央 `160×96` 区域）。若将森林树干、宇宙舷窗画在 `320×180` 两侧边缘，局内会被完全裁掉。 | 所有主题的背景生成函数必须采用**全画布均匀周期排布（`32×32` 或 `64×45` 周期网格）**，保证无论房间是 `10×5`、`20×11` 还是大尺寸 `32×18`，裁剪出的 `region_rect` 内部都包含完整的视觉锚点（树干/神庙柱/钟乳石/云层/星云桁架）。 |
| **6. GDScript 双层循环逐像素画背景图的 CPU 耗时过高** | `_cave()` 在 GDScript 中跑 `320×180 = 57,600` 次 `set_pixel` 循环；若新增 5 套复杂大地图背景并在启动时全量生成，会拉长启动与切关耗时。 | 1. **按需懒加载 + 缓存**：`Style.warm_assets()` 仅预热默认基线贴图；各主题背景与覆盖贴图在进入对应主题关卡时按需生成并常驻缓存。<br>2. **批量块绘制**：新主题背景优先使用 `Image.fill()` 与 `Image.fill_rect(Rect2i(...), color)` 替代内层 `set_pixel` 循环，单张背景生成耗时可从 `~10 ms` 压至 `< 0.3 ms`。 |

## 1. 现状诊断与核心痛点

当前第一阶段已实现“零外部贴图文件依赖”的纯代码像素美术管线，但在面向第二阶段（闯关模式、多风格地图、独特环境机关）与第三阶段（地狱挑战大地图）扩展时，现有代码组织存在 4 处明显瓶颈：

| 模块文件 | 当前实现方式 | 后续扩展痛点 |
| :--- | :--- | :--- |
| [`pushbox/scripts/ui/procedural_art.gd`](../../pushbox/scripts/ui/procedural_art.gd) | 单个 600+ 行文件塞入 `PALETTE`、全部角色/机关/UI 的 `PIXELS` 字符矩阵、`NAMES` 别名映射及 `_cave()` 背景绘制函数 | 第二、三阶段新增铁箱、酸液、浮石、冰块、各风格独特机关及 6+ 套地图主题后，单文件将膨胀至 4000+ 行，字符画极难检索、比对与分模块维护 |
| [`pushbox/scripts/ui/pixel_style.gd`](../../pushbox/scripts/ui/pixel_style.gd) | 仅维护扁平字典 `_textures[name]`，全量一次性 `warm_assets()`，无“地图主题（Biome Theme）”上下文概念 | 无法根据当前关卡动态切换同逻辑实体的不同风格外观（例如地牢木箱 vs 森林藤箱 vs 宇宙货舱箱） |
| [`pushbox/scripts/render/world.gdshader`](../../pushbox/scripts/render/world.gdshader) | 在 `fragment()` 中硬编码单一地牢配色的 `bedrock()`、`cracked_rock()`、`sand` 与 `water` | 新增森林草皮、遗迹砂岩、洞穴晶簇、天空岛云石、宇宙合金甲板等地形时，若直接堆砌分支会导致着色器臃肿且色板难以复用 |
| [`pushbox/scripts/ui/board_view.gd`](../../pushbox/scripts/ui/board_view.gd) & [`pushbox/scripts/game.gd`](../../pushbox/scripts/game.gd) | 硬编码 `"cave_bg"`、`"lantern_idle_%d"`、`"crate_static_0"` 及固定粒子色值（如 `Color("c28569")`、`Color("e4a672")`） | 背景图、环境挂件（挂灯/萤火虫/圣火盆/全息信标）及挖掘/爆破粒子颜色无法随关卡风格自动切换 |

## 2. 纯代码美术目录架构设计（Modular Art Architecture）

### 2.1 目标目录结构

将原先集中在 [`pushbox/scripts/ui/procedural_art.gd`](../../pushbox/scripts/ui/procedural_art.gd) 的代码拆分为独立的 **`pushbox/scripts/art/`** 模块体系，按**「底层图元工具 → 实体分类图库 → 主题风格包 → 统一注册中心」**四层组织：

```text
pushbox/scripts/
├── art/
│   ├── art_registry.gd          # 【核心门面】统一纹理/主题注册表，向 pixel_style.gd 提供基线缓存、主题按需生成与三级回退
│   ├── palette.gd               # 【色彩中心】ENDESGA 32 标准色表 + 语义化颜色槽位（Semantic Color Slots）与色板重映射工具
│   ├── canvas_ops.gd            # 【绘图图元】字符矩阵编译、fill_rect 批量块填充、Bresenham 画线、抖动过渡、确定性哈希 h32
│   │
│   ├── sprites/                 # 【按业务域拆分的精灵定义】告别单文件巨型字典（基线矩阵保持 100% SHA-256 一致）
│   │   ├── actors/
│   │   │   ├── miner_art.gd     # 主角各动作帧（idle/walk/push/climb/dig/pour/fall/win）及主题装束微调覆盖
│   │   │   └── hazards_art.gd   # 动态威胁与独特实体：石像鬼（gargoyle）、钟乳石重锤（stalactite）、间歇泉喷口（geyser）
│   │   ├── props/
│   │   │   ├── crates_art.gd    # 箱体家族：木箱（crate_static_0）、沉水铁箱（crate_iron_0）及各风格皮肤变体
│   │   │   ├── mechanisms_art.gd# 通用机关：闸门（gate）、梯子（ladder）、拉杆（lever）、压板（plate）、目标（target）
│   │   │   ├── biome_gimmicks_art.gd # 【新增】各风格专属机关：森林吸水藤种、遗迹流沙漏斗/天平、天空风向标/云垫、宇宙重力发生器/传送座
│   │   │   └── ambient_art.gd   # 环境装饰：地牢挂灯、森林萤火虫笼、遗迹火盆、洞穴发光晶簇、天空风铃灯、宇宙信标
│   │   ├── fx/
│   │   │   └── particles_art.gd # 序列帧特效：爆炸（explosion）、酸蚀气泡、冰晶碎裂、风流线、反重力星尘
│   │   └── ui/
│   │       ├── hud_icons_art.gd # HUD 与大厅图标：炸药、沙袋（0..7 满度）、锁头、模式徽章、章节图标
│   │       └── prompts_art.gd   # 引导与交互：键帽、鼠标左右键、拖拽小手、铲子指针、九宫格面板
│   │
│   └── themes/                  # 【多风格地图主题包】定义每种风格的背景生成、Shader 参数、专属机关皮肤与粒子配色
│       ├── theme_base.gd        # 主题数据契约基类（ThemeSpec）
│       ├── theme_dungeon.gd     # 0. 地牢风格（幽暗石牢 · 教学与经典基准）
│       ├── theme_forest.gd      # 1. 森林风格（迷雾古森 · 树根与苔藓秘境）
│       ├── theme_ruins.gd       # 2. 遗迹风格（黄金沙海 · 古代太阳神庙）
│       ├── theme_cave.gd        # 3. 洞穴风格（幽光晶窟 · 钟乳石与地下酸/熔岩脉）
│       ├── theme_sky_island.gd  # 4. 天空岛风格（云端圣域 · 浮空大理石与风之城）
│       └── theme_cosmos.gd      # 5. 宇宙风格（深空星站 · 钛合金舱段与陨石实验室）
│
├── render/
│   ├── world.gdshader           # 升级为支持 `biome_style_id`、跨像素深度探针与主题色板 Uniform 注入的程序化地形着色器
│   └── theme_shader_binder.gd   # 负责将当前关卡 ThemeSpec 的颜色与材质参数一键绑定到 EleWorld 的 ShaderMaterial
│
└── ui/
    ├── pixel_style.gd           # 保持 `Style.texture(name)` 基线恒等，新增 `Style.themed_texture(name, theme_id)`
    ├── biome_showcase_view.gd   # 【观察池 / 阶段 1.5 预览器】支持在游戏内按左右键或菜单直接切换检视 6 大风格地图与关卡池全景
    └── procedural_art.gd        # 保留为轻量兼容转发层（确保现有 14+1 自动化测试脚本零修改通过）
```

### 2.2 核心模块职责与解耦机制

1. **双轨缓存与三级主题解析机制（`art_registry.gd` & `pixel_style.gd`）**：
   - **基线轨（`Style.texture(name)`）**：直接读写 `_base_textures[name]`，始终返回 `dungeon` 默认基线贴图，保证 [`tests/procedural_art.gd`](../../tests/procedural_art.gd) 的 SHA-256 校验与 [`tests/bugfix.gd`](../../tests/bugfix.gd) 的逐像素镜像检查在任何时候运行都 100% 通过。
   - **主题轨（`Style.themed_texture(name, theme_id)`）**：供 `board_view.gd`、`biome_showcase_view.gd` 与 `game.gd` 渲染场景时调用，按“1. 主题专属重绘矩阵 → 2. 主题调色板重映射（Palette Swap）→ 3. 全局默认基线（Fallback）”三级优先级查找并缓存在 `_themed_textures[theme_id][name]`。

2. **大尺寸地图规格与视口扩展设计（Large Map Support）**：
   - 教学关（`T01–T04`）为了快速上手仅使用 `10×6` 到 `12×5` 的微型房间；而**第二阶段多风格正式地图与展示地图**全面涵盖从 `12×7`（★入门）、`16×9`（★★进阶）到 `20×11`～`32×18`（★★★大师大图与观察池全景）的多层次空间尺度。

## 3. 多风格地图视觉与元素表现总设计（6 大核心主题）

所有地图风格严格遵循 [`docs/reference/ui-art-direction.md`](../reference/ui-art-direction.md) 的三大铁律：
1. **调色板锁定 [ENDESGA 32](https://lospec.com/palette-list/endesga-32)**：所有实心像素仅取自 32 色标准色表（流体与光晕允许 Alpha 半透明混合），保持全游戏视觉高度统一。
2. **统一 1 像素 `#181425`（`ink`）深色描边与左上 45° 光源**：确保前景活动物件（人物、箱子、闸门、专属机关）与背景墙、地形之间永远具备极高辨识度。
3. **周期性全画布背景与“大块、安静”纹理原则**：背景纹理以 `32×32` 或 `64×45` 为周期铺满画布，确保任意大小的房间裁剪框内都有完整的风格视觉特征；噪点仅用于可挖掘的 `sand` / `pumice`。

### 3.1 六大地图风格视觉与玩法全局对照表

| 风格代号与名称 | 关卡池配置 | 远景背景与环境光（`bg` & `ambient`） | 地形着色器特征（`world.gdshader`） | 常规基础玩法（Shared Core） | **地图独特专属玩法（零改引擎即可在 2A 实现）** |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **0. 地牢风格**<br>`dungeon`<br>（幽暗石牢） | 6 关池 `D01–D06`<br>（通 3 关解森林） | 深紫黑错缝石砖墙、闪烁铁挂灯、微尘 | 16×16 蓝灰石砖、暖褐分叉裂岩、暖黄矿沙、清澈地下水 | 推木箱/铁箱、挖沙倒沙造坡、拉杆/压板铁闸门、连通器浮箱、十字爆破 | **千斤防夹闸与矿道塌方（Crush Lock & Collapse）**：向开启的铁闸门缝倒沙卡死千斤闸（`crush_max`），或炸断矿道木撑引发顶部碎石塌方填谷 |
| **1. 森林风格**<br>`forest`<br>（迷雾古森） | 6 关池 `F01–F06`<br>（通 3 关解遗迹） | 巨木树干剪影、垂挂青藤、萤火虫灯笼、绿孢子 | 深褐盘根岩土（**裸露顶面自动生长 3px 翠绿草皮**）、中空朽木塞、金色花粉沙、翡翠林泉 | 推藤箱/青苔石箱、挖倒花粉沙、林泉连通器、炸毁中空朽木 | **吸水生长藤梯与浮木树桥（Hydro-Growing Vines）**：引林泉水灌溉“枯藤种格（`vine_seed`）”，藤蔓遇水自动向上生长为可爬藤梯；爆破朽木可斩断藤蔓落箱 |
| **2. 遗迹风格**<br>`ruins`<br>（黄金神庙） | 6 关池 `R01–R06`<br>（通 3 关解洞穴） | 暗金砂岩柱廊、太阳纹浮雕方砖、壁龛圣火盆 | 暖赭象形石雕砖（亮金受光顶边）、风化砂岩柱、撒哈拉亮金流沙、绿洲碧水 | 推圣物箱/黑曜石匣、金沙塑形、压板雕花石门、沉沙囊排水 | **流沙计时漏斗与双盘配重天平（Sand Hourglass & Scales）**：神庙顶层流沙漏斗定量漏沙改变上下层体积；左右联动的黄金天平盘（左盘压箱或堆沙，右盘石台自动等距升起） |
| **3. 洞穴风格**<br>`cave`<br>（幽光晶窟） | 6 关池 `C01–C06`<br>（通 3 关解天空岛） | 起伏天然岩层、洞顶钟乳石群、青/紫发光晶簇 | 天然斜向玄武岩层理（带荧光矿点）、**硫磺亮黄矿脉裂岩**、碎晶矿砂、翠绿强酸与赤红岩浆 | 推矿箱/矿车箱、酸液顶面蚀岩、水火对流化浮石沙、双色沙分流 | **钟乳石震落重锤与间歇酸/熔岩泉（Stalactite Drop & Geysers）**：引爆或酸蚀洞顶支撑后，巨型钟乳石直落砸穿下方岩壳或堵住间歇喷发的酸液/水泉眼 |
| **4. 天空岛风格**<br>`sky_island`<br>（云端圣域） | 6 关池 `S01–S06`<br>（通 3 关解宇宙） | 破晓渐变天幕、多层像素云海、悬浮风灯球 | 镶金白大理石（**悬空平台底面自动生成 3px 纯白云絮托底**）、风蚀天柱石、以太金尘、高反光冰桥 | 推白羽箱/白金锚箱、急冻冰桥/解冻切换、云沙垫高、光羽风障门 | **定向风场偏转与浮云弹性软垫（Wind Emitter & Cloud Pad）**：拨动风向标开启顺风场，将倒出的云沙吹偏 1 格或让冰面箱子顺风滑行；“浮云软垫格”仅托住轻木箱，铁箱压上即穿透下坠 |
| **5. 宇宙风格**<br>`cosmos`<br>（深空星站） | 6 关池 `X01–X06`<br>（通 3 关通主线） | 深空星云、十字繁星、空间站舷窗桁架、全息信标 | 钛合金铆钉装甲板（**平台顶边自动绘制 2px 黄黑斜向警示条纹**）、电弧过载陨石裂岩、月壤星尘、冷却液与等离子流 | 推复合货运箱/引力重箱、冷却液浮力、等离子化沙、激光力场门 | **舱段局部重力反转与量子传送座（Gravity Flip & Teleporter）**：扳动反重力开关使舱内轻货箱与星尘向上吸附至舱顶（磁吸铁箱锁在地板）；成对传送座可跨封闭舱壁实时传箱与传沙 |

*(注：6 大地图共 **36 个 100% 有解关卡** 的具体尺寸、初始资源与每关确定性通关步骤详见 [`docs/design/mode-and-level-design.md`](mode-and-level-design.md) 第 2 节。)*

## 4. 六大风格大尺寸地图全景蓝图（阶段 1.5 观察池 & 阶段 2A 压轴关共用）

阶段 1.5 的 6 张大地图实机预览直接升级为常驻的**「观察池（Observation Pool）」**，并作为阶段 2A 每张地图关卡池的第 6 关（★★★ 压轴大图 `D_06`/`F_06`/`R_06`/`C_06`/`S_06`/`X_06`）：
- **4.1 地牢大图《深层矿井枢纽》**：蓝灰石砖、铁挂灯、防夹千斤闸（门缝倒沙撑住）、矿柱爆破塌方与深井沉沙囊连通器。
- **4.2 森林大图《巨木盘根水殿》**：3px 翠绿草皮、参天古树垂藤、萤火虫灯笼、中央断崖吸水生长 4 格高藤蔓梯与青苔沉水石箱。
- **4.3 遗迹大图《日轮金字塔内殿》**：象形雕花砂岩、圣火盆、顶层巨型流沙计时漏斗与中殿双盘黄金配重天平。
- **4.4 洞穴大图《幽光晶簇与熔脉》**：斜向玄武岩、发光晶簇、亮黄硫磺裂岩、洞顶 `2×2` 钟乳石重锤、左下翠绿强酸间歇泉与右下赤红岩浆化沙槽。
- **4.5 天空岛大图《破晓云海风之圣域》**：破晓霞光、底面 3px 纯白云絮托底、左上定向风场发射器吹偏云沙、中层浮云弹性软垫与天池急冻冰桥。
- **4.6 宇宙大图《深空星站：曲率反应舱》**：深空星云、钛合金铆钉板与顶面 2px 黄黑警示斜纹、红色激光力场门、中央反重力倒挂水柱舱与成对量子传送基座。

## 5. 地形着色器（`world.gdshader`）多风格与新材质扩展规格

升级后的 [`pushbox/scripts/render/world.gdshader`](../../pushbox/scripts/render/world.gdshader) 采用**「1 个 `biome_style_id` + 语义化 Uniform 色板 + 跨像素边界探针」**的数据驱动架构（注意：**严禁在 Shader 代码或注释中写出被 `tests/procedural_art.gd` 禁止的旧采样器名**）：

```glsl
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D palette : filter_nearest;
uniform int biome_style_id = 0; // 0=Dungeon, 1=Forest, 2=Ruins, 3=Cave, 4=SkyIsland, 5=Cosmos

// 材质 ID 绑定
uniform int bedrock_id = 1;
uniform int cracked_id = 2;
uniform int crate_id = 3;
uniform int gate_id = 4;
uniform int sand_id = 5;
uniform int water_id = 6;
uniform int iron_crate_id = -1;
uniform int acid_id = -1;
uniform int lava_id = -1;
uniform int pumice_id = -1;
uniform int ice_id = -1;

// 主题语义色板 Uniform（默认值为 0. 地牢风格，保证未绑定时 100% 兼容现有测试）
uniform vec4 bedrock_base = vec4(0.227451, 0.266667, 0.400000, 1.0);
uniform vec4 bedrock_seam = vec4(0.149020, 0.168627, 0.266667, 1.0);
uniform vec4 bedrock_edge = vec4(0.545098, 0.607843, 0.705882, 1.0);
uniform vec4 bedrock_trim = vec4(0.352941, 0.411765, 0.533333, 1.0);

uniform vec4 cracked_base = vec4(0.760784, 0.521569, 0.411765, 1.0);
uniform vec4 cracked_edge = vec4(0.894118, 0.650980, 0.447059, 1.0);
uniform vec4 cracked_vein = vec4(0.243137, 0.152941, 0.192157, 1.0);
```

## 6. 后续落地分步实施计划（含阶段 1.5、阶段 2A 零改引擎关卡池与阶段 2B）

| 步骤 | 任务名称 | 是否改 C++ 引擎 | 核心交付内容 | 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| **Step 0–2（阶段 1.5）** | **美术目录拆分 + 六大风格大地图观察池预览** | **否** | 建立 `pushbox/scripts/art/` 目录；升级 `world.gdshader`；在大厅接入 6 张大地图实机预览（观察池）。 | 19/19 脚本通过，用户进游戏检视 6 大风格美术效果确认满意。 |
| **Step 3（阶段 2A-1）** | **零改引擎实现 6 大地图常规 + 独特玩法机制** | **否（零 C++ 改动）** | 接入铁箱、强酸、熔岩、浮石、实心冰 JSON 配置，并在 `board.gd` 实现吸水藤梯、流沙漏斗/配重天平、钟乳石重锤/间歇泉、浮云软垫/顺风场、量子传送座/反重力舱。 | 全部 6 大独特机关单元测试与预演/撤销一致性 100% 通过。 |
| **Step 4（阶段 2A-2）** | **落地 36 关有解关卡池 + 观察池 + 满 3 关解锁下一图** | **否（零 C++ 改动）** | 制作 6 大地图 × 每图 6 关 = 36 个关卡 JSON（每关录制 `solution` 并强制验证 `won() == true`），实现“当前图通关满 3 关解锁下一张地图”与观察池自由侦察功能。 | `tests/campaign_stage2a.gd` 验证 36 关 100% 有解通关，T8 帧耗时 `<= 4 ms`，可交付外部试玩。 |
| **Step 5（阶段 2B · 延后）** | **外部试玩反馈后改 C++ 引擎扩底层机制** | **是（改 `ele-base-cpp`）** | 根据外部试玩反馈，按需扩展 `EXT-03`（周期电路）、`EXT-06`（流量传感）、连续气压风场等底层求解器。 | 试玩反馈收集完成后再启动。 |

## 7. 阶段 1.5 确认后，交给开发侧（GPT / Codex）启动「阶段 2A（零改引擎 36 关有解关卡池 + 满 3 关解锁）」的提示词

等你看完阶段 1.5 的 6 张大地图美术效果确认没问题后，直接复制下方提示词发给开发会话，即可在**不改一行 C++ 引擎**的前提下把 6 大地图关卡池全部做出来供人试玩：

```text
阶段 1.5 的六大地图美术效果审核通过！现在请启动「第二阶段 A（零改 C++ 引擎：6 大地图 × 6 关 = 36 关有解关卡池 + 观察池 + 通关 3 关解锁下一地图）」。
注意：本阶段严禁修改或重新编译 ele-base-cpp C++ 引擎（bin/ 动态库保持哈希不变），所有新增机制必须 100% 基于现有 SDK v1.2.0 能力与 GDScript 游戏层确定性规则实现，做完后先供外部玩家试玩。

在开始写代码前，请先按顺序读取以下 3 份文档：
1. docs/v2/status.md（查看当前阶段 1.5 完成基线）
2. docs/archive/plans/2026-10-14-three-modes-and-mechanisms.md（重点看第 3 节：第二阶段 A 详细执行清单 2A.1、2A.2、2A.3）
3. docs/design/mode-and-level-design.md（重点看第 0 节零改引擎实现表、第 1 节「6 关池 + 观察池 + 通关 3 关解锁下一地图」规则与 UI 布局、第 2 节 6 大地图共 36 关完整有解设计表）

请严格按以下 3 个任务顺序执行（全程保持单 worker 顺序执行）：

【任务 2A.1：接入现有 SDK 扩展材质并在游戏层实现 6 大地图独特机关（零改 C++ 引擎）】
1. 在 content/default/materials.json、reactions.json 与 rules.json 中接入沉水铁箱（iron_crate）、强酸（acid）、酸雾（fume）、熔岩（lava）、高密度浮石沙（pumice）与实心冰（ice），保持 D1-D5 与 T01-T04 哈希零回归。
2. 在 board.gd / session.gd / board_view.gd 中用纯确定性游戏层规则实现 6 大地图的独特机关（100% 兼容撤销 Z 与悬停预演 T6）：
   - 地牢（dungeon）：千斤防夹闸（crush_max）+ 矿柱爆破塌方；
   - 森林（forest）：吸水生长藤梯（vine_seeds 接触水后自动向上生成可爬藤梯）；
   - 遗迹（ruins）：流沙计时漏斗（hourglasses）+ 双盘黄金配重天平（scales 左重右升托箱）；
   - 洞穴（cave）：洞顶钟乳石震落重锤（stalactites 炸断支撑后直落砸穿脆岩/筑坝）+ 定量间歇泉（geysers）；
   - 天空岛（sky_island）：冷冻拉杆水冰互转 + 浮云弹性软垫（cloud_pads 木箱可走、铁箱压穿下坠）+ 定向顺风场（wind_zones）；
   - 宇宙（cosmos）：成对量子物质传送座（teleporters TP_A -> TP_B 跨墙传箱/传沙）+ 舱段局部反重力开关（gravity_zones 轻箱与沙吸附舱顶、铁箱锁底）。

【任务 2A.2：实现「6 大地图关卡池 + 观察池 + 通关 3 关解锁下一地图」UI 与存档】
1. 升级主大厅的「闯关模式」二级面板：顶部展示 6 大地图切换栏（1.幽暗石牢 -> 2.迷雾古森 -> 3.黄金神庙 -> 4.幽光晶窟 -> 5.云端圣域 -> 6.深空星站），每张地图拥有独立的 6 关关卡池（2 关★入门、2 关★★进阶、2 关★★★精通大图）。
2. 解锁规则：初始解锁地图 1（幽暗石牢）；每张地图内默认开放前 2 关，每通关 1 关多开放池内后 2 关；只要在当前地图的 6 关池中【累计通关满 3 关】，立即自动解锁下一张风格地图！（满 3/6 点亮通行银章，满 6/6 点亮全清金冠）。
3. 融合「观察池（Observation Pool）」：在地图池界面支持按 Tab 或点击「观察池」按钮进入全景侦察视口，自由浏览该地图各关卡的完整地形与机关布局。

【任务 2A.3：落地 6 大地图 × 6 关 = 36 关完整关卡池并执行 100% 有解硬性门禁】
1. 按 docs/design/mode-and-level-design.md 第 2.1–2.6 节规格，创建全部 36 个关卡 JSON（D_01..06、F_01..06、R_01..06、C_01..06、S_01..06、X_01..06）。
2. 【100% 有解死命令】：严禁出现任何无解地图！全部 36 个关卡 JSON 必须录制完整的作者解法 solution、solution_hashes 与 solution_keys。
3. 编写并跑通 tests/campaign_stage2a.gd 与全量 python3 tools/run_tests.py --performance：逐关自动回放全部 36 关的 solution，强制断言 36/36 关全部 session.board.won() == true、撤销重做 T5 一致、预演 T6 一致、满 3 关解锁下一地图流转正确、且 T8 帧耗时 <= 4ms。完成后更新 docs/v2/status.md 并导出各图代表关卡截图。
```
