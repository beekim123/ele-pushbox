# Art Lab

入口为 `index.html`。CSS 和 JavaScript 使用相对路径加载，保留直接双击打开的方式，无需安装依赖或运行构建命令。移动或分发时请携带整个 `art-lab` 目录。

## 文件职责

| 文件 | 内容 |
| --- | --- |
| `index.html` | 页面结构、可访问性标记与资源加载顺序 |
| `styles.css` | 排版、明暗主题、响应式布局与静态配色 |
| `js/appearance.js` | 网页外观、系统跟随与偏好存储 |
| `js/workspace.js` | 窄屏检视器、焦点管理与关闭操作 |
| `js/data/palette.js` | 像素调色板与确定性哈希 |
| `js/data/assets.js` | 素材矩阵、元数据与还原备份 |
| `js/data/biomes.js` | 地图布局与场景主题配色 |
| `js/data/campaign.js` | 真实六主题 / 36 关的 ID 和名称 |
| `js/state.js` | 当前选择、播放时钟、倍率与分类名称 |
| `js/gallery.js` | 资源计数、搜索过滤、素材卡片与空结果状态 |
| `js/renderers.js` | 像素矩阵与原有动态地图绘制 |
| `js/inspector.js` | 素材详情、帧选择、像素编辑、数据生成与复制 |
| `js/controls.js` | 分类、场景、预览底色、倍率与播放状态切换 |
| `js/app.js` | 页面事件绑定、启动流程与动画调度 |
| `js/ui/state.js` | 营地预演状态、解锁样例、命中区域和键盘操作 |
| `js/ui/draw.js` | 整数像素图元和点阵文字 |
| `js/ui/scenery.js` | 六主题分层背景、入口建筑与生态 |
| `js/ui/screens.js` | 矿井营地大厅与路线选关 |
| `js/ui/viewer.js` | 放大预演、输入适配、数据导出与绘制缓存 |
| `js/ui/showcase.js` | 首屏改稿展示、素材图鉴切换与挖掘动作预览 |
| `js/ui/font.js` | 项目像素字体生成的字形子集 |

## 加载与维护

使用按顺序加载的普通脚本，沿用原页面的共享顶层状态；不使用 ES module、异步脚本或 `fetch` 读取数据，以兼容本地文件打开。加载顺序由 `index.html` 统一维护：主题在 `<head>` 中先应用，其余脚本在页面结构之后按「布局、数据、状态、画廊、绘制、检视器、控制、入口」加载。

静态控件通过 `id` / `data-*` 标记，由 `app.js` 绑定事件；动态卡片、色板和帧按钮由对应视图文件绑定。HTML 不放行内事件或样式。Canvas 的动态尺寸和像素色板颜色仍由 JavaScript 设置。

从项目根目录运行验证：

```sh
node --test --test-concurrency=1 tests/art_lab_appearance.test.cjs tests/art_lab_camp_ui.test.cjs
```

测试覆盖主题、检视器、复制反馈、外部资源引用和完整脚本加载 / 启动；其中 DOM / Canvas 使用轻量适配器，不能替代浏览器视觉验收。


## 营地界面

打开 `index.html` 默认进入「本次改稿」：大厅、路线选关、矿工挖掘循环与三帧拆解直接显示。主题与进度样例同时控制两张界面；点击画面进入放大交互预演。顶部「素材图鉴」保留全部42项资源，搜索也会自动切到图鉴；挖掘动作旁的入口可直接进入像素检视器。两视图只绘制当前可见内容。

图鉴里也可以选中 `ui_lobby_screen` 或 `ui_campaign_screen` 后点击「放大交互预演」。支持鼠标选择入口 / 路牌、方向键选择、回车确认、PageUp / PageDown 换主题、Esc 返回。进度使用独立样例；「进入」只返回选择结果，不启动 Godot、不修改游戏存档。

文字以项目内 Fusion Pixel 12px 字体生成点阵字形，浏览器无需加载外部字体。原字体及其组件许可证保留在 `licenses/font/`。修改界面文案或关卡名称后，可在项目根目录执行以下开发工具（构建字形需要 Pillow，浏览器运行不需要 Python 或 Node）：

```sh
python3 tools/art-lab/scripts/build-ui-data.py
node tools/art-lab/scripts/render-camp-preview.cjs
```

渲染器直接还原 Canvas 的整数矩形，生成六主题、进度状态和动画帧到 `artifacts/art-lab-ui-camp/`。这些图是源码渲染证据，不是浏览器 / Godot 截图。界面绘制以 8 FPS 缓存，选择变化、精灵像素修改或还原会立即失效缓存；不会持续以 60 FPS 重画静态 UI。
