-- SPY CLUB PREMIUM SHOP V1 :: Preview3D
-- SPY_COSMETICS_V1: Preview3D
local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local Art=require(script.Parent.Art)
local Preview3D={}
Preview3D.CASE_REVEAL_TIME=3.6
local C={
	dark=Color3.fromRGB(20,25,27), wood=Color3.fromRGB(74,47,36), wood2=Color3.fromRGB(112,72,48),
	brass=Color3.fromRGB(205,158,78), ivory=Color3.fromRGB(235,225,204), mint=Color3.fromRGB(100,218,172),
	velvet=Color3.fromRGB(62,28,41), black=Color3.fromRGB(10,12,14), steel=Color3.fromRGB(87,95,97),
	red=Color3.fromRGB(156,55,61), blue=Color3.fromRGB(85,129,165)
}
local function hatBand(item)
	local band=item and item.wearable and item.wearable.band
	local shades={
		forest=Color3.fromRGB(51,82,68), navy=Color3.fromRGB(56,76,106),
		crimson=Color3.fromRGB(106,40,53), champagne=Color3.fromRGB(169,138,92),
		violet=Color3.fromRGB(83,60,105),
	}
	return shades[band] or (item and item.color and Color3.fromRGB(item.color[1],item.color[2],item.color[3])) or Color3.fromRGB(159,130,90)
end
local function part(parent,name,size,cf,color,material,shape,className)
	local p=Instance.new(className or "Part")
	p.Name,p.Size,p.CFrame,p.Color=name,size,cf,color
	p.Material=material or Enum.Material.SmoothPlastic
	p.Anchored,p.CanCollide,p.CastShadow=true,false,true
	p.TopSurface,p.BottomSurface=Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
	if shape and p:IsA("Part") then p.Shape=shape end
	p.Parent=parent
	return p
end
local function trim(parent,pos,size,color)
	return part(parent,"Trim",size,CFrame.new(pos),color,Enum.Material.Metal)
end
local STAND_MODEL_BY_CASE={
	atelier="AtelierCase",
	midnight="ClassicCase",
	velvet="SilverCase",
	blackvault="GoldCase",
}
local function findShowcaseCase(modelName)
	if not modelName then return nil end
	local source=workspace:FindFirstChild(modelName)
	if source then return source end
	local club=workspace:FindFirstChild("SpyClub")
	return club and club:FindFirstChild(modelName,true) or nil
end
local function decorateStandCase(clone,caseId)
	local cf,size=clone:GetBoundingBox()
	local accent=caseId=="blackvault" and C.brass or (caseId=="velvet" and C.ivory or C.brass)
	local glow=part(clone,"StandRevealGlow",Vector3.new(math.max(1,size.X*.72),.05,math.max(1,size.Z*.62)),cf*CFrame.new(0,-size.Y*.48,0),accent,Enum.Material.Neon)
	glow.Transparency=1
	local light=Instance.new("PointLight")
	light.Name="RevealLight";light.Color=accent;light.Brightness=0;light.Range=math.max(9,size.Magnitude*1.2);light.Parent=glow
end
local function cloneStandCase(parent,caseId)
	local modelName=STAND_MODEL_BY_CASE[caseId]
	local source=findShowcaseCase(modelName)
	if not source then return nil end
	local wasArchivable=source.Archivable
	source.Archivable=true
	local clone=source:Clone()
	source.Archivable=wasArchivable
	if not clone then return nil end
	clone.Name="CasePreview"
	clone:SetAttribute("StandModel",modelName)
	for _,descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("ProximityPrompt")
			or descendant:IsA("Script")
			or descendant:IsA("LocalScript")
			or descendant:IsA("ModuleScript")
		then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored=true
			descendant.CanCollide=false
			descendant.CanTouch=false
			descendant.CanQuery=false
		end
	end
	clone.Parent=parent
	decorateStandCase(clone,caseId)
	return clone
end
local function caseModel(parent,caseId)
	local m=Instance.new("Model"); m.Name="CasePreview"; m.Parent=parent
	local baseColor=caseId=="blackvault" and C.black or (caseId=="velvet" and C.velvet or C.wood)
	local accent=caseId=="blackvault" and C.mint or C.brass
	local material=caseId=="midnight" and Enum.Material.Wood or Enum.Material.Fabric
	local lining=caseId=="velvet" and Color3.fromRGB(98,43,62) or Color3.fromRGB(27,45,40)
	-- A hollow box: opening reveals a lined interior, not the top of a solid block.
	part(m,"Base",Vector3.new(5.1,.3,3.45),CFrame.new(0,-.93,0),baseColor,material)
	part(m,"Lining",Vector3.new(4.7,.12,3.02),CFrame.new(0,-.71,0),lining,Enum.Material.Fabric)
	for _,x in ipairs({-2.43,2.43}) do
		part(m,"Side",Vector3.new(.24,1.87,3.45),CFrame.new(x,.15,0),baseColor,material)
		part(m,"Rim",Vector3.new(.27,.09,3.5),CFrame.new(x,1.08,0),accent,Enum.Material.Metal)
	end
	for _,z in ipairs({-1.6,1.6}) do
		part(m,"Face",Vector3.new(4.65,1.87,.25),CFrame.new(0,.15,z),baseColor,material)
		part(m,"Rim",Vector3.new(5.12,.09,.2),CFrame.new(0,1.08,z),accent,Enum.Material.Metal)
	end
	local lid=Instance.new("Model"); lid.Name="LidAssembly"; lid.Parent=m
	part(lid,"Lid",Vector3.new(5.1,.42,3.45),CFrame.new(0,1.34,0),baseColor,material)
	part(lid,"Inside",Vector3.new(4.7,.04,3.06),CFrame.new(0,1.115,0),lining,Enum.Material.Fabric)
	for _,x in ipairs({-1.78,1.78}) do
		for _,z in ipairs({-1.75,1.75}) do
			part(m,"Band",Vector3.new(.18,1.82,.06),CFrame.new(x,.16,z),accent,Enum.Material.Metal)
		end
		part(lid,"LidBand",Vector3.new(.18,.46,3.5),CFrame.new(x,1.34,0),accent,Enum.Material.Metal)
		for _,y in ipairs({-.52,.83}) do
			part(m,"Rivet",Vector3.new(.12,.12,.07),CFrame.new(x,y,-1.8),C.ivory,Enum.Material.Metal,Enum.PartType.Ball)
		end
	end
	for _,x in ipairs({-2.31,2.31}) do
		for _,z in ipairs({-1.5,1.5}) do
			part(m,"Corner",Vector3.new(.26,.2,.26),CFrame.new(x,-.82,z),accent,Enum.Material.Metal)
			part(lid,"Corner",Vector3.new(.26,.18,.26),CFrame.new(x,1.57,z),accent,Enum.Material.Metal)
		end
	end
	for i,x in ipairs({-.9,.9}) do
		local lock=Instance.new("Model"); lock.Name="Lock"..i; lock.Parent=m
		part(lock,"Latch",Vector3.new(.42,.62,.14),CFrame.new(x,.91,-1.84),accent,Enum.Material.Metal)
		part(lock,"Keyhole",Vector3.new(.08,.17,.04),CFrame.new(x,.85,-1.93),C.dark)
		lock.WorldPivot=CFrame.new(x,1.06,-1.84)
		part(m,"Hinge",Vector3.new(.55,.18,.18),CFrame.new(x,1.1,1.78),accent,Enum.Material.Metal,Enum.PartType.Cylinder)
	end
	-- Handle and emblem face the camera (negative Z).
	part(m,"Handle",Vector3.new(1.35,.16,.18),CFrame.new(0,-.2,-2.04),C.steel,Enum.Material.Metal)
	for _,x in ipairs({-.6,.6}) do
		part(m,"HandleMount",Vector3.new(.15,.36,.22),CFrame.new(x,-.05,-1.93),accent,Enum.Material.Metal)
	end
	local sealCF=CFrame.new(0,.6,-1.81)*CFrame.Angles(0,math.rad(90),0)
	local seal=part(m,"Seal",Vector3.new(.07,.52,.52),sealCF,accent,Enum.Material.Metal,Enum.PartType.Cylinder)
	part(m,"CrestInset",Vector3.new(.045,.25,.25),CFrame.new(0,.6,-1.87)*CFrame.Angles(0,math.rad(90),0),baseColor)
	local revealGlow=part(m,"RevealGlow",Vector3.new(3.4,.08,2.15),CFrame.new(0,-.56,0),accent,Enum.Material.Neon)
	revealGlow.Transparency=1
	local revealLight=Instance.new("PointLight")
	revealLight.Name="RevealLight";revealLight.Color=accent;revealLight.Brightness=0;revealLight.Range=11;revealLight.Parent=revealGlow
	seal:SetAttribute("CaseSeal",true)
	if caseId=="blackvault" then
		part(m,"VaultGlow",Vector3.new(3.1,.04,.06),CFrame.new(0,1.05,-1.8),C.mint,Enum.Material.Neon)
	end
	lid.WorldPivot=CFrame.new(0,1.11,1.68)
	return m
