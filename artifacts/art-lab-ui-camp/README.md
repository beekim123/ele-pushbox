# 矿井营地 UI 候选

对应用户选择的「矿井营地」完整方案：大厅三个场景入口；选关为六主题路线木牌。当前仅接入 Art Lab，未同步 Godot，尚未用户视觉验收或正式入库。

- `forest-lobby.gif` / `forest-campaign.gif`：森林主展示，640×360 整数×2，平均8 FPS。
- `forest-*-animated.png`：每帧精确125 ms 的 APNG。
- `forest-*-4x.png`：1280×720 整数×4检视图。
- `six-themes.png`：六主题、两页面总览。
- `*-native.png`：320×180源码渲染原图，另含初始 / 中期 / 全通进度样例。
- `manifest.json`：12个主题视图的RGB像素SHA-256、绘制输入指纹与进度图索引。
- `verification.json`：本轮脚本与证据核验边界。

上述图由相同的整数Canvas矩形绘制代码直接还原，文字也使用项目字体生成的点阵；它们不是浏览器或Godot实机截图。导出PNG的纯像素路径与UI绘制一致，未运行浏览器截图或绕过本地页面访问限制。

从项目根目录重新生成原图：

```sh
node tools/art-lab/scripts/render-camp-preview.cjs
```

检查范围为 Art Lab 的独立进度样例、交互、导出、字形、配色和像素输出。29项脚本检查通过、3项代码评审问题修复复核通过，不代表游戏全量或T8性能门禁通过。
