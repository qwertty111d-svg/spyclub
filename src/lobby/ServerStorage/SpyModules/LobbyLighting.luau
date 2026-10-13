-- Restrained warm fixture light with a cool exterior and preserved dark tones. Every local emitter belongs to a visible fixture.
local LobbyLighting={}
local watching=setmetatable({},{__mode="k"})
local function inSet(owner, club, name)
 local current=owner.Parent
 while current and current~=club do
  if current.Parent==club and current.Name==name then return true end
  current=current.Parent
 end
 return false
end
local interiorLenses={SconceLens=true,SconceUpperLens=true,CornerLens=true,CornerUpperLens=true,
 CornerLowerLens=true,WindowLightLens=true,PictureLampLens=true}
local portraitLenses={LampDiffuser="LampLight",PortraitKeyDiffuser="PortraitKeyLight",
 PortraitRimDiffuser="PortraitRimLight",CeilingDiffuser="CeilingLight"}
local entranceLenses={EntranceWarmLens="EntryWarmLight",EntranceFaceLens="EntryFaceLight",CoolThresholdLens="EntryCoolLight"}
local archiveLenses={CafeLampDiffuser=true,DoorLampDiffuser=true,MeetingDiffuser=true,BarArchiveNeon=true,BoardLampDiffuser=true}
local shelfLenses={["ShelfLight4.0"]=true,["ShelfLight7.0"]=true,["ShelfLight10.0"]=true}
local function validOwner(light, club)
 local owner=light.Parent
 if owner and owner:IsA("Attachment")then owner=owner.Parent end
 if not owner or not owner:IsA("BasePart") or owner.Transparency>=.7 or not owner:IsDescendantOf(club) then return false end
 -- Attributes or Neon alone do not authorize an invisible/floating emitter.
 -- Exact lens/light identities must also belong to their named presentation set.
 local name=owner.Name
 if owner.Parent==club:FindFirstChild("FeedbackDesk") and name=="ReadingLampDiffuser" then
  return light.Name=="FeedbackWarmLight" and light:IsA("SurfaceLight")
 end
 if owner:GetAttribute("ClubFixture")~=true or owner.Material~=Enum.Material.Neon then return false end
 if inSet(owner,club,"ClubEntrance") then
  return entranceLenses[name]==light.Name and light:IsA("SurfaceLight")
 end
 if inSet(owner,club,"ClubInterior") then
  if name=="LoungeLampBulb" then return light.Name=="BulbGlow" and light:IsA("PointLight") end
  if name=="DisplayLens" then return light.Name=="DisplayAccent" and light:IsA("SurfaceLight") end
  local known=interiorLenses[name] or name:match("^Aisle%d+Lens$") or name:match("^Side%d+Lens$") or
   name:match("^Bar%d+Lens$") or name:match("^Corridor%d+Lens$")
  return known~=nil and known~=false and light.Name=="FixtureEmission" and light:IsA("SurfaceLight")
 end
 if owner.Parent==club and shelfLenses[name] then
  return light.Name=="FixtureEmission" and light:IsA("SurfaceLight")
 end
 if inSet(owner,club,"NocturneLounge") then
  return portraitLenses[name]==light.Name and (light:IsA("SurfaceLight") or light:IsA("SpotLight"))
 end
 if inSet(owner,club,"ClubArchive") then
  return archiveLenses[name]==true and light.Name=="ArchiveLight" and (light:IsA("SurfaceLight") or light:IsA("SpotLight"))
 end
 if inSet(owner,club,"RainWindows") then
  if name=="WindowStreetLens" then
   return (light.Name=="StreetSpill" or light.Name=="CanopyPavement") and light:IsA("SurfaceLight")
  end
  -- NightStreetScene is nested inside the real west-window exterior.
  local street=owner:FindFirstAncestor("NightStreet")
  local exterior=street and street.Parent
  local allowed=name=="ShopWindow" or name=="FacadeLampLens" or name=="LampLens"
  return allowed and light.Name=="FixtureLight" and light:IsA("SurfaceLight") and
   exterior and exterior.Name=="Exterior" and exterior.Parent==club:FindFirstChild("RainWindows")
 end
 return false
