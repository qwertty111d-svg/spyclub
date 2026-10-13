-- Server-owned planar spheres. Metres mapped to the shared nine-foot club bed.
-- Sliding, rolling, draw/follow, spin transfer and dissipative cushion impulses.
local Physics={DT=1/120,HALF_X=6.1,HALF_Z=3.05,MAX_SPEED=17,FALL_SECONDS=.42,TIP_LIMIT=.72,BED_SLICES=96}
Physics.UNITS_PER_METRE=12.2/2.54
Physics.GRAVITY=9.81*Physics.UNITS_PER_METRE
Physics.POCKETS={{-6.1,-3.05},{0,-3.05},{6.1,-3.05},{-6.1,3.05},{0,3.05},{6.1,3.05}}
local profiles={
 -- Jaw-tip openings retain the discipline's width; the recessed throat is narrower.
 pool8={RADIUS=.05715*.5*Physics.UNITS_PER_METRE,POCKET_RADIUS=.235,CORNER_RADIUS=.210,MOUTH=.33,CORNER=.425,JAW=.025,RESTITUTION=.96,CUSHION=.82},
 pyramid={RADIUS=.068*.5*Physics.UNITS_PER_METRE,POCKET_RADIUS=.190,CORNER_RADIUS=.185,MOUTH=.2225,CORNER=.310,JAW=.025,RESTITUTION=.96,CUSHION=.78},
}
for _,p in pairs(profiles)do p.SLIDE=.20;p.ROLL=.012;p.SPIN_DECEL=12;p.BALL_FRICTION=.045;p.RAIL_FRICTION=.16 end
profiles.pool9=profiles.pool8
Physics.RADIUS=profiles.pool8.RADIUS;Physics.POCKET_RADIUS=profiles.pool8.POCKET_RADIUS
function Physics.pocketRadius(p,index)return (index==2 or index==5)and p.POCKET_RADIUS or p.CORNER_RADIUS end
function Physics.parameters(mode)return profiles[mode]or profiles.pool8 end
function Physics.finite(v)return type(v)=="number"and v==v and v>-math.huge and v<math.huge end
function Physics.ball(balls,id)for _,b in ipairs(balls)do if b.id==id then return b end end end
local function fresh(id,x,z)return {id=id,x=x,z=z,vx=0,vz=0,wx=0,wy=0,wz=0,pocketed=false,qx=0,qy=0,qz=0,qw=1}end
function Physics.newRack(mode,seed)
 local p=Physics.parameters(mode);local balls={fresh(0,-3.8,0)}
 if mode=="pool9"then
  local order={2,3,4,5,6,7,8};local state=math.floor(seed or 1)%2147483647;if state==0 then state=1 end
  for i=#order,2,-1 do state=(state*48271)%2147483647;local j=state%i+1;order[i],order[j]=order[j],order[i]end
  local spacing=p.RADIUS*2+.0002;local index=1
  for row=0,4 do local n=3-math.abs(row-2)
   for column=0,n-1 do local id
    if row==0 then id=1 elseif row==2 and column==1 then id=9 else id=order[index];index+=1 end
    table.insert(balls,fresh(id,3.05+(row-2)*spacing*math.sqrt(3)/2,(column-(n-1)/2)*spacing))
   end
  end;return balls
 end
 local order={1,9,2,10,8,3,11,4,12,5,6,13,7,14,15}
 if mode~="pyramid"then
  local state=math.floor(Physics.finite(seed)and seed or 1)%2147483647;if state==0 then state=1 end
  local function pick(n)state=(state*48271)%2147483647;return state%n+1 end
  local solid,stripe=pick(7),pick(7)+8;local rearLeft,rearRight=solid,stripe
  if pick(2)==1 then rearLeft,rearRight=rearRight,rearLeft end
  local available={};for id=1,15 do if id~=8 and id~=solid and id~=stripe then table.insert(available,id)end end
  for i=#available,2,-1 do local j=pick(i);available[i],available[j]=available[j],available[i]end
  local n=1
  for i=1,15 do
   if i==5 then order[i]=8 elseif i==11 then order[i]=rearLeft elseif i==15 then order[i]=rearRight
   else order[i]=available[n];n+=1 end
  end
 end
 local spacing=p.RADIUS*2+.0002;local index=1
 for row=0,4 do for column=0,row do
  local id=mode=="pyramid"and index or order[index]
  table.insert(balls,fresh(id,3.05+row*spacing*math.sqrt(3)/2,(column-row/2)*spacing));index+=1
 end end
 return balls
