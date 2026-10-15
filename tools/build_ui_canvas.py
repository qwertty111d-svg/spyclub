#!/usr/bin/env python3
"""Build a self-contained interactive canvas from actual GUI geometry.

Native viewports are placeholders; this does not run Roblox Studio.
"""
from pathlib import Path
import json, subprocess, sys, tempfile
ROOT=Path(__file__).resolve().parents[1]
variants={'character':('dossier','nationality','personal'),'name':('dossier','firstName','personal'),
          'surname':('dossier','lastName','personal'),'appearance':('dossier','nationality','appearance'),
          'store':('store','nationality','personal'),'rolls':('premium','nationality','personal'),'daily':('daily','nationality','personal')}
devices={'desktop':(1440,900),'phone':(360,640),'narrow':(280,640),'landscape':(844,360)}
layouts={}
with tempfile.TemporaryDirectory(prefix='spy-canvas-') as tmp:
    for device,(width,height) in devices.items():
        for key,(panel,target,tab) in variants.items():
            out=Path(tmp)/f'{device}-{key}.html'
            subprocess.run([sys.executable,str(ROOT/'tools/render_layout_preview.py'),panel,'--width',str(width),'--height',str(height),
                            '--target',target,'--tab',tab,'--output',str(out)],check=True,stdout=subprocess.DEVNULL)
            layouts[f'{device}:{key}']={'w':width,'h':height,'nodes':json.loads(out.with_suffix('.json').read_text())}
