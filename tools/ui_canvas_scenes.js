// Labelled composition illustration, not a Roblox table render or simulation.
function drawTableScene(ctx, layout) {
  const byName = name => layout.nodes.find(node => node.name === name);
  const players = byName('Players'), dock = byName('PoolPanel');
  const power = byName('CuePower'), spin = byName('SpinControl');
  const left = power ? power.x + power.w + 18 : 28;
  const right = spin ? spin.x - 18 : layout.w - 28;
  const top = players ? players.y + players.h + 22 : 104;
  const bottom = dock ? dock.y - 22 : layout.h - 130;
  const availableW = Math.max(80, right - left), availableH = Math.max(100, bottom - top);
  const portrait = layout.w / layout.h < .85;
  const long = tableScene.HALF_X * 2, short = tableScene.HALF_Z * 2;
  const bedW = portrait ? short : long, bedH = portrait ? long : short;
  const scale = Math.min(availableW / (bedW + 1.2), availableH / (bedH + 1.2));
  const w = bedW * scale, h = bedH * scale, rim = scale * .6;
  const cx = left + availableW / 2, cy = top + availableH / 2;
  const color = rgb => `rgb(${rgb.join(',')})`;
  ctx.save();
  ctx.translate(cx, cy);
  ctx.shadowColor = '#0008';ctx.shadowBlur = 25;
  ctx.fillStyle = color(tableScene.edge);
  ctx.beginPath();ctx.roundRect(-w/2-rim,-h/2-rim,w+rim*2,h+rim*2,rim*.4);ctx.fill();
  ctx.shadowBlur = 0;
  ctx.fillStyle = color(tableScene.cushion);ctx.fillRect(-w/2-3,-h/2-3,w+6,h+6);
  ctx.fillStyle = color(tableScene.felt);ctx.fillRect(-w/2,-h/2,w,h);
  ctx.strokeStyle = '#ffffff10';ctx.lineWidth = 1;
  for(let i=1;i<16;i++){ctx.beginPath();ctx.moveTo(-w/2+i*w/16,-h/2);ctx.lineTo(-w/2+i*w/16,h/2);ctx.stroke()}
  ctx.fillStyle = color(tableScene.hole);
  for(const sign of [-1,1])for(const along of [-1,0,1]){
    const x=portrait?sign*w/2:along*w/2, y=portrait?along*h/2:sign*h/2;
    ctx.beginPath();ctx.arc(x,y,Math.max(3,scale*.24),0,Math.PI*2);ctx.fill();
  }
  const ball = (x,y,fill) => {ctx.fillStyle=fill;ctx.beginPath();ctx.arc(x,y,Math.max(2,scale*.14),0,Math.PI*2);ctx.fill()};
  ball(portrait?0:-w*.25,portrait?h*.25:0,'#eeece5');
  for(let row=0;row<3;row++)for(let index=0;index<=row;index++){
    const along=scale*(1.5+row*.28),across=scale*(index-row*.5)*.32;
    ball(portrait?across:along,portrait?-along:across,['#c6bba1','#44484e','#999891'][(row+index)%3]);
  }
  ctx.fillStyle='#c9cccf';ctx.font=`${Math.max(8,Math.min(11,layout.w/36))}px Arial`;
  ctx.textAlign='center';ctx.fillText('СТОЛ — СХЕМА КОМПОЗИЦИИ',0,h/2+rim+18);
  ctx.restore();
}
