#!/usr/bin/env python3
"""Build a local, network-free gallery from verified real-engine captures."""
from pathlib import Path
import json,html
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'artifacts/art-ui-polish'
v=json.loads((OUT/'verification.json').read_text())
manifest=json.loads((OUT/'captures/manifest.json').read_text())
verified = v.get('status') == 'art_ui_playtest_candidate'
status_text = (f'技术试玩候选：25/25 脚本、36/36 有解、T8 峰值 {v["T8"]["max_us"]/1000:.3f} ms。尚未用户验收或正式发布。'
 if verified else '实现与功能检查完成，补修版最终 T8 尚未通过；当前为工作检查点。现有 DMG 属于补修前 full-04 版本，尚未交付当前源码的完整通过候选。')
labels={'dungeon':'幽暗石牢','forest':'迷雾古森','ruins':'黄金神庙','cave':'幽光晶窟','sky_island':'云端圣域','cosmos':'深空星站'}
def shot(name,label):
 return f'<figure><a href="captures/{name}-1920x1080.png"><img src="captures/{name}-native.png" width="640" height="360" alt="{html.escape(label)}"></a><figcaption>{html.escape(label)} · 点击查看 1920×1080</figcaption></figure>'
parts=['<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>美术与 UI 翻新实机图册</title>',
'<style>body{background:#181425;color:#fff;font:16px/1.6 system-ui;margin:24px auto;padding:0 20px;max-width:1380px}h1,h2{color:#fee761}a{color:#2ce8f5}nav{display:flex;gap:16px;flex-wrap:wrap}.grid{display:flex;flex-wrap:wrap;gap:20px}figure{margin:0 0 16px;width:640px;max-width:100%}img{display:block;width:100%;height:auto;image-rendering:pixelated}figcaption{font-size:14px;color:#c0cbdc}button{font:inherit;padding:6px 18px;margin-bottom:12px}section{padding-top:16px;border-top:1px solid #3a4466}</style>',
'<h1>美术与 UI 翻新 · 实机图册</h1>',
f'<p>{status_text}</p>',
'<p>全部影像来自 macOS Godot 实机。原生 320×180，高清整数放大 ×6；点击图像打开高清版。动画为三个实际渲染时刻的循环对照。</p>',
'<nav>'+''.join(f'<a href="#{k}">{val}</a>' for k,val in labels.items())+'</nav>',shot('lobby','主大厅')]
for key,label in labels.items():
 parts.append(f'<section id="{key}"><h2>{label}</h2><div class="grid">')
 parts.extend([shot(key+'-pool','主题选关与实景微缩窗'),shot(key+'-showcase-panorama','展示图全景'),shot(key+'-showcase-detail','展示图原生细节'),shot(key+'-observation','旗舰关观察池')])
 parts.append(f'<figure><img class="animation" data-theme="{key}" src="captures/{key}-animation-0-native.png" width="640" height="360"><figcaption>生态动画：0 / 0.35 / 0.8 秒</figcaption></figure></div><h3>六个关卡开局</h3><div class="grid">')
 for index in range(1,7):parts.append(shot(f'{key}-opening-{index:02}',f'{label} {index:02}'))
 parts.append('</div></section>')
parts.append('<script>let i=0;setInterval(()=>{i=(i+1)%3;document.querySelectorAll(".animation").forEach(e=>{e.src="captures/"+e.dataset.theme+"-animation-"+i+"-native.png"})},450)</script>')
parts.append('<p>'+('醒来后在本 Codex 聊天回复：美术与 UI 优化验收：通过 / 需改……' if verified else '下一步由当前 Codex 在资源空闲后完成全量门禁及更新包。恢复提示词：继续补修版性能门禁与打包；保持单 worker，资源空闲后完整验证，不放宽门槛。')+'</p>')
(OUT/'gallery.html').write_text('\n'.join(parts))
print('Wrote local gallery with',len(manifest['captures']),'verified views')
