#!/usr/bin/env python3
"""Build a self-contained interactive canvas from actual GUI geometry.

Native viewports are placeholders; this does not run Roblox Studio.
"""
from pathlib import Path
import json, subprocess, sys, tempfile
ROOT=Path(__file__).resolve().parents[1]
variants={
 'character':('dossier','nationality','personal','start'),'name':('dossier','firstName','personal','start'),
 'surname':('dossier','lastName','personal','start'),'appearance':('dossier','nationality','appearance','start'),
 'store':('store','nationality','personal','start'),'rolls':('premium','nationality','personal','start'),
 'daily':('daily','nationality','personal','start'),
 'vincent':('dialogue','nationality','personal','start'),'vincent-news':('dialogue','nationality','personal','news'),
 'vincent-rules':('dialogue','nationality','personal','club'),'vincent-sale':('dialogue','nationality','personal','sell'),
 'match-hud':('match-hud','','',''),'match-topic':('match-topic','','',''),
 'match-vote':('match-vote','','',''),'match-result':('match-result','','',''),
 'settings-language':('settings','nationality','personal','language'),'settings-audio':('settings','nationality','personal','audio'),
 'settings-picture':('settings','nationality','personal','picture'),'settings-controls':('settings','nationality','personal','controls'),
 'journal':('journal','nationality','personal','start')}
devices={'desktop':(1440,900),'hd':(1920,1080),'phone':(360,640),'narrow':(280,640),'shortphone':(360,540),'landscape':(844,360)}
layouts={}
with tempfile.TemporaryDirectory(prefix='spy-canvas-') as tmp:
    for device,(width,height) in devices.items():
        for key,(panel,target,tab,section) in variants.items():
            out=Path(tmp)/f'{device}-{key}.html'
            if panel.startswith('match-'):
                command=[sys.executable,str(ROOT/'tools/render_match_layout_preview.py'),panel.removeprefix('match-'),'--width',str(width),'--height',str(height),'--output',str(out)]
            else:
                command=[sys.executable,str(ROOT/'tools/render_layout_preview.py'),panel,'--width',str(width),'--height',str(height),
                         '--target',target,'--tab',tab,'--section',section,'--output',str(out)]
            subprocess.run(command,check=True,stdout=subprocess.DEVNULL)
            layouts[f'{device}:{key}']={'w':width,'h':height,'nodes':json.loads(out.with_suffix('.json').read_text())}
