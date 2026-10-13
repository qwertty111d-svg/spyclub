local RunService = game:GetService("RunService")

local case = script.Parent
local startPivot = case:GetPivot()

local time = 0

local ROTATION_SPEED = math.rad(12) -- самый медленный
local BOB_HEIGHT = 0.16             -- чуть выше парит
local BOB_SPEED = 0.8               -- плавное движение
local TILT_ANGLE = math.rad(3)      -- лёгкий наклон

RunService.Heartbeat:Connect(function(dt)
	time += dt

	local bob = math.sin(time * BOB_SPEED) * BOB_HEIGHT
	local tilt = math.sin(time * 0.45) * TILT_ANGLE
	local rotation = CFrame.Angles(tilt, time * ROTATION_SPEED, 0)

	case:PivotTo(
		startPivot
			* CFrame.new(0, bob, 0)
			* rotation
	)
end)
