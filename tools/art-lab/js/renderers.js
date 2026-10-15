function drawMatrixOnCtx(ctx, rows, x0, y0, scale = 1, flipH = false) {
  if (!rows) return;
  const h = rows.length, w = rows[0].length;
  for (let y = 0; y < h; y++) {
    const r = rows[y];
    for (let x = 0; x < w; x++) {
      const ch = r[flipH ? (w - 1 - x) : x];
      if (ch && ch !== "." && ch !== " ") {
        ctx.fillStyle = PALETTE[ch] || "#ffffff";
        ctx.fillRect(x0 + x * scale, y0 + y * scale, scale, scale);
      }
    }
  }
}

function getSpriteFrames(id) {
  const found = ASSET_CATALOG.find(a => a.id === id);
  return found ? found.frames : null;
}

// 绘制 320x180 动态生态大地图 (含三层视差飘云、丁达尔光、花草摇曳、小鸟彩蝶飞蛾圣甲虫无人机)
function renderLiveMapToCtx(ctx, biomeIdx, t) {
  const map = BIOME_MAPS[biomeIdx];
  const cols = map[0].length, rows = map.length;
  const c = BIOME_COLORS[biomeIdx];

  // 1) 去 AI 味背景与动态天气
  if (biomeIdx === 1) {
    // 迷雾古森：深林底色 + 圆弧远景树冠 + 丁达尔斜射光束 + 分叉古树与摆动青藤 + 落叶
    ctx.fillStyle = PALETTE["p"]; ctx.fillRect(0, 0, 320, 180);
    for (let x = -10; x < 320; x += 52) {
      ctx.fillStyle = PALETTE["o"];
      ctx.fillRect(x + 16, 18, 14, 162);
      ctx.fillRect(x, 8, 44, 16);
      ctx.fillRect(x + 6, 2, 32, 8);
    }
    // 丁达尔斜射光束
    ctx.fillStyle = "rgba(99, 199, 77, 0.14)";
    for (let b = 0; b < 3; b++) {
      const bx = 40 + b * 100 + Math.sin(t * 0.7 + b) * 4;
      ctx.beginPath();
      ctx.moveTo(bx, 0); ctx.lineTo(bx + 18, 0);
      ctx.lineTo(bx + 72, 180); ctx.lineTo(bx + 50, 180);
      ctx.fill();
    }
    // 近景古树干与随风摇摆垂藤
    for (let x = 24; x < 320; x += 92) {
      ctx.fillStyle = PALETTE["g"]; ctx.fillRect(x, 0, 16, 180);
      ctx.fillStyle = PALETTE["f"]; ctx.fillRect(x + 3, 0, 5, 180);
      for (let vy = 0; vy < 36; vy += 2) {
        const sway = Math.round(Math.sin(t * 2.2 + vy * 0.15 + x) * 1.5);
        ctx.fillStyle = PALETTE["m"];
        ctx.fillRect(x + 38 + sway, vy, 2, 2);
      }
    }
    // 飘落绿叶与金色花粉
    for (let i = 0; i < 12; i++) {
      const lx = ((i * 37 + t * 10 + Math.sin(t * 2 + i) * 5) % 320) | 0;
      const ly = ((i * 23 + t * 8) % 180) | 0;
      ctx.fillStyle = (i % 3 === 0) ? PALETTE["l"] : PALETTE["m"];
      ctx.fillRect(lx, ly, 2, 1);
    }
  } else if (biomeIdx === 4) {
    // 云端圣域：破晓霞光 + 远/中/近三层视差连续飘动白云 + 远景飞鸟群
    const bands = ["x", "B", "C", "D", "E"];
    for (let b = 0; b < 5; b++) {
      ctx.fillStyle = PALETTE[bands[b]];
      ctx.fillRect(0, b * 36, 320, 36);
      if (b < 4) {
        ctx.fillStyle = PALETTE[bands[b + 1]];
        for (let y = b * 36 + 32; y < (b + 1) * 36; y += 2) {
          for (let x = (y & 2); x < 320; x += 4) ctx.fillRect(x, y, 2, 2);
        }
      }
    }
    const drawCloud = (cx, cy, w, h, topCol, botCol) => {
      ctx.fillStyle = botCol; ctx.fillRect(cx + 2, cy + h - 3, w - 4, 3);
      ctx.fillStyle = topCol;
      ctx.fillRect(cx, cy + 4, w, h - 6);
      ctx.fillRect(cx + 4, cy + 1, (w * 0.3) | 0, 4);
      ctx.fillRect(cx + ((w * 0.28) | 0), cy - 1, (w * 0.4) | 0, 6);
      ctx.fillRect(cx + ((w * 0.62) | 0), cy + 2, (w * 0.26) | 0, 3);
    };
    // 远、中、近三层视差飘动白云
    for (let i = 0; i < 5; i++) drawCloud(((i * 74 + t * 4) % 380) - 40, 132 + (i & 1) * 8, 48, 12, PALETTE["u"], PALETTE["v"]);
    for (let i = 0; i < 4; i++) drawCloud(((i * 92 + 20 + t * 9) % 390) - 45, 72 + (i % 3) * 16, 42, 11, PALETTE["t"], PALETTE["u"]);
    for (let i = 0; i < 4; i++) drawCloud(((i * 96 + t * 16) % 400) - 50, 154 + (i & 1) * 6, 60, 15, PALETTE["t"], PALETTE["u"]);
  } else if (biomeIdx === 2) {
    // 黄金神庙：砂岩立柱 + 顶棚持续漏沙细流
    ctx.fillStyle = PALETTE["g"]; ctx.fillRect(0, 0, 320, 180);
    for (let x = 28; x < 320; x += 84) {
      ctx.fillStyle = PALETTE["f"]; ctx.fillRect(x, 0, 16, 180);
      ctx.fillStyle = PALETTE["e"]; ctx.fillRect(x + 3, 0, 4, 180);
    }
    // 持续动态漏下的金沙流
    for (const sx of [80, 216]) {
      for (let y = 16; y < 156; y += 3) {
        ctx.fillStyle = ((y + Math.floor(t * 20)) & 1) ? PALETTE["l"] : PALETTE["k"];
        ctx.fillRect(sx, y + (Math.floor(t * 24) % 3), 1, 2);
      }
    }
  } else if (biomeIdx === 3) {
    // 幽光晶窟：起伏溶洞 + 滴酸动画
    ctx.fillStyle = PALETTE["z"]; ctx.fillRect(0, 0, 320, 180);
    for (let x = 16; x < 310; x += 40) {
      const len = 16 + (x % 18);
      ctx.fillStyle = PALETTE["p"]; ctx.fillRect(x, 0, 8, len);
      const dy = len + ((t * 36 + x) % 120);
      ctx.fillStyle = PALETTE["m"]; ctx.fillRect(x + 3, dy, 2, 3);
    }
  } else if (biomeIdx === 5) {
    // 深空星站：闪烁星空 + 紫蓝星云
    ctx.fillStyle = PALETTE["z"]; ctx.fillRect(0, 0, 320, 180);
    for (let i = 0; i < 40; i++) {
      const sx = h32(i, 1, 9) % 320, sy = h32(i, 2, 9) % 180;
      ctx.fillStyle = ((Math.floor(t * 3 + i) % 3) === 0) ? PALETTE["t"] : PALETTE["s"];
      ctx.fillRect(sx, sy, 1, 1);
    }
  } else {
    ctx.fillStyle = PALETTE["z"]; ctx.fillRect(0, 0, 320, 180);
    for (let y = 0; y < 180; y += 16) {
      const off = ((y / 16) & 1) ? 16 : 0;
      for (let x = 0; x < 320; x += 32) {
        ctx.fillStyle = PALETTE["y"]; ctx.fillRect(x + off + 1, y + 1, 30, 14);
      }
    }
  }

  // 2) 绘制地形与动态花草/小动物
  const ox = ((20 - cols) >> 1) * 16, oy = ((11 - rows) >> 1) * 16 + 2;
  for (let ty = 0; ty < rows; ty++) {
    for (let tx = 0; tx < cols; tx++) {
      const ch = map[ty][tx];
      if (ch === ".") continue;
      const x0 = ox + tx * 16, y0 = oy + ty * 16;
      const topOpen = ty > 0 && ".waABIT~V".includes(map[ty - 1][tx]);
      const botOpen = ty < rows - 1 && map[ty + 1][tx] === ".";

      if (ch === "#") {
        ctx.fillStyle = PALETTE[c.base]; ctx.fillRect(x0, y0, 16, 16);
        ctx.fillStyle = PALETTE[c.seam]; ctx.fillRect(x0, y0, 16, 1); ctx.fillRect(x0, y0, 1, 16);
        if (biomeIdx === 1 && topOpen) {
          ctx.fillStyle = PALETTE["m"]; ctx.fillRect(x0, y0, 16, 2);
          ctx.fillStyle = PALETTE["n"]; ctx.fillRect(x0, y0 + 2, 16, 2);
        } else if (biomeIdx === 4) {
          if (topOpen) { ctx.fillStyle = PALETTE["t"]; ctx.fillRect(x0, y0, 16, 2); }
          ctx.fillStyle = PALETTE["k"]; ctx.fillRect(x0, y0 + 2, 16, 1);
          if (botOpen) { ctx.fillStyle = PALETTE["t"]; ctx.fillRect(x0 + 1, y0 + 13, 14, 3); }
        } else if (biomeIdx === 5 && topOpen) {
          for (let px = 0; px < 16; px += 4) {
            ctx.fillStyle = PALETTE["l"]; ctx.fillRect(x0 + px, y0, 2, 2);
            ctx.fillStyle = PALETTE["z"]; ctx.fillRect(x0 + px + 2, y0, 2, 2);
          }
        } else if (topOpen) {
          ctx.fillStyle = PALETTE[c.edge]; ctx.fillRect(x0, y0, 16, 2);
        }

        // 在裸露地表绘制动态野花与小动物！
        if (topOpen && (tx + ty) % 2 === 0) {
          if (biomeIdx === 1) {
            const flFrames = getSpriteFrames("flower_sway");
            drawMatrixOnCtx(ctx, flFrames[Math.floor(t * 2.5 + tx) % flFrames.length], x0 + 4, y0 - 6, 1);
            if (tx % 3 === 0) {
              const bFrames = getSpriteFrames("forest_bird");
              const fIdx = Math.floor(t * 3 + tx) % bFrames.length;
              drawMatrixOnCtx(ctx, bFrames[fIdx], x0 + 3, y0 - 8 + (fIdx === 2 ? -2 : 0), 1, (tx & 1) === 0);
              const bfFrames = getSpriteFrames("forest_butterfly");
              drawMatrixOnCtx(ctx, bfFrames[Math.floor(t * 8) % 2], x0 + 4 + Math.sin(t * 2.5 + tx) * 8, y0 - 16 + Math.cos(t * 4 + tx) * 4, 1);
            }
          } else if (biomeIdx === 4) {
            if (tx === 4) {
              const pw = getSpriteFrames("wind_pinwheel");
              drawMatrixOnCtx(ctx, pw[Math.floor(t * 6) % 2], x0, y0 - 16, 1);
            } else if (tx % 3 === 0) {
              const dv = getSpriteFrames("sky_dove");
              drawMatrixOnCtx(ctx, dv[Math.floor(t * 3 + tx) % 2], x0 + 3, y0 - 7, 1);
            } else {
              const cs = getSpriteFrames("cloud_sprite");
              drawMatrixOnCtx(ctx, cs[Math.floor(t * 4 + tx) % 2], x0 + 3, y0 - 7, 1);
            }
          } else if (biomeIdx === 2 && tx % 3 === 0) {
            const sc = getSpriteFrames("ruins_scarab");
            drawMatrixOnCtx(ctx, sc[Math.floor(t * 6) % 2], x0 + 3 + Math.sin(t * 1.5 + tx) * 3, y0 - 5, 1);
          } else if (biomeIdx === 3 && tx % 3 === 0) {
            const cm = getSpriteFrames("cave_moth");
            drawMatrixOnCtx(ctx, cm[Math.floor(t * 8) % 2], x0 + 4 + Math.cos(t * 3 + tx) * 6, y0 - 14 + Math.sin(t * 4 + tx) * 3, 1);
          } else if (biomeIdx === 5 && tx % 4 === 0) {
            const dr = getSpriteFrames("cosmos_drone");
            drawMatrixOnCtx(ctx, dr[Math.floor(t * 6) % 2], x0 + 3, y0 - 18 + Math.sin(t * 3 + tx) * 3, 1);
          }
        }
      } else if (ch === "c") {
        ctx.fillStyle = PALETTE[c.crack]; ctx.fillRect(x0, y0, 16, 16);
        ctx.fillStyle = PALETTE[c.vein]; ctx.fillRect(x0 + 7, y0 + 2, 2, 12);
      } else if (ch === "s") {
        ctx.fillStyle = PALETTE[c.sand]; ctx.fillRect(x0, y0, 16, 16);
      } else if (ch === "w") {
        ctx.fillStyle = PALETTE[c.water]; ctx.fillRect(x0, y0, 16, 16);
        if (topOpen) { ctx.fillStyle = PALETTE["s"]; ctx.fillRect(x0, y0, 16, 2); }
      } else if (ch === "a") {
        ctx.fillStyle = PALETTE["n"]; ctx.fillRect(x0, y0, 16, 16);
        ctx.fillStyle = PALETTE["l"]; ctx.fillRect(x0, y0, 16, 2);
      } else if (ch === "m") {
        ctx.fillStyle = PALETTE["i"]; ctx.fillRect(x0, y0, 16, 16);
        ctx.fillStyle = PALETTE["l"]; ctx.fillRect(x0, y0, 16, 2);
      } else if (ch === "i") {
        ctx.fillStyle = PALETTE["s"]; ctx.fillRect(x0, y0, 16, 16);
        ctx.fillStyle = PALETTE["t"]; ctx.fillRect(x0, y0, 16, 2);
      } else if (ch === "~") {
        const cp = getSpriteFrames("cloud_pad");
        drawMatrixOnCtx(ctx, cp[Math.floor(t * 3) % 2], x0, y0, 1);
      } else if (ch === "V") {
        const vl = getSpriteFrames("vine_ladder");
        drawMatrixOnCtx(ctx, vl[Math.floor(t * 3) % 2], x0, y0, 1);
      } else if (ch === "A" || ch === "B") {
        const cr = getSpriteFrames(biomeIdx === 1 ? "crate_wood_forest" : (biomeIdx === 2 ? "crate_wood_ruins" : "crate_wood_dungeon"));
        drawMatrixOnCtx(ctx, cr[0], x0, y0, 1);
      } else if (ch === "I") {
        drawMatrixOnCtx(ctx, getSpriteFrames("crate_iron_all")[0], x0, y0, 1);
      } else if (ch === "T") {
        drawMatrixOnCtx(ctx, getSpriteFrames("target_lit_0") ? getSpriteFrames("target_lit_0")[0] : ASSET_CATALOG[0].frames[0], x0, y0, 1);
      }
    }
  }
  drawMatrixOnCtx(ctx, getSpriteFrames("miner_idle")[Math.floor(t * 2) % 2], ox + 48, oy + 48, 1);
}