payload=json.dumps(layouts,ensure_ascii=False,separators=(',',':')).replace('</','<\\/')
page='''<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>SPY CLUB — UI canvas</title><style>
*{box-sizing:border-box}body{margin:0;background:#101114;color:#f4f4f5;font:14px Arial,sans-serif}header{padding:24px 4vw 16px;display:flex;align-items:end;gap:24px;flex-wrap:wrap;border-bottom:1px solid #34353b}h1{font:34px Georgia,serif;margin:0}header small{color:#a9abb3}nav{display:flex;gap:6px;flex-wrap:wrap}#variants{padding:0 4vw 16px}#variants button{padding:9px 14px;font-size:12px}.overview #variants{display:none}button,select{font:13px Arial;color:#bfc1c8;background:#202126;border:1px solid #46474f;padding:12px 16px;cursor:pointer}button[aria-current=true]{background:#ececef;color:#18191c}select{margin-left:auto}main{padding:22px 4vw}#frame{margin:auto;max-width:1440px;position:relative}canvas{display:block;width:100%;height:auto;background:#1b1c20;border:1px solid #36373e}p{color:#a9abb3;line-height:1.6;max-width:1100px;margin:14px auto}.tag{color:#f4f4f5}#overview{display:none;grid-template-columns:1fr 1fr;gap:20px}#overview canvas{width:100%}.overview #overview{display:grid}.overview #frame,.overview #note{display:none}.overview h2{font:24px Georgia;margin:0 0 10px}
</style><header><div><h1>SPY CLUB</h1><small>UI canvas · реальные размеры компонентов</small></div><nav>
<button data-group="character">H · Персонаж</button><button data-group="store">Магазин</button><button data-group="rolls">Rolls</button><button data-group="daily">Награды</button><button data-group="vincent">Винсент</button><button data-group="match">Матч</button><button data-group="settings">Настройки</button><button data-group="journal">Журнал</button></nav>
<select id="device" aria-label="Размер экрана"><option value="desktop">Компьютер · 1440 × 900</option><option value="hd">Компьютер · 1920 × 1080</option><option value="shortphone">Короткий телефон · 360 × 540</option><option value="phone">Телефон · 360 × 640</option><option value="narrow">Узкий · 280 × 640</option><option value="landscape">Альбомный · 844 × 360</option></select></header><nav id="variants"></nav><main><div id="frame"><canvas id="ui"></canvas></div><div id="overview"></div><p id="note"><span class="tag">Выбирай экран, состояние и размер устройства. Внутри канваса работают переходы между вкладками и меню.</span> Покупки и выдача наград здесь отключены. Композиция, подписи и цвета сняты с Luau-компонентов. 3D, точные переносы шрифта и окончательный контраст проверяются в Roblox Studio. AutoSize, сетки и шрифты здесь используют документированные приближения.</p></main><script>
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
const groups={
 character:[['character','Происхождение'],['name','Имя'],['surname','Фамилия'],['appearance','Внешность']],
 store:[['store','Вещи за монеты']],rolls:[['rolls','Пакеты Rolls']],daily:[['daily','Семь дней']],
 vincent:[['vincent','Разговор'],['vincent-news','Поручение'],['vincent-rules','Правила'],['vincent-sale','Скупка']],
 match:[['match-hud','За столом'],['match-topic','Выбор темы'],['match-vote','Голосование'],['match-result','Результаты']],
 settings:[['settings-language','Язык'],['settings-audio','Звук'],['settings-picture','Графика'],['settings-controls','Камера']],journal:[['journal','Поручения и достижения']]};
function update(){const l=layouts[device+':'+screen];document.querySelector('#frame').style.maxWidth=l.w+'px';draw(canvas,device+':'+screen);
 const group=Object.keys(groups).find(g=>groups[g].some(([k])=>k===screen));document.querySelectorAll('[data-group]').forEach(b=>b.setAttribute('aria-current',b.dataset.group===group));
 const rail=document.querySelector('#variants');rail.replaceChildren();for(const [key,title]of groups[group]){const b=document.createElement('button');b.textContent=title;b.dataset.screen=key;b.setAttribute('aria-current',key===screen);b.onclick=()=>{screen=key;update()};rail.append(b)}}
document.querySelectorAll('[data-group]').forEach(b=>b.onclick=()=>{screen=groups[b.dataset.group][0][0];update()});document.querySelector('#device').onchange=e=>{device=e.target.value;update()};
canvas.onclick=e=>{const l=layouts[device+':'+screen],r=canvas.getBoundingClientRect(),px=(e.clientX-r.left)*l.w/r.width,py=(e.clientY-r.top)*l.h/r.height;const n=l.nodes.filter(n=>n.class==='TextButton'&&px>=n.x&&px<n.x+n.w&&py>=n.y&&py<n.y+n.h).at(-1);if(!n)return;
 const targets={TabPersonal:'character',TabAppearance:'appearance',SelectIdentity_firstName:'name',SelectIdentity_lastName:'surname',SelectIdentity_nationality:'character',StoreRobuxTab:'rolls',BackToCharacter:'store',StoreToCharacter:'character',BuyRolls:'store',OpenDailyReward:'daily',Response_news:'vincent-news',Response_club:'vincent-rules',Response_sellItems:'vincent-sale',Response_shop:'store',Response_journal:'journal',Response_start:'vincent',SettingsCategory_language:'settings-language',SettingsCategory_audio:'settings-audio',SettingsCategory_picture:'settings-picture',SettingsCategory_controls:'settings-controls'};
 if(targets[n.name]){screen=targets[n.name];update()}};
const query=new URLSearchParams(location.search);if(query.has('overview')){document.body.classList.add('overview');const grid=document.querySelector('#overview');
 const panels=query.get('overview')==='extension'?[['vincent','Винсент · Разговор'],['match-vote','Матч · Голосование'],['settings-audio','Настройки · Звук'],['journal','Журнал клуба']]:query.get('overview')==='match'?[['match-hud','Матч · За столом'],['match-topic','Выбор темы'],['match-vote','Голосование'],['match-result','Результаты']]:[['name','H · Случайное имя'],['store','Магазин · Монеты'],['rolls','Rolls · Robux'],['daily','Семь дней']];
 for(const [key,title]of panels){const card=document.createElement('section'),h=document.createElement('h2'),c=document.createElement('canvas');h.textContent=title;card.append(h,c);grid.append(card);draw(c,'desktop:'+key)}}
if(query.has('screen')&&layouts['desktop:'+query.get('screen')])screen=query.get('screen');if(query.has('device')&&layouts[query.get('device')+':'+screen])device=query.get('device');document.querySelector('#device').value=device;update();

</script></html>'''.replace('__DATA__',payload)
out=ROOT/'docs/designs/club-ui-canvas.html';out.write_text(page);print(out)
