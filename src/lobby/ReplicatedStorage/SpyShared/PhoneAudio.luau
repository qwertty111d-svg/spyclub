-- Verified Creator Store effects; optional audio never gates input or loading.
local Audio={}
function Audio.new(player)
 local self={lastEffect=-100,quiet=false,ringtone='soft',sounds={},generation=0,dead=false}
 local Sound=game:GetService('SoundService')
 local ids={soft=9117306132,classic=9117304268,key=9113649346,tap=113397864512278,open=113397864512278,message=9113649346,sent=113397864512278,shutter=9113678333}
 local function volume()local v=tonumber(player:GetAttribute('SpySfxVolume'))or tonumber(player:GetAttribute('SpySFXVolume'))or .7;return math.clamp(v,0,1)*.3 end
 for key,id in pairs(ids)do
  local s=Instance.new('Sound');s.Name='Phone_'..key;s.SoundId='rbxassetid://'..id;s.Volume=volume();s:SetAttribute('SpyAudioCategory','SFX');s.Parent=Sound;self.sounds[key]=s
 end
 function self:stopRing()self.generation+=1;for _,key in ipairs({'soft','classic'})do self.sounds[key]:Stop()end end
 function self:effect(key)
  if self.dead or self.quiet then return end
  if key~='soft'and key~='classic'then if os.clock()-self.lastEffect<.08 then return end;self.lastEffect=os.clock()end
  local s=self.sounds[key]or self.sounds.key;s.Volume=volume()*(key=='tap'and .38 or key=='open'and .5 or .65);s.PlaybackSpeed=key=='open'and .85 or key=='sent'and 1.15 or 1;s.TimePosition=0;s:Play()
 end
 function self:ring(enabled)
  self:stopRing();if self.dead or self.quiet or not enabled then return end
  local generation=self.generation
  local function beat()
   if self.dead or self.quiet or self.generation~=generation then return end
   self:effect(self.ringtone);task.delay(4,beat)
  end;beat()
 end
 function self:set(key,value)
  if key=='quiet'then self.quiet=value==true;self:stopRing()
  elseif key=='ringtone'then self.ringtone=value=='classic'and'classic'or'soft';self:stopRing()
  elseif key=='preview'then self:effect(self.ringtone)end
 end
 function self:destroy()self:stopRing();self.dead=true;for _,s in pairs(self.sounds)do s:Destroy()end end
 return self
end
return Audio
