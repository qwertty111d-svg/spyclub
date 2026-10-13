-- Small original props supported by existing furniture. No script-bearing marketplace model.
local Set={}
local graphite=Color3.fromRGB(40,46,47);local metal=Color3.fromRGB(132,139,133);local paper=Color3.fromRGB(196,190,164)
local function part(root,name,size,frame,color,mat)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color;p.Material=mat or Enum.Material.Metal;p.MaterialVariant=''
 p.Reflectance=0;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p:SetAttribute('SpyAuthoredSurface',true);p.Parent=root;return p
end
local function prompt(anchor,source,action)
 anchor.CanQuery=true
 local p=Instance.new('ProximityPrompt');p.Name='CasePrompt_'..source;p.ObjectText=source=='archive'and'Архив клуба'or source;p.ActionText=action=='open_archive'and'Открыть'or'Осмотреть'
 p:SetAttribute('SpyCasePrompt',source);p:SetAttribute('SpyCaseAction',action);p.Style=Enum.ProximityPromptStyle.Default
 p.KeyboardKeyCode=Enum.KeyCode.E;p.GamepadKeyCode=Enum.KeyCode.ButtonX;p.HoldDuration=0;p.MaxActivationDistance=8;p.RequiresLineOfSight=false;p.Parent=anchor
 return p
end
local function folder(root,center,name)
 local p=part(root,name or'EvidenceFolder',Vector3.new(1.05,.045,1.42),CFrame.new(center+Vector3.new(0,.0225,0)),Color3.fromRGB(96,110,97),Enum.Material.Fabric)
 part(root,'FileTab',Vector3.new(.30,.022,.18),CFrame.new(center+Vector3.new(-.25,.055,-.68)),Color3.fromRGB(132,142,122),Enum.Material.Fabric)
 part(root,'PaperEdge',Vector3.new(.88,.014,1.23),CFrame.new(center+Vector3.new(.02,.052,.05)),paper,Enum.Material.SmoothPlastic)
 part(root,'FolderClip',Vector3.new(.14,.03,.30),CFrame.new(center+Vector3.new(.25,.074,-.42)),metal)
 return p
end
function Set.lobby(club)
 local old=club:FindFirstChild('SpyCaseArchive');if old then return old end
 local root=Instance.new('Model');root.Name='SpyCaseArchive';root.Parent=club
 -- LibraryTop is 2.85 high and .15 thick; the folder rests on its upper face.
 local p=folder(root,Vector3.new(-38.5,2.925,-24.0),'ArchiveFolder');local entry=prompt(p,'archive','open_archive');entry.Enabled=false
 return root
end
function Set.match(world)
 local old=world:FindFirstChild('SpyMeetingClues');if old then return old end
 local room=world:FindFirstChild('SpyMatchRoom')or world
 local top=room:FindFirstChild('InnerFelt',true)or room:FindFirstChild('Felt',true)or room:FindFirstChild('TableTop',true)
 if not top or not top:IsA('BasePart')then return nil end
 local cf,size=top.CFrame,top.Size
 local y=top.Position.Y+(math.abs(cf.RightVector.Y)*size.X+math.abs(cf.UpVector.Y)*size.Y+math.abs(cf.LookVector.Y)*size.Z)*.5
 local center=Vector3.new(top.Position.X,y,top.Position.Z)
 local root=Instance.new('Model');root.Name='SpyMeetingClues';root.Parent=world
 local tape=center+Vector3.new(-1.65,0,-.25)
 local body=part(root,'RecorderBody',Vector3.new(1.35,.25,.95),CFrame.new(tape+Vector3.new(0,.125,0)),graphite)
 part(root,'RecorderDeck',Vector3.new(1.22,.025,.80),CFrame.new(tape+Vector3.new(0,.2625,0)),metal)
 for _,x in ipairs({-.33,.33})do
  local reel=part(root,'TapeReel',Vector3.new(.035,.46,.46),CFrame.new(tape+Vector3.new(x,.295,-.08))*CFrame.Angles(0,0,math.pi*.5),Color3.fromRGB(73,78,75))
  reel.Shape=Enum.PartType.Cylinder
  local hub=part(root,'ReelHub',Vector3.new(.04,.12,.12),reel.CFrame,metal);hub.Shape=Enum.PartType.Cylinder
  for i=1,3 do
   local angle=i*math.pi*2/3
   part(root,'ReelSpoke',Vector3.new(.024,.016,.13),CFrame.new(tape+Vector3.new(x+math.sin(angle)*.115,.32,-.08+math.cos(angle)*.115))*CFrame.Angles(0,angle,0),graphite)
  end
 end
 for i=1,5 do part(root,'RecorderKey',Vector3.new(.12,.028,.12),CFrame.new(tape+Vector3.new(-.42+i*.145,.289,.28)),i==5 and Color3.fromRGB(136,66,49)or graphite)end
 prompt(body,'tape','inspect_action')
 local phone=center+Vector3.new(1.65,0,-.2)
 local base=part(root,'PhoneBase',Vector3.new(1.13,.23,.83),CFrame.new(phone+Vector3.new(0,.115,0)),graphite)
 local dial=part(root,'PhoneDial',Vector3.new(.023,.48,.48),CFrame.new(phone+Vector3.new(0,.25,.11))*CFrame.Angles(0,0,math.pi*.5),metal);dial.Shape=Enum.PartType.Cylinder
 for i=1,10 do
  local angle=i*math.pi*2/10;local d=part(root,'DialHole',Vector3.new(.025,.063,.063),CFrame.new(phone+Vector3.new(math.sin(angle)*.172,.268,.11+math.cos(angle)*.172))*CFrame.Angles(0,0,math.pi*.5),graphite);d.Shape=Enum.PartType.Cylinder
 end
 for _,x in ipairs({-.43,.43})do
  part(root,'HandsetSupport',Vector3.new(.07,.14,.11),CFrame.new(phone+Vector3.new(x,.30,-.27)),metal)
  part(root,'HandsetEnd',Vector3.new(.24,.19,.28),CFrame.new(phone+Vector3.new(x,.455,-.27)),graphite)
 end
 part(root,'HandsetBridge',Vector3.new(.85,.10,.13),CFrame.new(phone+Vector3.new(0,.47,-.27)),graphite)
 for i=1,7 do part(root,'CordLoop',Vector3.new(.04,.04,.07),CFrame.new(phone+Vector3.new(.62,.026,-.32+i*.09)),graphite)end
 prompt(base,'phone','inspect_action')
 prompt(folder(root,center+Vector3.new(0,0,1.40)),'folder','inspect_action')
 return root
end
return Set
