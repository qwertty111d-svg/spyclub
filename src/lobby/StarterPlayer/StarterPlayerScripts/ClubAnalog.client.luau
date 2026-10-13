-- Subtle analogue texture under every interactive ScreenGui, never a camera or input effect.
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local Gui=game:GetService("GuiService")
local player=Players.LocalPlayer
local pg=player:FindFirstChildOfClass("PlayerGui")or player:WaitForChild("PlayerGui",8)
if not pg then return end
local settings
pcall(function()settings=UserSettings():GetService("UserGameSettings")end)
local previous=pg:FindFirstChild("ClubAnalog");if previous then previous:Destroy()end
local screen=Instance.new("ScreenGui");screen.Name="ClubAnalog";screen.DisplayOrder=-20;screen.IgnoreGuiInset=true;screen.ResetOnSpawn=false;screen.Parent=pg
local function rect(name)
 local f=Instance.new("Frame");f.Name=name;f.BorderSizePixel=0;f.Active=false;f.Selectable=false;f.BackgroundColor3=Color3.fromRGB(224,220,201);f.Parent=screen;return f
end
local grain={};local touch=Input.TouchEnabled
for i=1,touch and 8 or 48 do
 local f=rect("Grain");f.Size=UDim2.fromOffset(i%3==0 and 2 or 1,1);f.BackgroundTransparency=.92;grain[#grain+1]=f
end
local scans={}
local scanCount=touch and 12 or 32
for i=1,scanCount do local f=rect("Scanline");f.Size=UDim2.new(1,0,0,1);f.Position=UDim2.fromScale(0,i/(scanCount+1));f.BackgroundColor3=Color3.fromRGB(12,14,14);f.BackgroundTransparency=.989;scans[#scans+1]=f end
local strip=rect("Interference");strip.Size=UDim2.new(1,0,0,2);strip.BackgroundTransparency=.94;strip.Visible=false
local reduced=false
local function allowed()
 if player:GetAttribute("SpyEffects")==false or player:GetAttribute("SpyReducedMotion")==true then return false end
 if settings then
  local q=settings.SavedQualityLevel
  if q~=Enum.SavedQualitySetting.Automatic and q.Value<=3 then return false end
 end
 return true
end
local function refresh()screen.Enabled=allowed();if not screen.Enabled then strip.Visible=false end end
local links={player:GetAttributeChangedSignal("SpyEffects"):Connect(refresh),player:GetAttributeChangedSignal("SpyReducedMotion"):Connect(refresh)}
if settings then links[#links+1]=settings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(refresh)end
local elapsed,clock,nextStrip,stripUntil=0,0,47,0
links[#links+1]=Run.Heartbeat:Connect(function(dt)
 clock+=dt;elapsed+=dt
 if strip.Visible and clock>=stripUntil then strip.Visible=false end
 if not screen.Enabled then return end
 if elapsed>=(touch and 1/3 or 1/6)then
  elapsed=0
  for _,f in ipairs(grain)do f.Position=UDim2.fromScale(math.random(),math.random())end
 end
 if clock>=nextStrip then
  nextStrip=clock+38+math.random()*24
  -- Never put a tracking error over questions, voting, chat or a focused admin input.
  local inMenu=player:GetAttribute("SpyEntryActive")==true
  if inMenu and not Input:GetFocusedTextBox()and not Gui.MenuIsOpen then
   strip.Position=UDim2.fromScale(0,.22+math.random()*.55);strip.Visible=true;stripUntil=clock+.09
  end
 end
end)
refresh()
script.Destroying:Connect(function()for _,c in ipairs(links)do c:Disconnect()end;screen:Destroy()end)
