-- Floor runners use the live interaction anchors in the authored main lounge.
-- Continuous textile routes share the same height and have a hem only around their outer contour.
local Wayfinding = {}
local VERSION = 9
local watching = setmetatable({}, {__mode = "k"})
local C = {
    rug = Color3.fromRGB(42, 55, 49),
    hem = Color3.fromRGB(61, 70, 60),
    thread = Color3.fromRGB(141, 154, 148),
    lettering = Color3.fromRGB(218, 195, 150),
}

local function interactionPart(prompt)
    local parent = prompt.Parent
    while parent and parent ~= workspace do
        if parent:IsA("BasePart") then return parent end
        parent = parent.Parent
    end
end

local function findPrompt(root, name)
    for _, item in ipairs(root:GetDescendants()) do
        if item:IsA("ProximityPrompt") and item.Name == name then
            local anchor = interactionPart(item)
            if anchor then return anchor end
        end
    end
end

local function caseAnchor(name)
    local model = workspace:FindFirstChild(name, true)
    if not model then return nil end
    local anchor = findPrompt(model, "CasePrompt")
    return anchor and anchor.Position or nil
end

-- Public route data also makes map clearance verifiable without a Studio session.
function Wayfinding.plan(root)
    local floor = root:FindFirstChild("SafetyFloor")
    local ground = floor and floor.Position.Y + floor.Size.Y / 2 or 0
    -- Authored floor tiles are 0.06 high above SafetyFloor.
    local tile = root:FindFirstChild("Tile4_-20")
    if tile and tile:IsA("BasePart") then ground = math.max(ground, tile.Position.Y + tile.Size.Y / 2) end
    local plan = {ground = ground, rectangles = {}, marks = {}, destinations = {}}
    local function rect(name, x, z, width, length, axis)
        table.insert(plan.rectangles, {name = name, x = x, z = z, width = width, length = length, axis = axis or "z"})
    end
    local function mark(name, text, x, z, direction, width, length)
        table.insert(plan.marks, {name = name, text = text, x = x, z = z, direction = direction, width = width or 2.7, length = length or 1.8})
    end
    local function destination(name, point, approach)
        plan.destinations[name] = {anchor = point, approach = approach}
    end

    local spawn = root:FindFirstChild("ClubSpawn")
    local entryZ = spawn and spawn.Position.Z - 3 or -29.5
    rect("EntrySpine", 0, (entryZ + 19.5) / 2, 6.4, 19.5 - entryZ)
    mark("WelcomeInlay", "SPY CLUB", 0, entryZ + 3.8, 0, 3.6, 2.5)
    mark("LoungeApproach", "БАР  /  BAR   ↑", 0, -20.3, 0, 3.9, 1.2)
    if spawn then destination("entrance", spawn.Position, Vector3.new(0, ground, -20.3)) end

    local feedback = findPrompt(root, "FeedbackBook")
    if feedback then
        local point = feedback.Position
        local deskX = point.X + .4 -- preserve the writing book offset from the desk centre
        rect("ContactBranch", (deskX - 2.2) / 2, -21, 3.6, -deskX - 2.2, "x")
        mark("ContactInlay", "СВЯЗЬ", deskX + 1.6, -21, math.pi / 2, 2.25, 2.4)
        destination("feedback", point, Vector3.new(deskX, ground, -21))
    end

    local daily = findPrompt(root, "DailyReward")
    if daily then
        local point = daily.Position
        local rewardX, turnZ = point.X, 17.3
        rect("RewardsBranch", (rewardX - 2.2) / 2, turnZ, 4.6, -rewardX - 2.2, "x")
        -- Stop outside the DailyTop footprint (front edge z=23.15).
        local endZ = math.min(point.Z - 3.6, 21)
        rect("RewardsApproach", rewardX, (turnZ + 2.3 + endZ) / 2, 4.6, endZ - turnZ - 2.3)
        mark("RewardsInlay", "НАГРАДЫ", -18, turnZ, math.pi / 2, 2.8, 3.5)
        mark("RewardsTurn", "", rewardX, turnZ, 0, 2.3, 1.5)
        destination("daily", point, Vector3.new(rewardX, ground, endZ))
    end

    local vincent = findPrompt(root, "TalkVincent")
    if vincent then
        mark("VincentInlay", "ВИНСЕНТ", 0, 18, 0, 3.4, 2.4)
        destination("vincent", vincent.Position, Vector3.new(0, ground, 19.5))
    end

    local cases = {}
    for _, item in ipairs({
        {"ClassicCase", "classic", "КЛАССИКА"},
        {"SilverCase", "silver", "СЕРЕБРО"},
        {"GoldCase", "gold", "ЗОЛОТО"},
        {"AtelierDisplay", "atelier", "АТЕЛЬЕ"},
    }) do
        local point = caseAnchor(item[1])
        if point then table.insert(cases, {id = item[2], text = item[3], point = point}) end
    end
    if #cases > 0 then
        table.sort(cases, function(a, b) return a.point.Z < b.point.Z end)
        local aisleX = 29.3
        local branchZ = cases[math.min(2, #cases)].point.Z
        rect("CasesBranch", (2.2 + aisleX - 2.4) / 2, branchZ, 4.6, aisleX - 2.4 - 2.2, "x")
        local lowZ, highZ = cases[1].point.Z - 1.5, cases[#cases].point.Z + 1.5
        rect("CaseGallery", aisleX, (lowZ + highZ) / 2, 4.8, highZ - lowZ)
        mark("CasesInlay", "ОБРАЗ", 15, branchZ, -math.pi / 2, 2.8, 3.4)
        for _, entry in ipairs(cases) do
            mark(entry.id .. "Inlay", entry.text, aisleX, entry.point.Z, -math.pi / 2, 2.7, 2.5)
            destination(entry.id, entry.point, Vector3.new(aisleX+1.9, ground, entry.point.Z))
        end
    end
    return plan
end

local function part(parent, name, size, cf, color)
    local object = Instance.new("Part")
    object.Name, object.Size, object.CFrame, object.Color = name, size, cf, color
    object.Material = Enum.Material.Carpet
    object.MaterialVariant = "ClubTextile"
    object.Reflectance = 0
    object.Anchored, object.CanCollide, object.CanTouch, object.CanQuery = true, false, false, false
    object.CastShadow = false
    object.TopSurface, object.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    object.Parent = parent
    return object
end

-- Main runner keeps one UV surface. Branches meet it exactly, without overlapping bodies.
local function tailored(rectangles)
 local out={}
 for _,r in ipairs(rectangles)do
  local copy=table.clone(r)
  if r.axis=="x"then
   local low,high=r.x-r.length*.5,r.x+r.length*.5
   if r.x<0 then high=math.min(high,-3.2)else low=math.max(low,3.2)end
   if r.name=="CasesBranch"then high=26.9 end
   if r.name=="RewardsBranch"then low-=r.width*.5 end
   copy.x=(low+high)*.5;copy.length=high-low
  end
  if copy.length>.05 then out[#out+1]=copy end
 end
 return out
end
local function bounds(r)
 local w,l=r.width,r.length;if r.axis=="x"then w,l=l,w end
 return r.x-w*.5,r.x+w*.5,r.z-l*.5,r.z+l*.5
end
local function uncovered(low,high,cuts)
 table.sort(cuts,function(a,b)return a[1]<b[1]end)
 local out={};local cursor=low
 for _,cut in ipairs(cuts)do
  local a,b=math.max(low,cut[1]),math.min(high,cut[2])
  if b>a then if a>cursor+.001 then out[#out+1]={cursor,a}end;cursor=math.max(cursor,b)end
 end
 if high>cursor+.001 then out[#out+1]={cursor,high}end
 return out
end
local function drawTextiles(model,rectangles,ground)
 for index,r in ipairs(rectangles)do
  local x0,x1,z0,z1=bounds(r)
  local rug=part(model,r.name,Vector3.new(x1-x0,.12,z1-z0),CFrame.new(r.x,ground+.062,r.z),C.rug)
  rug:SetAttribute("WayfindingRunner",true)
  for _,edge in ipairs({{true,x0,z0,z1},{true,x1,z0,z1},{false,z0,x0,x1},{false,z1,x0,x1}})do
   local vertical,position,low,high=table.unpack(edge);local cuts={}
   for j,other in ipairs(rectangles)do if j~=index then
    local a,b,c,d=bounds(other)
    local touches=vertical and position>=a-.001 and position<=b+.001 or not vertical and position>=c-.001 and position<=d+.001
    if touches then cuts[#cuts+1]=vertical and {c,d}or {a,b}end
   end end
   for _,interval in ipairs(uncovered(low,high,cuts))do
    local length=interval[2]-interval[1];local center=(interval[1]+interval[2])*.5
    local inward=vertical and (position==x0 and .08 or -.08)or(position==z0 and .08 or -.08)
    local size=vertical and Vector3.new(.1,.004,math.max(.02,length-.10))or Vector3.new(math.max(.02,length-.10),.004,.1)
    local point=vertical and Vector3.new(position+inward,ground+.125,center)or Vector3.new(center,ground+.125,position+inward)
    part(model,"RunnerHem",size,CFrame.new(point),C.hem)
   end
  end
 end
end

local function drawMarks(model, marks, ground)
 for _, mark in ipairs(marks) do
  if mark.text ~= "" then
   local plate = part(model, mark.name, Vector3.new(mark.width, .004, mark.length),
    CFrame.new(mark.x, ground + .129, mark.z) * CFrame.Angles(0, mark.direction, 0), C.rug)
   plate.Transparency = 1
   local gui = Instance.new("SurfaceGui")
   gui.Name, gui.Face, gui.CanvasSize = "RunnerInlay", Enum.NormalId.Top, Vector2.new(600, 220)
   gui.LightInfluence, gui.AlwaysOnTop, gui.MaxDistance = .65, false, 32
   gui.Parent = plate
   local label = Instance.new("TextLabel")
   label.Name, label.Size, label.BackgroundTransparency = "Lettering", UDim2.fromScale(1, 1), 1
   label.Text, label.TextColor3 = mark.text, C.lettering
   label.Font, label.TextSize = Enum.Font.GothamMedium, 58
   label.Parent = gui
  end
 end
end

function Wayfinding.apply(root)
    local plan = Wayfinding.plan(root)
    local model = Instance.new("Model")
    model.Name = "ClubWayfinding"
    model:SetAttribute("Version", VERSION)
    drawTextiles(model, tailored(plan.rectangles), plan.ground)
    drawMarks(model, plan.marks, plan.ground)
    -- Commit a complete replacement. A failed optional build leaves the current runner intact.
    local previous = root:FindFirstChild(model.Name)
    if previous then previous:Destroy() end
    for _, name in ipairs({"EntryRunner", "RunnerPiping5", "RunnerPiping-5"}) do
        local legacy = root:FindFirstChild(name)
        if legacy then legacy:Destroy() end
    end
    model.Parent = root
    root:SetAttribute("WayfindingVersion", VERSION)
    return model, plan
end

function Wayfinding.start(root)
    Wayfinding.apply(root)
    if watching[root] then return end
    local pending = false
    local connection
    connection = workspace.DescendantAdded:Connect(function(item)
        if item.Name ~= "AtelierDisplay" and item.Name ~= "AtelierPromptAnchor" and item.Name ~= "CasePrompt" then return end
        if pending then return end
        pending = true
        task.defer(function()
            pending = false
            if not root.Parent then return end
            local ok, err = pcall(Wayfinding.apply, root)
            if not ok then root:SetAttribute("WayfindingError", tostring(err)) end
        end)
    end)
    watching[root] = connection
    root.Destroying:Connect(function() connection:Disconnect(); watching[root] = nil end)
end
return Wayfinding
