# 界面风格定稿（2026-10-16）

用户在对话中确认（原话）：「全部都通过」。本文件是界面线 UI-05 的设计依据，取代 UI-01 报告里 A/B/C 三个方向（UI-02–04 的比较台未做，改为在对话里直接出视觉提案）。效果图是 Python 生成的提案图，**不是已确认的美术资产**；正式资产仍按 UI-05 在工作台里做，再走 `node tools/art.mjs approve`。

## 1 四套风格

| 编号 | 名称 | 造型 |
|---|---|---|
| S1 | 晶石琉璃 | 切面玻璃框、冷青光边、紫晶角饰 |
| S2 | 漂浮符文 | 悬浮石板、琥珀符文光、无外框 |
| S3 | 祥云玉简 | 玉石面板、金回纹、漆匾标题、朱红流苏 |
| S4 | 梦泡糖霜 | 珠光泡泡、贴纸描边、泡泡里漂着万物 |

总览：[lobby/overview.png](ui-style/lobby/overview.png)；每套一张：`ui-style/lobby/S<n>_<名称>.png`。

## 2 大厅：每张地图一套皮肤

大厅布局、按钮顺序、操作只做一套，按当前地图换皮肤（面板、按钮两态、标题字效、当前条、金币条、按键条、光标、2–3 个小装饰、配色）。

| 地图 | 皮肤 |
|---|---|
| 第 1 章 幽暗石牢（dungeon） | S2 漂浮符文 |
| 第 2 章 黄金神庙（ruins） | S3 祥云玉简 |
| 第 3 章（cave） | S1 晶石琉璃 |
| 第 4 章 迷雾古森（forest） | S5 藤木萤光（只用于大厅） |
| 第 5 章（sky） | S4 梦泡糖霜 |
| 第 6 章 深空星站（cosmos） | S6 星港舱板（只用于大厅） |

对应图：[lobby/mapping.png](ui-style/lobby/mapping.png)。

S5、S6 只有大厅皮肤，不进设置里的「界面风格」（那里仍是 S1–S4 四套）：
- S5 藤木萤光：钉子木板 + 草皮苔边、土块字标题（字顶长草）、年轮木墩托徽章、叶片光标；装饰是垂藤、红蘑菇、萤火虫。
- S6 星港舱板：铆钉舱板 + 黄黑警示条、站牌点阵灯标题、舷窗托徽章、火箭光标、紫色选中条；装饰是金环小行星、红色信号灯、星光。

效果图：[lobby/S5_forest.png](ui-style/lobby/S5_forest.png)、[lobby/S6_cosmos.png](ui-style/lobby/S6_cosmos.png)（2 倍），320×180 原尺寸图是同名的 `.native.png`。

## 3 固定界面：默认 S1 晶石琉璃 · 素版

除大厅外的界面不随地图换，默认用 S1 的素版（不带漂浮碎晶和晶簇）。玩家可在 设置 → 界面风格 里换成另外三套。**目前只画了 S1 素版；另外三套的固定界面组件还没画，是后续工作。**

| 图 | 界面 |
|---|---|
| [fixed/sheet_A.png](ui-style/fixed/sheet_A.png) | A 大厅二级：A1 选择章节、A2 选关、A3 设置（新增「界面风格」） |
| [fixed/sheet_B.png](ui-style/fixed/sheet_B.png) | B 关卡内：B1 暂停、B2 提示、B3 规则卡、B4 对话、B5 过关，以及新的分块关卡 HUD |
| [fixed/sheet_C.png](ui-style/fixed/sheet_C.png) | C 渡口 · 配送：C1 今天送什么？、C2 商店、C3 配送 HUD、C4 配送暂停、C5 结算、C6 失败、C7 确认框（建议新增） |

每个界面的 320×180 原尺寸图：`ui-style/fixed/<界面>.native.png`。

要点：
- 暂停菜单常用项旁标快捷键（Esc / H / R）；配送暂停用同一套画法。
- 提示由主角气泡说出，挂「提示 n/3」；底栏是层数 + 演示 / 回到正确位置。
- 对话三种样式：NPC 说话泡（青）、主角心里话（思考泡）、系统提示条（紫）。
- 选关预览用真实关卡截图 + 一句话发现；过关画面用门的打开帧（`mech.door` 第 4 帧）。
- 商店买不起的价格标红、卖完整行变暗；结算右上评级徽章、账单式明细、合计放大；失败标题用粉色。
- HUD：沙袋为 0 时用压暗的沙袋图标 + 灰色「×0」。

## 4 新文字（写进 `content/i18n-ui/`，不改冻结的文字表）

- 设置：「界面风格」，选项「晶石琉璃 / 漂浮符文 / 祥云玉简 / 梦泡糖霜」，说明「大厅随地图换风格，」「其他界面用这一套。」
- C7 确认框（文案待定）：「放弃这一单？」「路上拾到的金币只带回一半。」「放弃」「再想想」（默认选中「再想想」）。

其余文字都来自现有 `content/i18n/`、`content/i18n-delivery/`。

## 5 还没做的

- S2–S4 的固定界面组件。
- 渡口设施（工坊、徽章柜等）的界面没有设计。
- 英文版没有出图。

## 6 重新生成效果图

代码在 `tools/ui-proposals/`（Python 3 + Pillow，读仓库里的 `art/source`、`art/export/reference` 和 `third_party/fonts`，输出到该目录下的 `out2/`、`fixed/out/`，不写别处）：

```sh
cd tools/ui-proposals && python3 make2.py                 # 大厅四套（out2/）
python3 make3.py                                          # 第 4、6 章大厅皮肤 S5、S6 和 mapping.png（out2/）
cd fixed && python3 screens_a.py && python3 screens_b.py && python3 screens_c.py && python3 make.py   # 固定界面（fixed/out/）
```