end
function LobbyLighting.audit(root)
 local club=root.Name=="SpyClub" and root or root:FindFirstChild("SpyClub")
 if not club then return {kept=0,removed=0} end
 local report={kept=0,removed=0}
 for _,light in ipairs(club:GetDescendants())do if light:IsA("Light") then
  if validOwner(light,club) then report.kept+=1 else
   report.removed+=1;light.Enabled=false;light:Destroy()
  end
 end end
 club:SetAttribute("LightingAuditKept",report.kept)
 club:SetAttribute("LightingAuditRemoved",report.removed)
 return report
end
function LobbyLighting.apply()
 local l=game:GetService("Lighting")
 l.ClockTime=22.4;l.Brightness=1.55;l.ExposureCompensation=.05;l.GlobalShadows=true;l.ShadowSoftness=.7
 l.EnvironmentDiffuseScale=.64;l.EnvironmentSpecularScale=.24
 l.ColorShift_Top=Color3.new(0,0,0);l.ColorShift_Bottom=Color3.new(0,0,0)
 l.Ambient=Color3.fromRGB(80,84,89);l.OutdoorAmbient=Color3.fromRGB(54,67,84);l.FogEnd=100000
 pcall(function()l.LightingStyle=Enum.LightingStyle.Realistic;l.PrioritizeLightingQuality=true end)
 local function effect(class,name)
  local found=l:FindFirstChild(name)
  if found and not found:IsA(class)then found:Destroy();found=nil end
  if not found then found=Instance.new(class);found.Name=name;found.Parent=l end
  return found
 end
 local air=effect("Atmosphere","ClubAtmosphere")
 air.Density=.02;air.Offset=.1;air.Color=Color3.fromRGB(160,177,190)
 air.Decay=Color3.fromRGB(83,89,101);air.Haze=.11;air.Glare=0
 local bloom=effect("BloomEffect","ClubBloom");bloom.Enabled=true;bloom.Intensity=.06;bloom.Size=14;bloom.Threshold=2.2
 local sun=effect("SunRaysEffect","ClubSunRays");sun.Enabled=false;sun.Intensity=0;sun.Spread=.65
 local grade=effect("ColorCorrectionEffect","ClubGrade")
 grade.Enabled=true;grade.Brightness=.004;grade.Contrast=.045;grade.Saturation=-.06;grade.TintColor=Color3.fromRGB(255,250,244)
 for _,fx in ipairs(l:GetChildren())do
  if fx:IsA("BlurEffect") or fx:IsA("DepthOfFieldEffect") or fx:IsA("ColorGradingEffect") or
   (fx:IsA("ColorCorrectionEffect")and fx~=grade) or (fx:IsA("BloomEffect")and fx~=bloom) or (fx:IsA("SunRaysEffect")and fx~=sun)then fx.Enabled=false end
 end
 local club=workspace:FindFirstChild("SpyClub");if not club then return end
 for _,name in ipairs({"WardrobeFill","AisleLuminaires"})do local old=club:FindFirstChild(name);if old then old:Destroy()end end
 -- Remove the authored 0.16-stud point emitters, rather than recoloring their light pools.
 LobbyLighting.audit(club)
 if not watching[club]then
  watching[club]=club.DescendantAdded:Connect(function(n)
   if n:IsA("Light") then task.defer(function()
    if n.Parent and not validOwner(n,club)then n.Enabled=false;n:Destroy()end
   end)end
  end)
  club.Destroying:Connect(function()if watching[club]then watching[club]:Disconnect();watching[club]=nil end end)
 end
 -- Presentation is deliberately deferred; a failed asset or optional scene cannot block boot.
 task.defer(function()
  for _,name in ipairs({"LobbyInterior","LobbyRainWindows","ClubDossierSet","ClubCinematicSet"})do
   local module=script.Parent:FindFirstChild(name)
   if module then
    local ok,err=pcall(function()require(module).apply(club)end)
    if not ok then club:SetAttribute(name.."Error",tostring(err));warn("["..name.."] "..tostring(err))end
   end
  end
  local material=script.Parent:FindFirstChild("LobbyInterior")
  if material then pcall(function()for _,p in ipairs(club:GetDescendants())do require(material).material(p)end end)end
  LobbyLighting.audit(club)
 end)
end
return LobbyLighting
