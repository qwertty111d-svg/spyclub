-- One scoped presentation owner; late gameplay screens cannot cover a scene.
local Presentation={}
local gameplay={HudGui=true,SpyClubUI=true,SpyLobbyPolishUI=true,SpyCreatorLauncher=true,SpyClubControl=true,SpyPlayerDirectory=true,SpyChatFrontend=true,SpyAULChat=true,SpySafeChat=true,SpyMatchTurnControls=true,MatchTurnControls=true,SpyMatchGuide=true,SpyQuickPlay=true}
local styled={HudGui=true,SpyClubUI=true,SpyLobbyPolishUI=true,SpyClubEntry=true,SpyClubCinematicTour=true,SpyPlayerDirectory=true,SpyClubControl=true,SpyCaseFilmUI=true,SpyMatchUI=true,SpyMatchTurnControls=true,MatchTurnControls=true,MatchUI=true,ClubLoading=true}
function Presentation.start(pg,player)
 local self={connections={},screens={},destroyed=false,writing=false}
 local function mode()
  if player:GetAttribute('SpyEntryPending')==true or player:GetAttribute('SpyEntryActive')==true then return 'entry' end
  if player:GetAttribute('SpyCaseCinematicActive')==true then return 'case' end
  if player:GetAttribute('SpyMatchIntroActive')==true then return 'intro' end
  if player:GetAttribute('SpyPhoneCameraActive')==true then return 'photo' end
  return nil
 end
 local function suppress(n,m)
  if not m then return false end
  if gameplay[n.Name]then return true end
  if n.Name=='SpyPhoneUI'then return m~='photo' end
  if n.Name=='SpyClubEntry'then return m~='entry' end
  if n.Name=='SpyCaseFilmUI'then return m~='case' end
  if n.Name=='SpyClubCinematicTour'then return true end
  return false
 end
 local function write(n,v)self.writing=true;n.Enabled=v;self.writing=false end
 local function refresh()
  local m=mode()
  for n,r in pairs(self.screens)do
   if n.Parent then
    if suppress(n,m)then if not r.held then r.desired=n.Enabled;r.held=true end;write(n,false)
    elseif r.held then r.held=false;write(n,r.desired)end
   end
  end
 end
 local function screenOf(n)
  while n and n~=pg do if n:IsA('ScreenGui')then return n end;n=n.Parent end
 end
 local function typography(n)
  if not(n:IsA('TextLabel')or n:IsA('TextButton')or n:IsA('TextBox'))then return end
  local s=screenOf(n);if not s or not styled[s.Name]then return end
  -- Player content and numeric spacing are never rewritten.
  local heading=n:IsA('TextButton')or n.TextSize>=20 or n.Name:lower():find('title')or n.Name:lower():find('heading')
  n.Font=heading and Enum.Font.BuilderSansBold or Enum.Font.BuilderSansMedium
 end
 local function watch(n)
  typography(n)
  if not n:IsA('ScreenGui')or self.screens[n]then return end
  if not(gameplay[n.Name]or n.Name=='SpyPhoneUI'or n.Name=='SpyClubEntry'or n.Name=='SpyCaseFilmUI'or n.Name=='SpyClubCinematicTour')then return end
  local r={desired=n.Enabled,held=false};self.screens[n]=r
  self.connections[#self.connections+1]=n:GetPropertyChangedSignal('Enabled'):Connect(function()
   if self.writing or self.destroyed then return end
   if r.held then r.desired=n.Enabled;if suppress(n,mode())then write(n,false)end end
  end)
  self.connections[#self.connections+1]=n.Destroying:Connect(function()self.screens[n]=nil end)
  refresh()
 end
 for _,n in ipairs(pg:GetDescendants())do watch(n)end
 self.connections[#self.connections+1]=pg.DescendantAdded:Connect(watch)
 self.connections[#self.connections+1]=pg.ChildAdded:Connect(watch)
 for _,key in ipairs({'SpyEntryPending','SpyEntryActive','SpyCaseCinematicActive','SpyMatchIntroActive','SpyPhoneCameraActive'})do
  self.connections[#self.connections+1]=player:GetAttributeChangedSignal(key):Connect(refresh)
 end
 function self:destroy()
  self.destroyed=true;for _,c in ipairs(self.connections)do c:Disconnect()end
  for n,r in pairs(self.screens)do if n.Parent and r.held then write(n,r.desired)end end
  table.clear(self.screens)
 end
 refresh();return self
end
return Presentation
