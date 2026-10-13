-- Slow decorative motion only; no strobing, gameplay physics or camera ownership.
local Run=game:GetService("RunService")
local player=game:GetService("Players").LocalPlayer
local records={};local count=0
local function allowed()return player:GetAttribute("SpyEffects")~=false and player:GetAttribute("SpyReducedMotion")~=true end
local function restore(n,r)
 if not n.Parent then return end
 if r.kind=="sway"then n:PivotTo(r.base)
 else n.Transparency=r.alpha;for l,b in pairs(r.lights)do if l.Parent then l.Brightness=b end end end
end
local function add(n)
 if records[n]or count>=8 then return end
 local r
 if n:IsA("Model")and n:GetAttribute("ClubSway")==true then r={kind="sway",base=n:GetPivot()}
 elseif n:IsA("BasePart")and n:GetAttribute("ClubPulse")==true then
  r={kind="pulse",alpha=n.Transparency,lights={}}
  for _,l in ipairs(n:GetChildren())do if l:IsA("Light")then r.lights[l]=l.Brightness end end
 end
 if r then records[n]=r;count+=1;r.phase=count*1.9 end
end
for _,n in ipairs(workspace:GetDescendants())do add(n)end
local added=workspace.DescendantAdded:Connect(add)
local clock,elapsed=0,0
local function refresh()
 for n,r in pairs(records)do if not allowed()then restore(n,r)end end
end
local a=player:GetAttributeChangedSignal("SpyEffects"):Connect(refresh)
local b=player:GetAttributeChangedSignal("SpyReducedMotion"):Connect(refresh)
local step=Run.Heartbeat:Connect(function(dt)
 clock+=dt;elapsed+=dt;if elapsed<.1 then return end;elapsed=0
 for n,r in pairs(records)do
  if not n.Parent then records[n]=nil;count-=1
  elseif allowed()then
   local value=math.sin(clock*.48+r.phase)
   if r.kind=="sway"then n:PivotTo(r.base*CFrame.Angles(0,0,value*.006))
   else
    n.Transparency=math.clamp(r.alpha+value*.012,0,.45)
    for l,base in pairs(r.lights)do if l.Parent then l.Brightness=base*(.985+.015*value)end end
   end
  end
 end
end)
script.Destroying:Connect(function()
 added:Disconnect();a:Disconnect();b:Disconnect();step:Disconnect()
 for n,r in pairs(records)do restore(n,r)end;table.clear(records)
end)
