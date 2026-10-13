-- Local presentation state machine, deliberately independent from Humanoid movement authority.
local Gait={}
function Gait.create(animator,ids,delay,onFailure)
 local self={active=nil,tracks={},animations={},closed=false,failed={}}
 local function load(state)
  if self.tracks[state]then return self.tracks[state]end
  if self.failed[state]or not ids[state]then return nil end
  self.failed[state]=true
  local animation=Instance.new("Animation");animation.AnimationId="rbxassetid://"..tostring(ids[state])
  local ok,track=pcall(function()return animator:LoadAnimation(animation)end)
  if self.closed then if ok and track then track:Destroy()end;animation:Destroy();return nil end
  if not ok or not track then animation:Destroy();if onFailure then onFailure(state,"load denied")end;return nil end
  track.Priority=state=="idle"and Enum.AnimationPriority.Idle or Enum.AnimationPriority.Movement
  track.Looped=state~="jump";self.tracks[state]=track;self.animations[state]=animation
  delay(6,function()
   if self.closed or self.tracks[state]~=track then return end
   if track.Length==0 then track:Stop(0);track:Destroy();animation:Destroy();self.tracks[state]=nil;self.animations[state]=nil;if onFailure then onFailure(state,"zero length after 6s")end end
  end)
  return track
 end
 function self:step(speed,state,grounded,enabled)
  if self.closed then return end
  local wanted
  if enabled then
   if state==Enum.HumanoidStateType.Jumping then wanted="jump"
   elseif not grounded or state==Enum.HumanoidStateType.Freefall then wanted="fall"
   elseif speed<.8 then wanted="idle"
   elseif speed>14 or(self.active=="run"and speed>12)then wanted="run"
   else wanted="walk"end
  end
  local track=wanted and load(wanted)
  if self.closed then return end
  if wanted~=self.active or track~=self.activeTrack then
   local previous=self.active and self.tracks[self.active]
   if previous and previous.IsPlaying then previous:Stop(.24)end
   self.active=wanted;self.activeTrack=track
   if track then
    local rate=wanted=="walk"and(track.Length>0 and math.clamp(track.Length*speed/12.6,.15,2.4)or .75)or
     wanted=="run"and(track.Length>0 and math.clamp(track.Length*speed/16,.25,2.5)or 1)or 1
    track:Play(.28,1,rate)
   end
  elseif track and(wanted=="walk"or wanted=="run")then
   local stride=wanted=="walk"and 12.6 or 16
   track:AdjustSpeed(track.Length>0 and math.clamp(track.Length*speed/stride,.15,2.5)or .75)
  end
 end
 function self:destroy()
  if self.closed then return end;self.closed=true
  for _,track in pairs(self.tracks)do track:Stop(.15);track:Destroy()end
  for _,animation in pairs(self.animations)do animation:Destroy()end
  table.clear(self.tracks);table.clear(self.animations);self.active=nil;self.activeTrack=nil
 end
 return self
end
return Gait