end
-- Exact same conservative strip edge is used by the rendered bed and capture.
function Physics.apertureCut(x,p)
 local width=2*Physics.HALF_X/Physics.BED_SLICES;local cut=0
 for i,c in ipairs(Physics.POCKETS)do
  local pr=Physics.pocketRadius(p,i)
  local nearest=math.max(0,math.abs(x-c[1])-width*.5)
  if nearest<pr then cut=math.max(cut,math.sqrt(pr^2-nearest^2))end
 end;return cut
end
function Physics.pocketIndexAt(x,z,p)
 local width=2*Physics.HALF_X/Physics.BED_SLICES
 local slice=math.clamp(math.floor((x+Physics.HALF_X)/width),0,Physics.BED_SLICES-1)
 local mid=-Physics.HALF_X+(slice+.5)*width
 for i,c in ipairs(Physics.POCKETS)do
  local pr=Physics.pocketRadius(p,i)
  if(x-c[1])^2+(z-c[2])^2<=pr^2 then return i end
  if x>=-Physics.HALF_X and x<=Physics.HALF_X then
   local nearest=math.max(0,math.abs(mid-c[1])-width*.5)
   if nearest<pr then
    local cut=math.sqrt(pr^2-nearest^2)
    if(c[2]<0 and z<=c[2]+cut)or(c[2]>0 and z>=c[2]-cut)then return i end
   end
  end
 end
end
function Physics.railsAtBall(b,p,standing)
 local result={};if standing and math.abs(b.vx)+math.abs(b.vz)>.02 then return result end
 local hx,hz,r=Physics.HALF_X,Physics.HALF_Z,p.RADIUS
 if math.abs(b.z)<=hz-p.CORNER then
  if math.abs(b.x+hx-r)<.003 then table.insert(result,1)end
  if math.abs(b.x-hx+r)<.003 then table.insert(result,2)end
 end
 if math.abs(b.x)>=p.MOUTH and math.abs(b.x)<=hx-p.CORNER then
  if math.abs(b.z+hz-r)<.003 then table.insert(result,3)end
  if math.abs(b.z-hz+r)<.003 then table.insert(result,4)end
 end;return result
end
function Physics.allStopped(balls)
 for _,b in ipairs(balls)do
  if b.pocketed then if b.fallT and b.fallT<Physics.FALL_SECONDS then return false end
  elseif math.abs(b.vx)+math.abs(b.vz)+math.abs(b.wx or 0)+math.abs(b.wy or 0)+math.abs(b.wz or 0)>.000001 then return false end
 end
 return true
end
function Physics.remaining(balls,includeCue)local count=0;for _,b in ipairs(balls)do if not b.pocketed and(includeCue or b.id~=0)then count+=1 end end;return count end
function Physics.stop(balls)for _,b in ipairs(balls)do b.vx,b.vz,b.wx,b.wy,b.wz=0,0,0,0,0;if b.fallT then b.fallT=Physics.FALL_SECONDS end end end
function Physics.validSpin(spin)
 if spin==nil then return true end
 return type(spin)=="table"and Physics.finite(spin.x)and Physics.finite(spin.y)and spin.x^2+spin.y^2<=Physics.TIP_LIMIT^2+.000001
end
function Physics.strike(balls,angle,power,mode,cueId,spin)
 if not Physics.finite(angle)or not Physics.finite(power)or angle < -360 or angle>360 or power<.08 or power>1 or not Physics.validSpin(spin)or not Physics.allStopped(balls)then return false end
 local cue=Physics.ball(balls,cueId or 0);if not cue or cue.pocketed then return false end
 local speed=.35+power*power*(Physics.MAX_SPEED-.35);local a=math.rad(angle);local dx,dz=math.cos(a),math.sin(a)
 local p=Physics.parameters(mode);local sx,sy=spin and spin.x or 0,spin and spin.y or 0
 cue.vx,cue.vz=dx*speed,dz*speed
 cue.wx,cue.wz=2.5*sy*dz*speed/p.RADIUS,-2.5*sy*dx*speed/p.RADIUS
 cue.wy=2.5*sx*speed/p.RADIUS;return true
