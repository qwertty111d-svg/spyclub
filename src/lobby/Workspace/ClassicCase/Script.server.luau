local RunService = game:GetService("RunService")

local case = script.Parent
local startPivot = case:GetPivot()

local time = 0

local ROTATION_SPEED = math.rad(30) -- полный оборот примерно за 12 секунд
local BOB_HEIGHT = 0.2              -- насколько поднимается/опускается
local BOB_SPEED = 1.5               -- скорость парения

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