end
local function itemModel(parent,item)
	local m=Instance.new("Model"); m.Name="ItemPreview"; m.Parent=parent
	local color=item and item.color and Color3.fromRGB(item.color[1],item.color[2],item.color[3]) or C.mint
	local kind=item and item.kind or "card"
	local id=item and item.id or ""
	local art=item and item.art or ""
	if id=="dockGift" then
		part(m,"GiftBox",Vector3.new(3.4,2.6,3),CFrame.new(0,-.2,0),Color3.fromRGB(158,62,93),Enum.Material.SmoothPlastic)
		part(m,"GiftLid",Vector3.new(3.65,.45,3.2),CFrame.new(0,1.27,0),Color3.fromRGB(205,95,120),Enum.Material.SmoothPlastic)
		part(m,"RibbonFront",Vector3.new(.48,3.15,3.24),CFrame.new(0,.1,0),C.brass,Enum.Material.Metal)
		part(m,"RibbonTop",Vector3.new(3.68,.08,.46),CFrame.new(0,1.54,0),C.brass,Enum.Material.Metal)
		for _,x in ipairs({-.48,.48}) do part(m,"Bow",Vector3.new(1.05,.65,.55),CFrame.new(x,1.88,0)*CFrame.Angles(0,0,x*.55),C.brass,Enum.Material.Metal) end
	elseif id=="dockSettings" then
		local steel=Color3.fromRGB(151,179,194)
		local axis=CFrame.Angles(0,math.rad(90),0)
		part(m,"Gear",Vector3.new(.58,2.9,2.9),axis,steel,Enum.Material.Metal,Enum.PartType.Cylinder)
		for i=1,8 do
			local a=i*math.pi/4
			part(m,"Tooth",Vector3.new(.68,.86,.64),CFrame.new(math.sin(a)*1.5,math.cos(a)*1.5,0)*CFrame.Angles(0,0,-a),steel,Enum.Material.Metal)
		end
		part(m,"Inset",Vector3.new(.65,1.55,1.55),CFrame.new(0,0,-.07)*axis,C.dark,Enum.Material.SmoothPlastic,Enum.PartType.Cylinder)
		part(m,"Hub",Vector3.new(.7,.77,.77),CFrame.new(0,0,-.12)*axis,C.brass,Enum.Material.Metal,Enum.PartType.Cylinder)
	elseif id=="dockWardrobe" then
		local hat=Color3.fromRGB(151,109,70)
		part(m,"Brim",Vector3.new(.25,4.4,3.7),CFrame.Angles(0,0,math.rad(90)),hat,Enum.Material.Fabric,Enum.PartType.Cylinder)
		part(m,"Crown",Vector3.new(1.65,2.9,2.55),CFrame.new(0,.9,0)*CFrame.Angles(0,0,math.rad(90)),hat,Enum.Material.Fabric,Enum.PartType.Cylinder)
		part(m,"Ribbon",Vector3.new(.38,3,2.65),CFrame.new(0,.43,0)*CFrame.Angles(0,0,math.rad(90)),Color3.fromRGB(70,116,135),Enum.Material.Fabric,Enum.PartType.Cylinder)
		part(m,"Pin",Vector3.new(.42,.44,.15),CFrame.new(.45,.43,-1.37),C.brass,Enum.Material.Metal)
	elseif art=="fedora" then
		part(m,"Brim",Vector3.new(.18,4.2,3.5),CFrame.Angles(0,0,math.rad(90)),C.black,Enum.Material.Fabric,Enum.PartType.Cylinder)
		part(m,"Crown",Vector3.new(1.55,2.7,2.35),CFrame.new(0,.86,0)*CFrame.Angles(0,0,math.rad(90)),C.dark,Enum.Material.Fabric,Enum.PartType.Cylinder)
		part(m,"Band",Vector3.new(.28,2.88,2.52),CFrame.new(0,.38,0)*CFrame.Angles(0,0,math.rad(90)),hatBand(item),Enum.Material.Fabric,Enum.PartType.Cylinder)
		part(m,"Pin",Vector3.new(.18,.45,.12),CFrame.new(.95,.38,-1.18),C.brass,Enum.Material.Metal)
	elseif art=="tophat" then
		part(m,"Brim",Vector3.new(.18,4.15,3.65),CFrame.Angles(0,0,math.rad(90)),C.black,Enum.Material.Fabric,Enum.PartType.Cylinder)
		part(m,"Crown",Vector3.new(2.45,2.75,2.55),CFrame.new(0,1.24,0)*CFrame.Angles(0,0,math.rad(90)),C.dark,Enum.Material.Fabric,Enum.PartType.Cylinder)
		part(m,"Band",Vector3.new(.38,2.92,2.72),CFrame.new(0,.54,0)*CFrame.Angles(0,0,math.rad(90)),hatBand(item),Enum.Material.Fabric,Enum.PartType.Cylinder)
	elseif art=="glasses" then
		local frame=(item.wearable and (item.wearable.style=="noir" or item.wearable.style=="interrogation"))
			and C.black or Color3.fromRGB(61,53,46)
		for _,x in ipairs({-1.05,1.05}) do
			local lens=part(m,"Lens",Vector3.new(1.68,1.18,.12),CFrame.new(x,0,0),color,Enum.Material.Glass); lens.Transparency=.35
			part(m,"Top",Vector3.new(1.88,.12,.16),CFrame.new(x,.66,-.04),frame,Enum.Material.Metal)
			part(m,"Bottom",Vector3.new(1.88,.12,.16),CFrame.new(x,-.66,-.04),frame,Enum.Material.Metal)
			part(m,"Left",Vector3.new(.12,1.26,.16),CFrame.new(x-.88,0,-.04),frame,Enum.Material.Metal)
			part(m,"Right",Vector3.new(.12,1.26,.16),CFrame.new(x+.88,0,-.04),frame,Enum.Material.Metal)
		end
		part(m,"Bridge",Vector3.new(.48,.12,.16),CFrame.new(0,.08,-.04),frame,Enum.Material.Metal)
	elseif art=="tie" then
		local fabric=item.wearable and item.wearable.accent=="burgundy" and Color3.fromRGB(92,24,40) or C.black
		part(m,"Knot",Vector3.new(.72,.72,.32),CFrame.new(0,1.35,0)*CFrame.Angles(0,0,math.rad(45)),fabric,Enum.Material.Fabric)
		part(m,"Blade",Vector3.new(.82,2.5,.26),CFrame.new(0,-.15,0),fabric,Enum.Material.Fabric)
		part(m,"Tip",Vector3.new(.72,.72,.26),CFrame.new(0,-1.65,0)*CFrame.Angles(0,0,math.rad(45)),fabric,Enum.Material.Fabric)
		if item.wearable and item.wearable.accent=="founder" then
			part(m,"TieBar",Vector3.new(.95,.10,.10),CFrame.new(0,.39,-.20),C.brass,Enum.Material.Metal)
		end
	elseif art=="gloves" then
		for _,x in ipairs({-1.05,1.05}) do
			part(m,"Cuff",Vector3.new(1.1,.62,.88),CFrame.new(x,-.85,0),color,Enum.Material.Fabric)
			part(m,"Palm",Vector3.new(1.02,1.35,.82),CFrame.new(x,.15,0),C.dark,Enum.Material.Fabric)
			for finger=1,4 do
				part(m,"Finger",Vector3.new(.18,.78,.22),CFrame.new(x-.33+(finger-1)*.22,1.16,0),C.dark,Enum.Material.Fabric)
			end
		end
	elseif art=="holster" then
		part(m,"Torso",Vector3.new(3.35,4.15,1.7),CFrame.new(),Color3.fromRGB(27,28,31),Enum.Material.Fabric)
		local leather=Color3.fromRGB(83,52,37)
		part(m,"ShoulderStrap",Vector3.new(.30,4.45,.18),CFrame.new(-.85,.05,-.92)*CFrame.Angles(0,0,math.rad(-13)),leather,Enum.Material.Fabric)
		part(m,"ChestStrap",Vector3.new(2.65,.28,.18),CFrame.new(0,-.42,-.94)*CFrame.Angles(0,0,math.rad(8)),leather,Enum.Material.Fabric)
		part(m,"Holster",Vector3.new(.72,1.22,.36),CFrame.new(1.02,-1.05,-1.02)*CFrame.Angles(0,0,math.rad(-8)),Color3.fromRGB(58,37,29),Enum.Material.Fabric)
		part(m,"Buckle",Vector3.new(.32,.22,.08),CFrame.new(-.25,-.42,-1.06),C.brass,Enum.Material.Metal)
	elseif art=="vest" then
		part(m,"Torso",Vector3.new(3.4,4.2,1.8),CFrame.new(),Color3.fromRGB(29,34,32),Enum.Material.Fabric)
		part(m,"Shirt",Vector3.new(1.0,3.55,.16),CFrame.new(0,.08,-.99),C.ivory,Enum.Material.Fabric)
		for index=1,4 do part(m,"Button",Vector3.new(.16,.16,.08),CFrame.new(0,.72-index*.5,-1.11),C.brass,Enum.Material.Metal,Enum.PartType.Ball) end
	elseif art=="tuxedo" then
		part(m,"Torso",Vector3.new(3.4,4.2,1.8),CFrame.new(),Color3.fromRGB(45,22,39),Enum.Material.Fabric)
		part(m,"Shirt",Vector3.new(1.0,3.55,.16),CFrame.new(0,.08,-.99),C.ivory,Enum.Material.Fabric)
		part(m,"LapelL",Vector3.new(.68,3.0,.16),CFrame.new(-.68,.05,-1.12)*CFrame.Angles(0,0,math.rad(-12)),C.black,Enum.Material.Fabric)
		part(m,"LapelR",Vector3.new(.68,3.0,.16),CFrame.new(.68,.05,-1.12)*CFrame.Angles(0,0,math.rad(12)),C.black,Enum.Material.Fabric)
		part(m,"PocketSquare",Vector3.new(.55,.28,.12),CFrame.new(.78,.25,-1.22)*CFrame.Angles(0,0,math.rad(-8)),color,Enum.Material.Fabric)
	elseif art=="director" then
		part(m,"Torso",Vector3.new(3.4,4.2,1.8),CFrame.new(),Color3.fromRGB(19,20,23),Enum.Material.Fabric)
		part(m,"Shirt",Vector3.new(1.0,3.55,.16),CFrame.new(0,.08,-.99),C.ivory,Enum.Material.Fabric)
		part(m,"LapelL",Vector3.new(.72,3.05,.16),CFrame.new(-.70,.04,-1.12)*CFrame.Angles(0,0,math.rad(-12)),C.black,Enum.Material.Fabric)
		part(m,"LapelR",Vector3.new(.72,3.05,.16),CFrame.new(.70,.04,-1.12)*CFrame.Angles(0,0,math.rad(12)),C.black,Enum.Material.Fabric)
		part(m,"Pin",Vector3.new(.24,.24,.10),CFrame.new(.82,.35,-1.23),C.brass,Enum.Material.Metal,Enum.PartType.Ball)
		part(m,"Chain",Vector3.new(.10,1.15,.08),CFrame.new(.55,-.16,-1.22)*CFrame.Angles(0,0,math.rad(48)),C.brass,Enum.Material.Metal)
	elseif id=="dice" then
		part(m,"Die",Vector3.new(2.5,2.5,2.5),CFrame.Angles(math.rad(18),math.rad(32),math.rad(8)),C.ivory)
		for _,pos in ipairs({Vector3.new(-.55,.55,-1.28),Vector3.new(.55,-.55,-1.28),Vector3.new(0,0,-1.28)}) do part(m,"Pip",Vector3.new(.28,.28,.08),CFrame.Angles(math.rad(18),math.rad(32),math.rad(8))*CFrame.new(pos),C.dark) end
	elseif id=="lens" then
		part(m,"LensRing",Vector3.new(.34,3.2,3.2),CFrame.Angles(0,math.rad(90),0),C.brass,Enum.Material.Metal,Enum.PartType.Cylinder)
		local glass=part(m,"Glass",Vector3.new(.1,2.55,2.55),CFrame.new(0,0,-.24)*CFrame.Angles(0,math.rad(90),0),Color3.fromRGB(145,217,222),Enum.Material.Glass,Enum.PartType.Cylinder); glass.Transparency=.35
		part(m,"Handle",Vector3.new(.4,2.1,.4),CFrame.new(.75,-2,0)*CFrame.Angles(0,0,math.rad(24)),C.wood,Enum.Material.Wood)
	elseif id=="watch" then
		part(m,"Watch",Vector3.new(.35,3,3),CFrame.Angles(0,math.rad(90),0),C.brass,Enum.Material.Metal,Enum.PartType.Cylinder)
		part(m,"Face",Vector3.new(.12,2.5,2.5),CFrame.new(0,0,-.24)*CFrame.Angles(0,math.rad(90),0),C.ivory,Enum.Material.SmoothPlastic,Enum.PartType.Cylinder)
		part(m,"Hand",Vector3.new(.07,.9,.06),CFrame.new(0,.35,-.34),C.dark)
	elseif id=="notebook" or id=="history" then
		local cover=id=="history" and Color3.fromRGB(44,76,72) or Color3.fromRGB(95,76,49)
		part(m,"Book",Vector3.new(3.3,.5,4.4),CFrame.Angles(math.rad(9),math.rad(-18),0),cover,Enum.Material.Fabric)
		part(m,"Pages",Vector3.new(2.95,.34,4.05),CFrame.new(0,.17,0)*CFrame.Angles(math.rad(9),math.rad(-18),0),C.ivory)
		part(m,"Band",Vector3.new(.28,.58,4.48),CFrame.new(.78,.06,0)*CFrame.Angles(math.rad(9),math.rad(-18),0),color,Enum.Material.SmoothPlastic)
		if id=="history" then
			for i=1,3 do part(m,"Tab"..i,Vector3.new(.7,.12,.38),CFrame.new(1.56,.38,-1.25+i*.8)*CFrame.Angles(math.rad(9),math.rad(-18),0),color) end
		end
	elseif kind=="outfit" then
		part(m,"Torso",Vector3.new(3.4,4.2,1.8),CFrame.new(0,0,0),Color3.fromRGB(25,27,29),Enum.Material.Fabric)
		part(m,"Shirt",Vector3.new(1.05,3.3,.18),CFrame.new(0,.1,-1),C.ivory,Enum.Material.Fabric)
		part(m,"LapelL",Vector3.new(.72,2.9,.16),CFrame.new(-.72,.1,-1.14)*CFrame.Angles(0,0,math.rad(-12)),C.dark,Enum.Material.Fabric)
		part(m,"LapelR",Vector3.new(.72,2.9,.16),CFrame.new(.72,.1,-1.14)*CFrame.Angles(0,0,math.rad(12)),C.dark,Enum.Material.Fabric)
		part(m,"Bow",Vector3.new(1.15,.35,.28),CFrame.new(0,1.25,-1.24),C.dark,Enum.Material.Fabric)
	elseif kind=="accessory" then
		part(m,"Brim",Vector3.new(.35,4.2,4.2),CFrame.Angles(0,0,math.rad(90)),C.dark,Enum.Material.Fabric,Enum.PartType.Cylinder)
		part(m,"Crown",Vector3.new(2.2,2.8,2.8),CFrame.new(0,1.1,0)*CFrame.Angles(0,0,math.rad(90)),C.dark,Enum.Material.Fabric,Enum.PartType.Cylinder)
		part(m,"Band",Vector3.new(.35,2.95,2.95),CFrame.new(0,.42,0)*CFrame.Angles(0,0,math.rad(90)),C.brass,Enum.Material.Fabric,Enum.PartType.Cylinder)
	elseif kind=="frame" then
		for _,x in ipairs({-1.7,1.7}) do part(m,"Side",Vector3.new(.28,4.2,.28),CFrame.new(x,0,0),color,Enum.Material.Metal) end
		for _,y in ipairs({-2,2}) do part(m,"Top",Vector3.new(3.7,.28,.28),CFrame.new(0,y,0),color,Enum.Material.Metal) end
		for _,x in ipairs({-1.7,1.7}) do for _,y in ipairs({-2,2}) do part(m,"Stud",Vector3.new(.48,.48,.48),CFrame.new(x,y,0),color,Enum.Material.Metal,Enum.PartType.Ball) end end
	elseif kind=="title" then
		part(m,"Plaque",Vector3.new(4.1,.34,2.25),CFrame.Angles(math.rad(12),math.rad(-16),0),C.dark,Enum.Material.SmoothPlastic)
		part(m,"Inset",Vector3.new(3.55,.18,1.72),CFrame.new(0,.28,0)*CFrame.Angles(math.rad(12),math.rad(-16),0),color,Enum.Material.Metal)
		part(m,"Medal",Vector3.new(.2,.9,.9),CFrame.new(-1.2,.48,-.1)*CFrame.Angles(math.rad(12),math.rad(-16),math.rad(90)),C.brass,Enum.Material.Metal,Enum.PartType.Cylinder)
	elseif kind=="emote" then
		part(m,"Palm",Vector3.new(1.6,2,1),CFrame.new(0,-.2,0)*CFrame.Angles(0,0,math.rad(-12)),color,Enum.Material.SmoothPlastic)
		for i=1,4 do part(m,"Finger"..i,Vector3.new(.34,1.85,.34),CFrame.new(-.62+(i-1)*.42,1.45,0)*CFrame.Angles(0,0,math.rad(-10+i*4)),color,Enum.Material.SmoothPlastic) end
	elseif kind=="effect" then
		local core=part(m,"Core",Vector3.new(2.2,2.2,2.2),CFrame.new(),color,Enum.Material.Neon,Enum.PartType.Ball); core.Transparency=.08
		for i=1,10 do
			local a=i*math.pi/5
			local orb=part(m,"Spark",Vector3.new(.38,.38,.38),CFrame.new(math.cos(a)*2.1,math.sin(a*.7)*1.2,math.sin(a)*1.4),color,Enum.Material.Neon,Enum.PartType.Ball); orb.Transparency=.15
		end
	else
		part(m,"File",Vector3.new(3.6,.28,4.8),CFrame.Angles(math.rad(10),math.rad(-22),0),color,Enum.Material.SmoothPlastic)
		part(m,"Paper",Vector3.new(3.15,.1,4.1),CFrame.new(0,.22,0)*CFrame.Angles(math.rad(10),math.rad(-22),0),C.ivory)
		part(m,"Seal",Vector3.new(.24,1.05,1.05),CFrame.new(.7,.46,.45)*CFrame.Angles(math.rad(10),math.rad(-22),math.rad(90)),C.brass,Enum.Material.Metal,Enum.PartType.Cylinder)
		part(m,"Strip",Vector3.new(2.2,.06,.16),CFrame.new(-.25,.42,-.65)*CFrame.Angles(math.rad(10),math.rad(-22),0),C.dark)
	end
	return m