end
-- Stroke histories follow the actual impulse chain, rather than counting unrelated rails.
local function history(trace,id)
 trace.histories=trace.histories or {};local h=trace.histories[id]
 if not h then h={rails={},crossed=false};trace.histories[id]=h end;return h
end
function Physics.event(trace,kind,id,side,jaw)
 if not trace then return end
 if kind=="contact"then
  if trace.firstContact==nil then
   trace.firstContact=id;trace.firstContactX=side
   if trace.homeRestricted and not trace.homeExited and side and side< -Physics.HALF_X/2 then trace.badHome=true end
  end;return
 end
 if kind=="rail"and trace.frozenActive and(trace.frozenActive[id]or {})[side]then return end
 if kind=="rail"and not jaw and id==trace.cueId and trace.firstContact==nil then trace.cueKick=true end
 if trace.firstContact==nil then return end
 local h=history(trace,id)
 if kind=="rail"then
  trace.rails=trace.rails or {};trace.objectsAtRail=trace.objectsAtRail or {};trace.banked=trace.banked or {}
  if not trace.rails[side]then trace.rails[side]=true;trace.railCount=(trace.railCount or 0)+1 end
  if id~=trace.cueId then trace.objectsAtRail[id]=true;if not jaw then trace.banked[id]=true end end
  if h.crossed then trace.pyramidLegal=true end
  for rail in pairs(h.rails)do if rail~=side then trace.pyramidLegal=true end end
  h.rails[side]=true
 elseif kind=="cross"then
  trace.crossed=true;if id~=trace.cueId then trace.objectCrossed=true end
  if next(h.rails)then trace.pyramidLegal=true end;h.crossed=true
 end
end
local function contactHistory(trace,a,b,frozenA,frozenB)
 if not trace or trace.firstContact==nil then return end
 local ha,hb=history(trace,a.id),history(trace,b.id)
 if next(ha.rails)and a.x*b.x<=0 or next(hb.rails)and a.x*b.x<=0 then trace.pyramidLegal=true end
 -- A collision transfers rail/crossing history with the propagated motion.
 local rails={};for k in pairs(ha.rails)do rails[k]=true end;for k in pairs(hb.rails)do rails[k]=true end
 for k in pairs(rails)do ha.rails[k]=true;hb.rails[k]=true end
 ha.crossed=ha.crossed or hb.crossed;hb.crossed=ha.crossed
 local frozen={[a.id]=frozenA,[b.id]=frozenB}
 for _,pair in ipairs({{a,b},{b,a}})do
  local h=history(trace,pair[1].id)
  for _,side in ipairs(frozen[pair[2].id]or {})do
   if h.crossed then trace.pyramidLegal=true end
   for previous in pairs(h.rails)do if previous~=side then trace.pyramidLegal=true end end
  end
 end
end
function Physics.newTrace(balls,cueId,p)
 local trace={cueId=cueId,railCount=0,rails={},objectsAtRail={},histories={},banked={},frozen={},frozenActive={},headCrossedObjects={}}
 for _,b in ipairs(balls)do if not b.pocketed then
  local f={};if math.abs(b.x+Physics.HALF_X-p.RADIUS)<.003 then table.insert(f,1)end
  if math.abs(b.x-Physics.HALF_X+p.RADIUS)<.003 then table.insert(f,2)end
  if math.abs(b.z+Physics.HALF_Z-p.RADIUS)<.003 then table.insert(f,3)end
  if math.abs(b.z-Physics.HALF_Z+p.RADIUS)<.003 then table.insert(f,4)end;trace.frozen[b.id]=f;trace.frozenActive[b.id]={};for _,side in ipairs(f)do trace.frozenActive[b.id][side]=true end
 end end;return trace
