local RunService = game:GetService("RunService")

local case = script.Parent
local startPivot = case:GetPivot()

local time = 0

local ROTATION_SPEED = math.rad(18) -- медленнее первого
local BOB_HEIGHT = 0.12              -- меньше ход вверх-вниз
local BOB_SPEED = 1.0                -- спокойнее парение

RunService.Heartbeat:Connect(function(dt)
	time += dt

	local bob = math.sin(time * BOB_SPEED) * BOB_HEIGHT
	local rotation = CFrame.Angles(0, time * ROTATION_SPEED, 0)

	case:PivotTo(
		startPivot
			* CFrame.new(0, bob, 0)
			* rotation
	)
end)
