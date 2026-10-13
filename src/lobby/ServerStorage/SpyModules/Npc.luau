-- ServerStorage > SpyModules > Npc
-- Static Vincent binder for the hand-placed premium VincentVisual model.
-- The old generated Bartender rig is no longer required.

local Npc = {}
local bound = setmetatable({}, {__mode = "k"})

local function stabilize(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Dialog") then
			-- Toolbox dialogs are not part of SPY CLUB's dialogue system.
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.Massless = true
		end
	end
end

function Npc.spawn(world)
	local model = world:FindFirstChild("VincentVisual")
		or world:FindFirstChild("Bartender") -- compatibility with older saves only

	if not model or not model:IsA("Model") then
		warn("SpyClub: VincentVisual is missing; continuing without NPC animation")
		return nil
	end

	if bound[model] then
		return model
	end

	local head = model:FindFirstChild("Head")
	local torso = model:FindFirstChild("Torso")
	local humanoid = model:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.AutoRotate = false
		humanoid.BreakJointsOnDeath = false
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	-- Vincent is a static bartender. The imported model already contains its
	-- visual joints, so anchoring the authored pieces is safer than rebuilding
	-- an obsolete R6 HumanoidRootPart rig around it.
	stabilize(model)

	if torso and torso:IsA("BasePart") then
		model.PrimaryPart = torso
	elseif head and head:IsA("BasePart") then
		model.PrimaryPart = head
	end

	bound[model] = true
	return model
end

return Npc