end
local function nameplatePreview(parent,item)
    local card=Instance.new("Frame")
    card.Name="NameplatePreview";card.AnchorPoint=Vector2.new(.5,.5)
    card.Position=UDim2.fromScale(.5,.5);card.Size=UDim2.fromScale(.91,.65)
    card.BackgroundColor3=Color3.fromRGB(24,21,20);card.BorderSizePixel=0;card.Parent=parent
    local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,9);corner.Parent=card
    local color=Color3.fromRGB(table.unpack(item.titleColor or item.color))
    local border=Instance.new("UIStroke");border.Color=item.kind=="frame" and color or Color3.fromRGB(118,96,69)
    border.Thickness=item.id=="inner_circle_frame" and 2.4 or 1.5;border.Parent=card
    local function line(text,y,height,size,tint)
        local label=Instance.new("TextLabel");label.BackgroundTransparency=1
        label.Position=UDim2.new(0,12,y,0);label.Size=UDim2.new(1,-24,height,0)
        label.Font=Enum.Font.GothamBold;label.TextColor3=tint;label.TextSize=size
        label.TextXAlignment=Enum.TextXAlignment.Left;label.TextTruncate=Enum.TextTruncate.AtEnd
        label.Text=text;label.Parent=card;return label
    end
    local player=Players.LocalPlayer
    local identity=line(player and player.DisplayName or "SPY CLUB",.10,.35,16,Color3.fromRGB(243,224,194));identity.Name="PlayerName";identity:SetAttribute("SpyUserText",true)
    line(item.kind=="title" and (item.ru or item.en) or "SPY CLUB",.53,.30,12,color)
    return card,nil
