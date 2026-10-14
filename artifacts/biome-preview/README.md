# 阶段 1.5 六大风格地图实机预览

日期：2026-10-14（Asia/Shanghai）。基线还原点：`feaa6ba`，提交信息 `Stage 1 baseline complete: seal accepted code and cleanup`。

双击仓库 `Run Demo.command` → 大厅 **地图风格预览 · B**（也可直接按 B）→ 左右方向键、箭头按钮或底部主题标签切换。Esc / 左上「返回大厅」退出。

展示器直接使用游戏的 `world.gdshader` 渲染 SDK 格式的材质编码纹理，搭配按需生成的背景与主题精灵。六图为视觉展示数据；新机关的物理结算属于第二阶段。蓝图中的多字符标签已移至独立摆件坐标，地形按规定格数补齐；六个区域、水路、平台与专属机关构图保留。

| 风格 | 大图格数 | 原生 640×360 | 1920×1080（整数 ×3） |
| --- | --- | --- | --- |
| 地牢 · 深层矿井枢纽 | 24×13 | [原生](captures/dungeon-native.png) | [放大](captures/dungeon-1920x1080.png) |
| 森林 · 巨木盘根水殿 | 28×15 | [原生](captures/forest-native.png) | [放大](captures/forest-1920x1080.png) |
| 遗迹 · 日轮金字塔内殿 | 28×15 | [原生](captures/ruins-native.png) | [放大](captures/ruins-1920x1080.png) |
| 洞穴 · 幽光晶簇与地下熔脉 | 30×16 | [原生](captures/cave-native.png) | [放大](captures/cave-1920x1080.png) |
| 天空岛 · 破晓云海与风之圣域 | 30×16 | [原生](captures/sky_island-native.png) | [放大](captures/sky_island-1920x1080.png) |
| 宇宙 · 深空星站：曲率反应舱 | 32×18 | [原生](captures/cosmos-native.png) | [放大](captures/cosmos-1920x1080.png) |

截图从真实 macOS Godot 视口读取；原生 RGBA 指纹与画布规格见 [截图清单](captures/manifest.json)。六图均已逐张视觉检查。字体缺字箭头改为像素三角形，天空背景使用单向破晓色带，宇宙背景降低桁架密度，箱体增加主题专属标识。

验证过程：模块 167 项检查通过；六图、材质与闸门探针 346 项检查通过。覆盖 68 张原图的字节/引用恒等、主题缓存及回退、小房间背景裁剪、完整草皮/云底/警示边、各材质着色和透明占位、四格机械门、能量门固定基座、键鼠切图及直接 `select_level()` 恢复布局。

冻结核对：[43 项运行/规则/关卡/原测试指纹](frozen-files.json) 均与封存提交一致。失败与修正过程保留在 `logs/`：首轮封存前 T8 超限、透明像素隐藏 RGB 差异、测试 ShaderMaterial 复制参数差异，以及未打开预览时提前编译 Shader 的 headless 错误；均不计为通过证据。预览材质现为进入时按需创建。

**最终验证：20/20 脚本零失败。** D1–D5 T8：533 样本峰值 2.387 ms，8 次显示预演峰值 38.763 ms；教学 T8：600 样本峰值 2.694 ms，5 次显示预演峰值 51.401 ms。均满足 4 ms / 100 ms。证据见 [verification.json](verification.json)、[全量摘要](logs/final/test-summary.json) 与 [完整日志](logs/final/console.log)。大厅入口另有 [原生截图](captures/lobby-entry-native.png) 和 [1920×1080 截图](captures/lobby-entry-1920x1080.png)（整数 ×6）。14 张图的每个放大像素已核对，见 [截图验证](capture-verification.json)。

当前为阶段 1.5 技术候选，技术测试与本会话代码复核通过；完整目录和源码指纹见 [source-hashes.json](source-hashes.json)。用户美术验收待进行，第二阶段玩法未启动，候选已本地提交封存，未推送或正式发布。

下一步由用户进入游戏检视六图，在本聊天回复 `阶段 1.5 美术通过。` 或 `阶段 1.5 请修改：……。`。本 Codex 完成最终验证与状态记录后停止，收到美术意见后再处理；第二阶段开发需后续明确授权。