end
function Physics.collide(a,b,p)
 p=p or profiles.pool8;local dx,dz=b.x-a.x,b.z-a.z;local d2=dx*dx+dz*dz;local diameter=p.RADIUS*2
 if d2>=diameter^2 then return false,false end
 local distance=math.sqrt(d2);local nx,nz=1,0;if distance>.000001 then nx,nz=dx/distance,dz/distance end
 local correction=math.max(0,diameter-distance)/2+.0000001
 a.x-=nx*correction;a.z-=nz*correction;b.x+=nx*correction;b.z+=nz*correction
 local closing=(a.vx-b.vx)*nx+(a.vz-b.vz)*nz
 if closing>.000001 then
  local j=closing*(1+p.RESTITUTION)/2;a.vx-=j*nx;a.vz-=j*nz;b.vx+=j*nx;b.vz+=j*nz
  local tx,tz=-nz,nx
  local slip=(a.vx-b.vx)*tx+(a.vz-b.vz)*tz-p.RADIUS*((a.wy or 0)+(b.wy or 0))
  local jt=math.clamp(slip/7,-p.BALL_FRICTION*j,p.BALL_FRICTION*j)
  a.vx-=jt*tx;a.vz-=jt*tz;b.vx+=jt*tx;b.vz+=jt*tz
  a.wy=(a.wy or 0)+2.5*jt/p.RADIUS;b.wy=(b.wy or 0)+2.5*jt/p.RADIUS
 end
 return true,closing>.000001
end
local function rotate(b,dt)
 local wx,wy,wz=b.wx or 0,b.wy or 0,b.wz or 0;local length=math.sqrt(wx^2+wy^2+wz^2);if length<.000001 then return end
 local h=length*dt*.5;local k=math.sin(h)/length;local x,y,z,w=wx*k,wy*k,wz*k,math.cos(h)
 local qx,qy,qz,qw=b.qx or 0,b.qy or 0,b.qz or 0,b.qw or 1
 b.qx=w*qx+x*qw+y*qz-z*qy;b.qy=w*qy+y*qw+z*qx-x*qz
 b.qz=w*qz+z*qw+x*qy-y*qx;b.qw=w*qw-x*qx-y*qy-z*qz
 local n=math.sqrt(b.qx^2+b.qy^2+b.qz^2+b.qw^2);b.qx/=n;b.qy/=n;b.qz/=n;b.qw/=n
end
local function cloth(b,p,dt)
 local r=p.RADIUS;local wx,wz=b.wx or 0,b.wz or 0
 local sx,sz=b.vx+r*wz,b.vz-r*wx;local slip=math.sqrt(sx*sx+sz*sz)
 local rollingDt=dt
 if slip>.00001 then
  local a=p.SLIDE*Physics.GRAVITY;local duration=math.min(dt,slip/(3.5*a))
  local ax,az=-a*sx/slip,-a*sz/slip
  b.vx+=ax*duration;b.vz+=az*duration;wx-=2.5*az*duration/r;wz+=2.5*ax*duration/r
  rollingDt-=duration
 end
 if rollingDt>0 then
  local speed=math.sqrt(b.vx^2+b.vz^2);local nextSpeed=math.max(0,speed-p.ROLL*Physics.GRAVITY*rollingDt)
  if nextSpeed<.008 then b.vx,b.vz=0,0 elseif speed>0 then b.vx*=nextSpeed/speed;b.vz*=nextSpeed/speed end
  wx,wz=b.vz/r,-b.vx/r
 end
 b.wx,b.wz=wx,wz
 local spin=b.wy or 0;local reduced=math.max(0,math.abs(spin)-p.SPIN_DECEL*dt);b.wy=spin<0 and -reduced or reduced
end
function Physics.jaws(p)
 local jaws={};local h,z=Physics.HALF_X,Physics.HALF_Z
 for _,sign in ipairs({-1,1})do
  for _,x in ipairs({-p.MOUTH,p.MOUTH,-h+p.CORNER,h-p.CORNER})do table.insert(jaws,{x,sign*z})end
  for _,side in ipairs({-1,1})do table.insert(jaws,{side*h,sign*(z-p.CORNER)})end
 end;return jaws
end
-- At most twelve audible contacts per 120Hz tick, strongest impacts retained.
function Physics.audio(trace,kind,level)
 if not trace or not Physics.finite(level)or level<.03 then return end
 local e={kind=kind,level=math.clamp(level,0,1)};trace.audio=trace.audio or {}
 if #trace.audio<12 then table.insert(trace.audio,e)
 else local weakest=1;for i,v in ipairs(trace.audio)do if v.level<trace.audio[weakest].level then weakest=i end end
  if e.level>trace.audio[weakest].level then trace.audio[weakest]=e end
 end