end
function Preview3D.mount(parent,item,caseId,options)
	options=options or {}
	if item and not caseId and (item.kind=="frame" or item.kind=="title") then return nameplatePreview(parent,item) end
	-- Inventory suits use the same canonical R15 body and Shirt/Pants asset as
	-- the character; a stylised torso dummy made purchases look different.
	if item and not caseId and (item.wearable or item.kind=="outfit" or item.kind=="accessory" or item.kind=="trinket") then
		return Preview3D.mountCollection(parent,{item},{motion=options.motion}),nil
	end
	if item and item.kind=="card" then
		local host=Instance.new("Frame")
		host.Name="CardPreview"; host.Size=UDim2.fromScale(.66,.9); host.Position=UDim2.fromScale(.5,.5)
		host.AnchorPoint=Vector2.new(.5,.5); host.BackgroundTransparency=1; host.ZIndex=parent.ZIndex+1; host.Parent=parent
		local aspect=Instance.new("UIAspectRatioConstraint"); aspect.AspectRatio=.72; aspect.Parent=host
		return Art.draw(host,item),nil
	end
	local viewport=Instance.new("ViewportFrame")
	viewport.Name="Preview3D"; viewport.Size=UDim2.fromScale(1,1); viewport.BackgroundTransparency=1
	viewport.BorderSizePixel=0; viewport.ZIndex=parent.ZIndex+1
	viewport.Ambient=Color3.fromRGB(175,175,175); viewport.LightColor=Color3.fromRGB(255,255,255)
	viewport.LightDirection=Vector3.new(-1,-1,-1); viewport.Parent=parent
	local world=Instance.new("WorldModel"); world.Parent=viewport
	local model=caseId and cloneStandCase(world,caseId) or itemModel(world,item)
	if not model and caseId then error("Missing showcase case: "..tostring(caseId)) end
	local cf,size=model:GetBoundingBox()
	local camera=Instance.new("Camera"); camera.FieldOfView=34; camera.Parent=viewport; viewport.CurrentCamera=camera
	local extent=math.max(size.X,size.Y,size.Z)
	local phase=0
	local function frameCamera()
		local aspect=math.max(.35,viewport.AbsoluteSize.X/math.max(1,viewport.AbsoluteSize.Y))
		local distance=extent*(options.dock and 1.5 or (caseId and 1.7 or 1.95))*math.max(1,1/aspect)
		local angle=math.rad(23)+(options.motion and math.sin(phase*.5)*.07 or 0)
		local target=cf.Position+Vector3.new(0,caseId and .5 or 0,0)
		camera.CFrame=CFrame.lookAt(target+Vector3.new(math.sin(angle)*distance,distance*.42,-math.cos(angle)*distance),target)
	end
	frameCamera()
	local sizeConnection=viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(frameCamera)
	local idle
	if options.motion then idle=RunService.RenderStepped:Connect(function(dt)
			if not viewport.Parent then return end
			local visible=true; local ancestor=viewport.Parent
			while ancestor and ancestor:IsA("GuiObject") do if not ancestor.Visible then visible=false; break end; ancestor=ancestor.Parent end
			if visible then phase=phase+dt; frameCamera() end
		end) end
	viewport.Destroying:Connect(function() sizeConnection:Disconnect(); if idle then idle:Disconnect() end end)
	return viewport,model
