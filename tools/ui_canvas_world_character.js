// A projected 3D diagram of the H sequence, not Roblox rendering or a real skin.
let worldPreviewStart = null, worldPreviewFrame = 0, worldPreviewActive = false;
const isWorldCharacterKey = key => /:(character|name|surname|appearance)$/.test(key);
const worldClamp = value => Math.max(0, Math.min(1, value));
const worldEase = value => 1 - Math.pow(1 - worldClamp(value), 5);
function worldPreviewTime(c, key) {
  if (c !== canvas || !isWorldCharacterKey(key) || matchMedia('(prefers-reduced-motion: reduce)').matches) return 10;
  return worldPreviewStart === null ? 10 : (performance.now() - worldPreviewStart) / 1000;
}
function worldPaneAmount(side, time) {
  return worldEase((time - (side === 'right' ? 1.0 : .72)) / .28);
}
function startWorldPreview(force = false) {
  const active = isWorldCharacterKey(device + ':' + screen);
  if (active && (!worldPreviewActive || force)) worldPreviewStart = performance.now();
  worldPreviewActive = active;
  if (worldPreviewFrame) cancelAnimationFrame(worldPreviewFrame);
  worldPreviewFrame = 0;
  if (!active) return;
  const tick = () => {
    worldPreviewFrame = 0;
    if (!isWorldCharacterKey(device + ':' + screen)) return;
    draw(canvas, device + ':' + screen);
    if (worldPreviewTime(canvas, device + ':' + screen) < 1.34) worldPreviewFrame = requestAnimationFrame(tick);
  };
  worldPreviewFrame = requestAnimationFrame(tick);
}
function drawWorldCharacterScene(ctx, layout, time, enabled) {
  const aperture = layout.nodes.find(node => node.name === 'PortraitStage');
  if (!aperture) return;
  const cx = aperture.x + aperture.w / 2, cy = aperture.y + aperture.h / 2;
  if (!enabled) {
    ctx.save();ctx.fillStyle = '#b0b2ba';ctx.font = '12px Arial';ctx.textAlign = 'center';
    ctx.fillText('3D-мир · Roblox Studio', cx, cy);ctx.restore();return;
  }
  const angle = -.68 * (1 - worldEase(time / .72));
  const distance = 9, focal = distance * Math.min(aperture.h / 6.4, aperture.w / 3.6);
  const sin = Math.sin(angle), cos = Math.cos(angle);
  function project(point) {
    const [x, y, z] = point, depth = distance - sin*x + cos*z;
    if (depth <= .3) return null;
    return {x:cx + focal*(cos*x + sin*z)/depth, y:cy - focal*(y-2.7)/depth, depth};
  }
  const faces = [];
  function face(points, fill) {
    const projected = points.map(project);
    if (projected.some(point => !point)) return;
    faces.push({points:projected, fill, depth:projected.reduce((sum,p)=>sum+p.depth,0)/projected.length});
  }
  function box(x,y,z,w,h,d,fill,side = '#282b30') {
    const x0=x-w/2,x1=x+w/2,y0=y-h/2,y1=y+h/2,z0=z-d/2,z1=z+d/2;
    face([[x0,y0,z0],[x1,y0,z0],[x1,y1,z0],[x0,y1,z0]],fill);
    face([[x0,y0,z1],[x0,y1,z1],[x1,y1,z1],[x1,y0,z1]],side);
    face([[x0,y0,z0],[x0,y1,z0],[x0,y1,z1],[x0,y0,z1]],side);
    face([[x1,y0,z0],[x1,y0,z1],[x1,y1,z1],[x1,y1,z0]],side);
    face([[x0,y1,z0],[x1,y1,z0],[x1,y1,z1],[x0,y1,z1]],side);
  }
  ctx.save();ctx.beginPath();ctx.rect(0,0,layout.w,layout.h);ctx.clip();
  const room = ctx.createLinearGradient(0,0,0,layout.h);
  room.addColorStop(0,'#17191e');room.addColorStop(.55,'#2d3036');room.addColorStop(1,'#17181b');
  ctx.fillStyle=room;ctx.fillRect(0,0,layout.w,layout.h);
  // Architectural context stays behind the actor; this is deliberately a diagram.
  face([[-28,0,9],[28,0,9],[28,13,9],[-28,13,9]],'#292c32');
  for(let x=-18;x<20;x+=4) {
    box(x,5.5,8.7,.18,11,.3,'#44474e','#33363d');
    face([[x+.2,3,8.6],[x+3.8,3,8.6],[x+3.8,9,8.6],[x+.2,9,8.6]],'#12151c');
    box(x+2,10.1,8.3,2.5,.05,.12,'#c1c1bc','#777b80');
  }
  for(let z=-2;z<10;z+=2)for(let x=-14;x<16;x+=2)
    face([[x,0,z],[x+2,0,z],[x+2,0,z+2],[x,0,z+2]],(x+z)%4===0?'#303338':'#2c2e33');
  box(-.43,1.1,0,.75,1.95,.75,'#202126','#17191d');
  box(.43,1.1,0,.75,1.95,.75,'#202126','#17191d');
  box(-.43,.18,-.14,.82,.32,1,'#13151a','#101216');
  box(.43,.18,-.14,.82,.32,1,'#13151a','#101216');
  box(0,3,0,1.85,1.95,.95,'#24262b','#191c21');
  box(-1.2,3,0,.52,1.95,.75,'#292c31','#202328');
  box(1.2,3,0,.52,1.95,.75,'#292c31','#202328');
  box(0,4.72,0,1.4,1.35,1.1,'#d2c7b6','#a49c91');
  box(0,5.36,.06,1.5,.23,1.2,'#252326','#1b1a1e');
  face([[-.72,4.85,-.57],[-.72,5.48,-.57],[.72,5.48,-.57],[.72,5.04,-.57],[.35,5.24,-.57],[0,5.05,-.57],[-.25,5.25,-.57]],'#282428');
  face([[-.65,3.93,-.49],[0,3.55,-.49],[-.2,3.12,-.49]],'#e8e6df');
  face([[.65,3.93,-.49],[0,3.55,-.49],[.2,3.12,-.49]],'#e8e6df');
  face([[0,3.6,-.51],[.1,3.4,-.51],[.06,2.65,-.51],[-.06,2.65,-.51],[-.1,3.4,-.51]],'#8e9199');
  face([[-.34,4.72,-.57],[-.24,4.72,-.57],[-.24,4.8,-.57],[-.34,4.8,-.57]],'#333139');
  face([[.24,4.72,-.57],[.34,4.72,-.57],[.34,4.8,-.57],[.24,4.8,-.57]],'#333139');
  faces.sort((a,b)=>b.depth-a.depth);
  for(const item of faces) {
    ctx.fillStyle=item.fill;ctx.beginPath();ctx.moveTo(item.points[0].x,item.points[0].y);
    for(const p of item.points.slice(1))ctx.lineTo(p.x,p.y);
    ctx.closePath();ctx.fill();ctx.strokeStyle='#ffffff08';ctx.lineWidth=.6;ctx.stroke();
  }
  const vignette=ctx.createRadialGradient(cx,cy,Math.min(aperture.w,aperture.h)*.2,cx,cy,Math.max(layout.w,layout.h)*.7);
  vignette.addColorStop(0,'#0000');vignette.addColorStop(1,'#08090dbb');ctx.fillStyle=vignette;ctx.fillRect(0,0,layout.w,layout.h);
  ctx.restore();
}