end
local function rebound(b,nx,nz,p,trace,side,jaw)
 local vn=b.vx*nx+b.vz*nz;if vn>=-.000001 then return end
 Physics.audio(trace,"cushion",math.abs(vn)/10)
 local j=-(1+p.CUSHION)*vn;b.vx+=j*nx;b.vz+=j*nz
 local tx,tz=-nz,nx;local slip=b.vx*tx+b.vz*tz+p.RADIUS*(b.wy or 0)
 local jt=math.clamp(-slip/3.5,-p.RAIL_FRICTION*j,p.RAIL_FRICTION*j)
 b.vx+=jt*tx;b.vz+=jt*tz;b.wy=(b.wy or 0)+2.5*jt/p.RADIUS
 Physics.event(trace,"rail",b.id,side,jaw)
end
local function cushions(b,p,trace,jaws)
 local hx,hz,r=Physics.HALF_X,Physics.HALF_Z,p.RADIUS;local lx,lz=hx-r,hz-r
 local sideGap=math.abs(b.x)<p.MOUTH or math.abs(b.x)>hx-p.CORNER;local endGap=math.abs(b.z)>hz-p.CORNER
 if not endGap then
  if b.x < -lx then b.x=-lx;rebound(b,1,0,p,trace,1)end
  if b.x > lx then b.x=lx;rebound(b,-1,0,p,trace,2)end
 end
 if not sideGap then
  if b.z < -lz then b.z=-lz;rebound(b,0,1,p,trace,3)end
  if b.z > lz then b.z=lz;rebound(b,0,-1,p,trace,4)end
 end
 for _,jaw in ipairs(jaws)do
  local dx,dz=b.x-jaw[1],b.z-jaw[2];local distance=math.sqrt(dx^2+dz^2);local reach=r+p.JAW
  if distance<reach and distance>.000001 then
   local nx,nz=dx/distance,dz/distance;b.x=jaw[1]+nx*reach;b.z=jaw[2]+nz*reach
   rebound(b,nx,nz,p,trace,math.abs(jaw[1])>hx-.01 and(jaw[1]<0 and 1 or 2)or(jaw[2]<0 and 3 or 4),true)
  end
 end
 -- Pocket backs are closed. A miss cannot escape the simulation or hover off-table.
 if math.abs(b.x)>hx+p.POCKET_RADIUS then local sign=b.x<0 and -1 or 1;b.x=sign*(hx+p.POCKET_RADIUS);rebound(b,-sign,0,p,trace,sign<0 and 1 or 2)end
 if math.abs(b.z)>hz+p.POCKET_RADIUS then local sign=b.z<0 and -1 or 1;b.z=sign*(hz+p.POCKET_RADIUS);rebound(b,0,-sign,p,trace,sign<0 and 3 or 4)end