end
local function pivotTween(group,target,duration,delay)
	local driver=Instance.new("CFrameValue"); driver.Value=group:GetPivot(); driver.Parent=group
	local connection=driver:GetPropertyChangedSignal("Value"):Connect(function() if group.Parent then group:PivotTo(driver.Value) end end)
	group.Destroying:Connect(function() connection:Disconnect() end)
	task.delay(delay or 0,function()
		if not group.Parent then return end
		local tween=TweenService:Create(driver,TweenInfo.new(duration,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Value=target})
		tween:Play()
	end)
end
local function animateShowcaseCase(model,revealColor)
	local startPivot=model:GetPivot()
	local highlight=Instance.new("Highlight")
	highlight.Name="CaseRarityTrace"
	highlight.FillColor=revealColor
	highlight.FillTransparency=1
	highlight.OutlineColor=revealColor
	highlight.OutlineTransparency=1
	highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee=model
	highlight.Parent=model

	local originalParts={}
	for _,part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Name~="StandRevealGlow" then
			part:SetAttribute("OriginalTransparency",part.Transparency)
			originalParts[#originalParts+1]=part
		end
	end

	TweenService:Create(highlight,TweenInfo.new(.42,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{OutlineTransparency=.08}):Play()
	pivotTween(model,startPivot*CFrame.new(0,.22,0)*CFrame.Angles(math.rad(-2),math.rad(7),0),1.25,.28)

	local glow=model:FindFirstChild("StandRevealGlow",true)
	local light=glow and glow:FindFirstChild("RevealLight")
	if glow and glow:IsA("BasePart") then
		glow.Color=revealColor
		task.delay(1.18,function()
			if not glow.Parent then return end
			TweenService:Create(glow,TweenInfo.new(.78,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Transparency=.10,Size=glow.Size*Vector3.new(1.35,1,1.35)}):Play()
			if light then
				light.Color=revealColor
				TweenService:Create(light,TweenInfo.new(.62,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Brightness=3.1,Range=18}):Play()
			end
		end)
	end

	task.delay(2.32,function()
		if not model.Parent then return end
		TweenService:Create(highlight,TweenInfo.new(.34,Enum.EasingStyle.Quint,Enum.EasingDirection.In),{FillTransparency=.72,OutlineTransparency=1}):Play()
		for _,part in ipairs(originalParts) do
			if part.Parent then
				TweenService:Create(part,TweenInfo.new(.52,Enum.EasingStyle.Quint,Enum.EasingDirection.In),{Transparency=1}):Play()
			end
		end
		if light then TweenService:Create(light,TweenInfo.new(.48),{Brightness=0}):Play() end
	end)
end
function Preview3D.animateCaseOpen(viewport,model,rarityKey)
	if not viewport or not model or model:GetAttribute("Opened") then return Preview3D.CASE_REVEAL_TIME end
	model:SetAttribute("Opened",true)
	local rarityColors={
		common=Color3.fromRGB(205,199,188),uncommon=Color3.fromRGB(91,190,121),rare=Color3.fromRGB(76,139,238),
		epic=Color3.fromRGB(169,91,232),legendary=Color3.fromRGB(238,181,73),mythic=Color3.fromRGB(224,55,78),
	}
	local revealColor=rarityColors[rarityKey] or C.brass
	if model:GetAttribute("StandModel") then
		animateShowcaseCase(model,revealColor)
		return Preview3D.CASE_REVEAL_TIME
	end
	local seal=model:FindFirstChild("StandSeal",true) or model:FindFirstChild("Seal",true)
	if seal and seal:IsA("BasePart") then
		task.delay(.28,function()
			if not seal.Parent then return end
			local flash=TweenService:Create(seal,TweenInfo.new(.30,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Color=revealColor,Transparency=.18})
			flash:Play()
		end)
	end
	for index,name in ipairs({"Lock1","Lock2"}) do
		local lock=model:FindFirstChild(name)
		if lock then pivotTween(lock,lock:GetPivot()*CFrame.new(0,-.17,-.20)*CFrame.Angles(math.rad(-68),0,0),.42,.58+(index-1)*.32) end
	end
	local glow=model:FindFirstChild("StandRevealGlow",true) or model:FindFirstChild("RevealGlow",true)
	if glow and glow:IsA("BasePart") then
		glow.Color=revealColor
		local light=glow:FindFirstChild("RevealLight")
		if light then light.Color=revealColor end
		task.delay(1.12,function()
			if not glow.Parent then return end
			TweenService:Create(glow,TweenInfo.new(.72,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Transparency=.12,Size=Vector3.new(4.25,.10,2.85)}):Play()
			if light then TweenService:Create(light,TweenInfo.new(.72),{Brightness=2.4,Range=15}):Play() end
		end)
	end
	local lid=model:FindFirstChild("LidAssembly")
	if lid then pivotTween(lid,lid:GetPivot()*CFrame.Angles(math.rad(112),0,0),1.05,1.62) end
	return Preview3D.CASE_REVEAL_TIME
end
local function canonicalDescription()
	local description=Instance.new("HumanoidDescription")
	local function set(propertyName,value) pcall(function() description[propertyName]=value end) end
	set("HeightScale",1); set("WidthScale",1); set("DepthScale",1); set("HeadScale",1)
	set("BodyTypeScale",0); set("ProportionScale",0)
	for _,propertyName in ipairs({"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg"}) do set(propertyName,0) end
	local skin=Color3.fromRGB(224,197,172)
	set("HeadColor",skin); set("LeftArmColor",skin); set("RightArmColor",skin)
	set("TorsoColor",Color3.fromRGB(29,27,30)); set("LeftLegColor",Color3.fromRGB(22,23,26)); set("RightLegColor",Color3.fromRGB(22,23,26))
	set("Shirt",0); set("Pants",0); set("GraphicTShirt",0); set("Face",0)
	pcall(function() description:SetAccessories({},true) end)
	return description
end

local PREVIEW_FACE_INK=Color3.fromRGB(38,31,30)
-- One fitting source: the exact same resolved clothing and accessories as live players.
local Wardrobe=require(script.Parent.Wardrobe)
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local function cleanPreview(model)
    for _,node in ipairs(model:GetDescendants()) do
        if node:IsA("LuaSourceContainer") or node:IsA("GuiBase2d") or node:IsA("LayerCollector")
            or node:IsA("ProximityPrompt") or node:IsA("Dialog") or node:IsA("Sound") then node:Destroy()
        elseif node:IsA("BasePart") then
            node.Anchored=true;node.CanCollide=false;node.CanTouch=false;node.CanQuery=false
            node.LocalTransparencyModifier=0
        end
    end
    local humanoid=model:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None end
end
function Preview3D.mountCollection(parent,items,options)
    options=options or {}
    local equipped=Wardrobe.itemsToEquipment(items,options.equipped)
    local viewport=Instance.new("ViewportFrame")
    viewport.Name="WardrobePreview";viewport.Size=UDim2.fromScale(1,1)
    viewport.BackgroundTransparency=1;viewport.BorderSizePixel=0;viewport.ZIndex=parent.ZIndex+1
    viewport.Ambient=Color3.fromRGB(190,190,190);viewport.LightColor=Color3.fromRGB(255,255,255)
    viewport.LightDirection=Vector3.new(-1,-.45,-1);viewport.Parent=parent
    local world=Instance.new("WorldModel");world.Parent=viewport
    local camera=Instance.new("Camera");camera.FieldOfView=30;camera.Parent=viewport;viewport.CurrentCamera=camera
    local status=Instance.new("TextLabel")
    status.Name="PreviewStatus";status.BackgroundTransparency=1;status.Size=UDim2.fromScale(1,1)
    status.Text="…";status.Font=Enum.Font.GothamBold;status.TextSize=20
    status.TextColor3=Color3.fromRGB(207,189,159);status.ZIndex=viewport.ZIndex+1;status.Parent=viewport
    local model,folder
    local yaw=math.rad(15)
    local elapsed=0
    local revealElapsed=0
    local animate=options.reducedMotion~=true
    local cinematic=options.cinematic==true and animate
    local dragging=false
    local lastX=0
    local connections={}
    local alive=true
    local building=false
    local needsRefresh=false
    local single=items and #items==1 and items[1]
    local slot=not options.fullBody and single and (single.equipSlot or single.kind)
    local target,span,width
    local function frameCamera()
        if not target then return end
        local aspect=math.max(.35,viewport.AbsoluteSize.X/math.max(1,viewport.AbsoluteSize.Y))
        local distance=math.max(span/2,width/(2*aspect))/math.tan(math.rad(camera.FieldOfView/2))*1.12
        local progress=cinematic and math.clamp(revealElapsed/.8,0,1) or 1
        local eased=1-(1-progress)^5
        distance*=.88+.12*eased
        local angle=yaw-.12*(1-eased)+(animate and options.motion and not dragging and math.sin(elapsed*.35)*(cinematic and .06 or .12) or 0)
        camera.CFrame=CFrame.lookAt(target+Vector3.new(math.sin(angle)*distance,distance*.04,-math.cos(angle)*distance),target)
        camera.Focus=CFrame.new(target)
    end
    local function focus()
        local cf,size=model:GetBoundingBox()
        target=cf.Position;span=size.Y+.2;width=math.max(size.X,size.Z)+.25
        local head=model:FindFirstChild("Head")
        local torso=model:FindFirstChild("UpperTorso")
        local lower=model:FindFirstChild("LowerTorso")
        if (slot=="hat" or slot=="accessory" or slot=="hair") and head then
            target=head.Position+Vector3.new(0,.45,0);span=3.15;width=3.25
        elseif slot=="glasses" and head then
            target=head.Position+Vector3.new(0,.07,0);span=2.15;width=2.55
        elseif slot=="tie" and torso then
            target=torso.Position+Vector3.new(0,.25,0);span=2.65;width=3.1
        elseif (slot=="gloves" or slot=="shoulder") and torso then
            target=torso.Position-Vector3.new(0,.25,0);span=3.45;width=4.2
        elseif slot=="trinket" and lower then
            target=lower.Position+Vector3.new(.3,-.1,-.25);span=1.7;width=2.5
        end
        frameCamera()
    end
    local rebuild
    rebuild=function()
        if not alive then return end
        if building then needsRefresh=true;return end
        building=true
        task.spawn(function()
            local character=options.character
            local replicated=options.replicatedCharacter==true and character and character:FindFirstChildOfClass("Humanoid")~=nil
            -- The H scene renders what has actually replicated, without waiting on
            -- fitting assets or replacing the player's real clothing in its clone.
            local ready=replicated or Wardrobe.prepare(equipped,slot and 6 or 12,slot)
            folder=ReplicatedStorage:FindFirstChild("SpyWardrobeAssets")
            -- Product try-on keeps the existing Wardrobe rendering contract.
            local rig=character and character:FindFirstChildOfClass("Humanoid") and character
                or (folder and (folder:FindFirstChild("PreviewRig") or folder:WaitForChild("PreviewRig",8)))
            if not alive then building=false;return end
            if rig then
                local archivable=rig.Archivable
                rig.Archivable=true
                local cloned,nextModel=pcall(rig.Clone,rig)
                rig.Archivable=archivable
                if not cloned or not nextModel then building=false;status.Text="Примерка временно недоступна";return end
                nextModel.Name=character and "PersonalAppearance" or "FittingMannequin"
                -- Do not bring live character scripts into the ViewportFrame's WorldModel.
                cleanPreview(nextModel)
                nextModel.Parent=world
                nextModel:PivotTo(CFrame.new())
                local renderer=(ready and not slot) and Wardrobe.render or Wardrobe.renderAvailable
                local ok,reason=true,nil
                if not replicated then ok,reason=pcall(renderer,nextModel,equipped) end
                if ok then
                    cleanPreview(nextModel)
                    if model then model:Destroy() end
                    model=nextModel;revealElapsed=0;focus();status.Visible=not ready
                    viewport:SetAttribute("CharacterReady",true)
                    if not ready then
                        status.Text="Часть образа пока недоступна";status.TextSize=12
                        status.Size=UDim2.new(1,-16,0,36);status.Position=UDim2.new(0,8,1,-40)
                    end
                else nextModel:Destroy();status.Text="Примерка недоступна";warn("[SpyWardrobe] Preview: "..tostring(reason)) end
            else status.Text="Примерка временно недоступна" end
            building=false
            if needsRefresh then needsRefresh=false;if not model then task.defer(rebuild) end end
        end)
    end
    connections[#connections+1]=viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(frameCamera)
    connections[#connections+1]=viewport.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true;lastX=input.Position.X;revealElapsed=.8
            if options.onDraggingChanged then options.onDraggingChanged(true) end
        end
    end)
    connections[#connections+1]=UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
            local delta=input.Position.X-lastX;lastX=input.Position.X;yaw-=delta*.008;frameCamera()
        end
    end)
    connections[#connections+1]=UserInputService.InputEnded:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch) then
            dragging=false
            if options.onDraggingChanged then options.onDraggingChanged(false) end
        end
    end)
    if animate and (options.motion or cinematic) then
        connections[#connections+1]=RunService.RenderStepped:Connect(function(dt)
            if not alive or not model then return end
            elapsed+=dt;revealElapsed+=dt;frameCamera()
        end)
    end
    if options.replicatedCharacter and options.character then rebuild() end
    task.spawn(function()
        folder=ReplicatedStorage:FindFirstChild("SpyWardrobeAssets") or ReplicatedStorage:WaitForChild("SpyWardrobeAssets",20)
        if folder and alive then
            connections[#connections+1]=folder:GetAttributeChangedSignal("Revision"):Connect(function() if not model then rebuild() end end)
            connections[#connections+1]=folder.ChildAdded:Connect(function(child)
                if child.Name=="PreviewRig" then rebuild() end
            end)
            if not model then rebuild() end
        end
    end)
    viewport.Destroying:Connect(function()
        alive=false
        if dragging and options.onDraggingChanged then options.onDraggingChanged(false) end
        for _,connection in ipairs(connections) do connection:Disconnect() end
    end)
    return viewport
end
-- A portrait of the authored NPC, independent of player equipment and the world camera.
-- The returned viewport owns its clone, resize connection, and bounded late-source retry.
function Preview3D.mountNPC(parent, source)
    local viewport=Instance.new("ViewportFrame")
    viewport.Name="VincentPortrait";viewport.Size=UDim2.fromScale(1,1)
    viewport.BackgroundTransparency=1;viewport.BorderSizePixel=0;viewport.Active=false
    viewport.ZIndex=parent.ZIndex+1
    viewport.Ambient=Color3.fromRGB(190,190,190);viewport.LightColor=Color3.fromRGB(255,255,255)
    viewport.LightDirection=Vector3.new(-1,-.45,-1)
    viewport:SetAttribute("PortraitReady",false)
    viewport.Parent=parent
    local world=Instance.new("WorldModel");world.Name="PortraitWorld";world.Parent=viewport
    local camera=Instance.new("Camera");camera.FieldOfView=30;camera.Parent=viewport;viewport.CurrentCamera=camera
    local alive=true
    local attempts=0
    local retryThread
    local head,torso
    local function frameCamera()
        if not alive or not head or not head.Parent then return end
        -- Vincent's saved Model pivot is unrelated to his physical parts. Frame the
        -- face and chest directly, including space above the head for his actual hat.
        local chest=torso or head
        local target=head.Position-Vector3.new(0,chest.Size.Y*.35,0)
        local span=math.max(head.Size.Y*3.8,chest.Size.Y*1.9)
        local width=math.max(head.Size.X*2.1,chest.Size.X*2.1)
        local aspect=math.max(.35,viewport.AbsoluteSize.X/math.max(1,viewport.AbsoluteSize.Y))
        local distance=math.max(span/2,width/(2*aspect))/math.tan(math.rad(camera.FieldOfView/2))*1.08
        local forward=head.CFrame.LookVector
        forward=Vector3.new(forward.X,0,forward.Z)
        forward=forward.Magnitude>.01 and forward.Unit or Vector3.new(0,0,-1)
        local right=Vector3.new(-forward.Z,0,forward.X)
        camera.CFrame=CFrame.lookAt(target+forward*distance+right*(distance*.10)+Vector3.new(0,distance*.04,0),target)
        camera.Focus=CFrame.new(target)
    end
    local function resolveSource()
        if source then return source end
        local club=workspace:FindFirstChild("SpyClub")
        return club and club:FindFirstChild("VincentVisual")
    end
    local attempt
    attempt=function()
        retryThread=nil
        if not alive or not viewport.Parent then return end
        attempts+=1
        local authored=resolveSource()
        local cloned,model=false,nil
        if authored and authored:IsA("Model") then
            local archivable=authored.Archivable
            cloned,model=pcall(function()
                authored.Archivable=true
                return authored:Clone()
            end)
            authored.Archivable=archivable
        end
        if cloned and model then
            local ok=pcall(function()
                for _,node in ipairs(model:GetDescendants()) do
                    if node:IsA("LuaSourceContainer") or node:IsA("ProximityPrompt") or node:IsA("Dialog")
                        or node:IsA("BillboardGui") or node:IsA("SurfaceGui") or node:IsA("Sound") then
                        node:Destroy()
                    elseif node:IsA("BasePart") then
                        node.Anchored=true;node.CanCollide=false;node.CanTouch=false;node.CanQuery=false
                        node.LocalTransparencyModifier=0
                    elseif node:IsA("Humanoid") then
                        node.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
                    end
                end
                head=model:FindFirstChild("Head",true)
                torso=model:FindFirstChild("Torso",true) or model:FindFirstChild("UpperTorso",true)
                if not head or not head:IsA("BasePart") then error("NPC head unavailable") end
                if torso and not torso:IsA("BasePart") then torso=nil end
                model.Name="VincentPortraitModel";model.Parent=world
                frameCamera()
            end)
            if ok then viewport:SetAttribute("PortraitReady",true);return end
            model:Destroy();head=nil;torso=nil
        end
        -- Replication may deliver the static NPC after the UI opens. Stop polling
        -- after five seconds; the dialogue's typographic identity remains usable.
        if attempts<20 then retryThread=task.delay(.25,attempt) end
    end
    local sizeConnection=viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(frameCamera)
    viewport.Destroying:Connect(function()
        alive=false;head=nil;torso=nil
        if retryThread then task.cancel(retryThread);retryThread=nil end
        sizeConnection:Disconnect()
    end)
    attempt()
    return viewport
end
return Preview3D