// 绘制美化版 320x180 UI 页面卡片
function renderUIPreviewToCtx(ctx, type, t) {
  renderLiveMapToCtx(ctx, 1, t);
  ctx.fillStyle = "rgba(24, 20, 37, 0.55)";
  ctx.fillRect(0, 0, 320, 180);

  const box = (x, y, w, h, hl = "#8b9bb4") => {
    ctx.fillStyle = "rgba(38, 43, 68, 0.92)";
    ctx.fillRect(x, y, w, h);
    ctx.strokeStyle = hl;
    ctx.lineWidth = 1;
    ctx.strokeRect(x + 0.5, y + 0.5, w - 1, h - 1);
  };

  ctx.font = "bold 10px 'PingFang SC', monospace";
  ctx.textBaseline = "top";
  if (type === "ui_lobby") {
    ctx.fillStyle = "#fee761";
    ctx.fillText("推 箱 子 ： 沙 与 水", 108, 16);
    const titles = ["教学模式", "闯关模式", "挑战模式"];
    for (let i = 0; i < 3; i++) {
      box(16 + i * 100, 44, 88, 92, i === 1 ? "#fee761" : "#5a6988");
      ctx.fillStyle = i === 1 ? "#fee761" : "#ffffff";
      ctx.fillText(titles[i], 38 + i * 100, 54);
      drawMatrixOnCtx(ctx, getSpriteFrames("miner_idle")[0], 42 + i * 100, 74, 1);
      drawMatrixOnCtx(ctx, getSpriteFrames("forest_bird")[Math.floor(t * 3) % 3], 62 + i * 100, 80, 1);
    }
  } else {
    // 闯关模式选关页
    ctx.fillStyle = "#fee761";
    ctx.fillText("✦ 迷雾古森 · 关卡池 (已通 3/6 ★已解锁下一图)", 46, 6);
    for (let m = 0; m < 6; m++) {
      box(14 + m * 50, 22, 42, 18, m === 1 ? "#fee761" : "#5a6988");
      ctx.fillStyle = m === 1 ? "#fee761" : "#c0cbdc";
      ctx.fillText(["石牢","古森","神庙","晶窟","天空","星站"][m], 25 + m * 50, 26);
    }
    box(12, 46, 108, 110, "#63c74d");
    ctx.fillStyle = "#63c74d";
    ctx.fillText("动态微缩实景窗", 28, 52);
    drawMatrixOnCtx(ctx, getSpriteFrames("forest_bird")[Math.floor(t * 4) % 3], 42, 86, 2);
    drawMatrixOnCtx(ctx, getSpriteFrames("forest_butterfly")[Math.floor(t * 8) % 2], 74, 76, 2);
    for (let idx = 0; idx < 6; idx++) {
      const col = idx % 2, row = (idx / 2) | 0;
      const cx = 128 + col * 92, cy = 46 + row * 37;
      box(cx, cy, 86, 32, idx === 1 ? "#fee761" : "#5a6988");
      ctx.fillStyle = "#ffffff";
      ctx.fillText("0" + (idx + 1) + " 森林关卡", cx + 6, cy + 5);
      ctx.fillStyle = "#feae34";
      ctx.fillText("★".repeat((idx >> 1) + 1), cx + 6, cy + 18);
    }
  }
}
