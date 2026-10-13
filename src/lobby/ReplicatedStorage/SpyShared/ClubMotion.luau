-- Numeric gait model. No camera, remotes, physics or animation ownership here.
local Motion={}
local function ease(value,target,rate,dt) return target+(value-target)*math.exp(-rate*dt) end
function Motion.new()
 return {roll=0,pitch=0,phase=0,steps=0,speed=0,landing=0,airSpeed=0,grounded=true}
end
function Motion.step(s,input,dt)
 dt=math.clamp(dt,0,.1)
 local enabled=input.enabled~=false
 local moving=enabled and input.grounded and (input.speed or 0)>.8
 local speed=moving and math.min(input.speed,26) or 0
 s.speed=ease(s.speed,speed,12,dt)
 local roll=enabled and input.grounded and math.clamp(-(input.side or 0)*.0028-(input.turn or 0)*.007,-math.rad(5),math.rad(5)) or 0
 local pitch=moving and math.clamp(-(input.forward or 0)*.0022,-.045,.03) or 0
 s.roll=ease(s.roll,roll,8,dt);s.pitch=ease(s.pitch,pitch,8,dt)
 if moving then s.phase+=speed*dt*(math.pi/6.3) end
 local steps=math.floor(s.phase/math.pi)
 local footstep=moving and steps>s.steps
 s.steps=steps
 if not input.grounded then s.airSpeed=math.min(s.airSpeed,input.vertical or 0) end
 if input.grounded and not s.grounded and enabled then s.landing=math.clamp(-s.airSpeed/45,0,1);s.airSpeed=0 end
 s.landing=ease(s.landing,0,11,dt)
 s.grounded=input.grounded==true
 return footstep
end
return Motion