end
function Physics.step(balls,p,trace)
 p=p or profiles.pool8;local speed=0
 for _,b in ipairs(balls)do if not b.pocketed then speed=math.max(speed,math.sqrt(b.vx^2+b.vz^2))end end
 local steps=math.clamp(math.ceil(speed*Physics.DT/(p.RADIUS*.25)),1,12);local dt=Physics.DT/steps;local sunk={};local jaws=Physics.jaws(p)
 local function sink(b)
  local index=Physics.pocketIndexAt(b.x,b.z,p)
  if index then Physics.audio(trace,"pocket",.35+math.sqrt(b.vx^2+b.vz^2)/17*.4);b.pocketed=true;b.pocketIndex=index;b.fallT=0;b.vx,b.vz=0,0;table.insert(sunk,b.id)end
 end
 for _=1,steps do
  for _,b in ipairs(balls)do
   if b.pocketed then if b.fallT then b.fallT=math.min(Physics.FALL_SECONDS,b.fallT+dt);rotate(b,dt)end
   else
    local oldX=b.x;b.x+=b.vx*dt;b.z+=b.vz*dt
    if trace and b.id~=trace.cueId and oldX>=-Physics.HALF_X/2 and b.x< -Physics.HALF_X/2 then trace.headCrossedObjects=trace.headCrossedObjects or {};trace.headCrossedObjects[b.id]=true end
    if trace and trace.homeRestricted and b.id==trace.cueId and b.x>=-Physics.HALF_X/2 then trace.homeExited=true end
    if trace and trace.frozenActive then
     local f=trace.frozenActive[b.id]or {};local r=p.RADIUS
     if b.x>-Physics.HALF_X+r+.005 then f[1]=nil end
     if b.x<Physics.HALF_X-r-.005 then f[2]=nil end
     if b.z>-Physics.HALF_Z+r+.005 then f[3]=nil end
     if b.z<Physics.HALF_Z-r-.005 then f[4]=nil end
    end
    if(oldX<0 and b.x>=0)or(oldX>0 and b.x<=0)then Physics.event(trace,"cross",b.id)end
    -- Resolve support loss before any jaw can push an unsupported centre
    -- back onto the bed. The capture edge is the actual rendered aperture.
    sink(b)
    if not b.pocketed then cushions(b,p,trace,jaws);sink(b)end
   end
  end
  for _=1,3 do for i=1,#balls-1 do local a=balls[i]
   if not a.pocketed then for j=i+1,#balls do local b=balls[j]
    local dx,dz=b.x-a.x,b.z-a.z
    -- Same rejection as collide(), before allocating rail histories for a pair
    -- which cannot touch. Pair order and all three solver passes stay intact.
    if not b.pocketed and dx*dx+dz*dz<(p.RADIUS*2)^2 then
     local frozenA,frozenB=Physics.railsAtBall(a,p,true),Physics.railsAtBall(b,p,true);local ax,bx=a.x,b.x
     local speed=math.sqrt((a.vx-b.vx)^2+(a.vz-b.vz)^2)
     local _,impulse=Physics.collide(a,b,p)
     if impulse and trace then
      Physics.audio(trace,"ball",speed/12)
      if a.id==trace.cueId then Physics.event(trace,"contact",b.id,bx)elseif b.id==trace.cueId then Physics.event(trace,"contact",a.id,ax)end
      contactHistory(trace,a,b,frozenA,frozenB)
     end
    end
   end end
  end end
  for _,b in ipairs(balls)do if not b.pocketed then
   -- Pair separation can also move a centre beyond the support edge.
   sink(b)
   if not b.pocketed then cushions(b,p,trace,jaws);sink(b)end
   if not b.pocketed then cloth(b,p,dt);rotate(b,dt)end
  end end
 end
 return sunk
end
function Physics.place(balls,id,x,z,p,area)
 if not Physics.finite(x)or not Physics.finite(z)then return false end
 local b=Physics.ball(balls,id);if not b then return false end
 if math.abs(x)>Physics.HALF_X-p.RADIUS or math.abs(z)>Physics.HALF_Z-p.RADIUS or(area=="home"and x>=-Physics.HALF_X/2)then return false end
 for i,c in ipairs(Physics.POCKETS)do if(x-c[1])^2+(z-c[2])^2<=(Physics.pocketRadius(p,i)+p.RADIUS*.15)^2 then return false end end
 for _,other in ipairs(balls)do if other.id~=id and not other.pocketed and(other.x-x)^2+(other.z-z)^2<(p.RADIUS*2+.0001)^2 then return false end end
 b.x,b.z,b.vx,b.vz,b.wx,b.wy,b.wz,b.pocketed=x,z,0,0,0,0,0,false;b.pocketIndex=nil;b.fallT=nil;return true
end
function Physics.spot(balls,id,p)
 -- Foot spot, then toward foot rail; only after that toward head. Never random grid.
 for _,sign in ipairs({1,-1})do for i=0,math.ceil(Physics.HALF_X*2/.005)do
  local x=Physics.HALF_X/2+sign*i*.005
  if math.abs(x)<=Physics.HALF_X-p.RADIUS and Physics.place(balls,id,x,0,p,"table")then return true end
 end end;return false
end
function Physics.respawnCue(balls,p)
 p=p or profiles.pool8
 for x=-4.8,-3.2,.3 do for z=-2.5,2.5,.3 do if Physics.place(balls,0,x,z,p,"home")then return true end end end
 return Physics.spot(balls,0,p)
end
return Physics