payload=json.dumps(layouts,ensure_ascii=False,separators=(',',':')).replace('</','<\\/')
page='''<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>SPY CLUB — UI canvas</title><style>
*{box-sizing:border-box}body{margin:0;background:#101114;color:#f4f4f5;font:14px Arial,sans-serif}header{padding:24px 4vw 16px;display:flex;align-items:end;gap:24px;flex-wrap:wrap;border-bottom:1px solid #34353b}h1{font:34px Georgia,serif;margin:0}header small{color:#a9abb3}nav{display:flex;gap:6px;flex-wrap:wrap}button,select{font:13px Arial;color:#bfc1c8;background:#202126;border:1px solid #46474f;padding:12px 16px;cursor:pointer}button[aria-current=true]{background:#ececef;color:#18191c}select{margin-left:auto}main{padding:22px 4vw}#frame{margin:auto;max-width:1440px;position:relative}canvas{display:block;width:100%;height:auto;background:#1b1c20;border:1px solid #36373e}p{color:#a9abb3;line-height:1.6;max-width:1100px;margin:14px auto}.tag{color:#f4f4f5}#overview{display:none;grid-template-columns:1fr 1fr;gap:20px}#overview canvas{width:100%}.overview #overview{display:grid}.overview #frame,.overview #note{display:none}.overview h2{font:24px Georgia;margin:0 0 10px}
</style><header><div><h1>SPY CLUB</h1><small>UI canvas · реальные размеры компонентов</small></div><nav>
<button data-screen="character">H · Персонаж</button><button data-screen="store">Магазин</button><button data-screen="rolls">Rolls · Robux</button><button data-screen="daily">Семь дней</button></nav>
<select id="device" aria-label="Размер экрана"><option value="desktop">Компьютер · 1440 × 900</option><option value="phone">Телефон · 360 × 640</option><option value="narrow">Узкий · 280 × 640</option><option value="landscape">Альбомный · 844 × 360</option></select></header><main><div id="frame"><canvas id="ui"></canvas></div><div id="overview"></div><p id="note"><span class="tag">Нажми вкладки H, поля имени и фамилии или вкладку Rolls в магазине.</span> Покупки и выдача наград здесь отключены. Размеры, подписи и цвета сняты с Luau-компонентов; 3D-аватар, вещи и фон комнаты требуют Roblox Studio. Шрифт браузера заменяет игровой Garamond.</p></main><script>
const layouts=__DATA__;let screen='character',device='desktop';const canvas=document.querySelector('#ui');
const col=(v,a=1)=>v?`rgba(${v[1]},${v[2]},${v[3]},${a})`:'transparent';
function lines(ctx,text,width,wrap){if(!wrap)return text.split('\\n');let out=[];for(const line of text.split('\\n')){let row='';for(const word of line.split(' ')){const test=row?row+' '+word:word;if(ctx.measureText(test).width<=width){row=test;continue}if(row){out.push(row);row=''}for(const ch of word){if(row&&ctx.measureText(row+ch).width>width){out.push(row);row=''}row+=ch}}out.push(row)}return out}
function draw(c,key){const layout=layouts[key];c.width=layout.w;c.height=layout.h;const x=c.getContext('2d');
 const bg=x.createLinearGradient(0,0,layout.w,layout.h);bg.addColorStop(0,'#37383d');bg.addColorStop(.45,'#222328');bg.addColorStop(1,'#17181c');x.fillStyle=bg;x.fillRect(0,0,c.width,c.height);
 x.strokeStyle='#ffffff08';for(let j=0;j<7;j++){x.strokeRect(j*c.width/6-80,0,90,c.height)}
 const nodes=layout.nodes.map((n,i)=>({...n,i})).sort((a,b)=>a.z-b.z||a.i-b.i);
 for(const n of nodes){if(n.w<=0||n.h<=0)continue;x.save();x.beginPath();x.rect(n.clip.x,n.clip.y,Math.max(0,n.clip.right-n.clip.x),Math.max(0,n.clip.bottom-n.clip.y));x.clip();
 x.fillStyle=col(n.bg,n.bgAlpha);x.fillRect(n.x,n.y,n.w,n.h);
 if(n.strokeWidth&&n.strokeAlpha){x.strokeStyle=col(n.strokeColor,n.strokeAlpha);x.lineWidth=n.strokeWidth;x.strokeRect(n.x+.5,n.y+.5,n.w-1,n.h-1)}
 if(n.class==='ViewportFrame'){x.strokeStyle='#c4c6ce24';x.setLineDash([4,6]);x.strokeRect(n.x+8,n.y+8,n.w-16,n.h-16);x.setLineDash([]);x.fillStyle='#9b9da7';x.font='11px Arial';x.textAlign='center';x.fillText(n.w>150?'3D-персонаж · Roblox Studio':'3D preview',n.x+n.w/2,n.y+n.h/2);}
 if(n.text){x.beginPath();x.rect(n.x,n.y,n.w,n.h);x.clip();const serif=n.font.includes('Garamond'),bold=n.font.includes('Bold');x.font=`${bold?'700':'400'} ${n.fontSize}px ${serif?'Georgia':'Arial'}`;x.fillStyle=col(n.color,n.textAlpha);x.textBaseline='middle';const right=n.align.includes('Right'),center=n.align.includes('Center');x.textAlign=right?'right':center?'center':'left';let rows=lines(x,n.text,n.w-2,n.wrap);const lh=n.fontSize*1.12;let top=n.valign.includes('Top')?n.y+lh/2:n.y+(n.h-rows.length*lh)/2+lh/2;for(let line of rows){if(!n.wrap&&x.measureText(line).width>n.w){while(line.length&&x.measureText(line+'…').width>n.w)line=line.slice(0,-1);line+='…'}x.fillText(line,n.x+(right?n.w:center?n.w/2:0),top);top+=lh}}
 x.restore()}}
function update(){const l=layouts[device+':'+screen];document.querySelector('#frame').style.maxWidth=l.w+'px';draw(canvas,device+':'+screen);document.querySelectorAll('[data-screen]').forEach(b=>b.setAttribute('aria-current',b.dataset.screen===screen||(b.dataset.screen==='character'&&['name','surname','appearance'].includes(screen))))}
document.querySelectorAll('[data-screen]').forEach(b=>b.onclick=()=>{screen=b.dataset.screen;update()});document.querySelector('#device').onchange=e=>{device=e.target.value;update()};
canvas.onclick=e=>{const l=layouts[device+':'+screen],r=canvas.getBoundingClientRect(),px=(e.clientX-r.left)*l.w/r.width,py=(e.clientY-r.top)*l.h/r.height;const n=l.nodes.filter(n=>n.class==='TextButton'&&px>=n.x&&px<n.x+n.w&&py>=n.y&&py<n.y+n.h).at(-1);if(!n)return;const targets={TabPersonal:'character',TabAppearance:'appearance',SelectIdentity_firstName:'name',SelectIdentity_lastName:'surname',SelectIdentity_nationality:'character',StoreRobuxTab:'rolls',BackToCharacter:'store',StoreToCharacter:'character',BuyRolls:'store',OpenDailyReward:'daily'};if(targets[n.name]){screen=targets[n.name];update()}};
const query=new URLSearchParams(location.search);if(query.has('overview')){document.body.classList.add('overview');const grid=document.querySelector('#overview');for(const [key,title] of [['name','H · Случайное имя'],['store','Магазин · Монеты'],['rolls','Rolls · Robux'],['daily','Семь дней']]){const card=document.createElement('section'),h=document.createElement('h2'),c=document.createElement('canvas');h.textContent=title;card.append(h,c);grid.append(card);draw(c,'desktop:'+key)}}
if(query.has('screen'))screen=query.get('screen');if(query.has('device'))device=query.get('device');document.querySelector('#device').value=device;update();
</script></html>'''.replace('__DATA__',payload)
out=ROOT/'docs/designs/club-ui-canvas.html';out.write_text(page);print(out)
