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
| `js/state.js` | 当前选择、播放时钟、倍率与分类名称 |
| `js/gallery.js` | 资源计数、搜索过滤、素材卡片与空结果状态 |
| `js/renderers.js` | 像素矩阵、动态场景与游戏 UI 的 Canvas 绘制 |
| `js/inspector.js` | 素材详情、帧选择、像素编辑、数据生成与复制 |
| `js/controls.js` | 分类、场景、预览底色、倍率与播放状态切换 |
| `js/app.js` | 页面事件绑定、启动流程与动画调度 |

## 加载与维护

使用按顺序加载的普通脚本，沿用原页面的共享顶层状态；不使用 ES module、异步脚本或 `fetch` 读取数据，以兼容本地文件打开。加载顺序由 `index.html` 统一维护：主题在 `<head>` 中先应用，其余脚本在页面结构之后按「布局、数据、状态、画廊、绘制、检视器、控制、入口」加载。

静态控件通过 `id` / `data-*` 标记，由 `app.js` 绑定事件；动态卡片、色板和帧按钮由对应视图文件绑定。HTML 不放行内事件或样式。Canvas 的动态尺寸和像素色板颜色仍由 JavaScript 设置。

从项目根目录运行验证：

```sh
node --test --test-concurrency=1 tests/art_lab_appearance.test.cjs
```

测试覆盖主题、检视器、复制反馈、外部资源引用和完整脚本加载 / 启动；其中 DOM / Canvas 使用轻量适配器，不能替代浏览器视觉验收。
