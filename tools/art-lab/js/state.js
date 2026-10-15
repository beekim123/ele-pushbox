let currentCategory = "all";
let currentBiomeFilter = "all";
let stageBgClass = "bg-checker";
let globalScale = 4;
let isPlaying = true;
let clock = 0.0;
let lastTime = performance.now();
let selectedAsset = ASSET_CATALOG[5]; // 默认选中红胸知更鸟
let selectedFrameIdx = 0;
let activePaintCode = "i";

const CATEGORY_TITLES = {
  all: ["全部素材", "素材、场景与界面预演"],
  character: ["角色", "矿工的待机、行走、挖掘与攀爬动作"],
  monster: ["动物与怪物", "环境生物与挑战角色"],
  prop: ["道具与箱体", "主题木箱、铁箱与随身道具"],
  plant_mech: ["植物与机关", "场景植物、动态灯饰与主题机关"],
  terrain: ["地形与流体", "地表、岩层与材质样本"],
  ui: ["界面与图标", "320 × 180 界面布局与操作引导"],
  map: ["地图全景", "六个场景主题的动态组合预演"]
};
const BIOME_NAMES = {
  all: "全主题通用", dungeon: "幽暗石牢", forest: "迷雾古森", ruins: "黄金神庙",
  cave: "幽光晶窟", sky_island: "云端圣域", cosmos: "深空星站"
};
