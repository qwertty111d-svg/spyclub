-- One controller per panel; cursor movement is measured in visible-screen pixels.
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local FloatingUIController = {}

function FloatingUIController.create(panel, options)
    options = options or {}
    local container = options.container or panel.Parent
    local screenGui = panel:FindFirstAncestorWhichIsA("ScreenGui")
    local basePosition = panel.Position
    local offset = Vector2.zero
    local active, paused, alive = false, false, true
    local maxOffset = options.maxOffset or 14
    local smoothTime = options.smoothTime or 0.15
    local padding = options.safePadding or 18
    local self = {}

    function self:setActive(value)
        active = value == true
        if not active then offset = Vector2.zero; panel.Position = basePosition end
    end
    function self:setPaused(value)
        paused = value == true
    end
    function self:setBasePosition(position)
        basePosition = position
        offset = Vector2.zero
        panel.Position = position
    end

    -- Created once, reused across opens, and disconnected on destruction.
    local connection = RunService.RenderStepped:Connect(function(dt)
        if not alive or not active or not panel.Visible then return end
        local target = Vector2.zero
        if not paused and not UserInputService.TouchEnabled and UserInputService.MouseEnabled
            and UserInputService:GetFocusedTextBox() == nil then
            local topLeft, bottomRight = GuiService:GetGuiInset()
            local camera = workspace.CurrentCamera
            local viewport = camera and camera.ViewportSize or container.AbsoluteSize
            local visible = viewport - topLeft - bottomRight
            local mouse = UserInputService:GetMouseLocation() - topLeft
            target = Vector2.new(
                math.clamp((mouse.X - visible.X * 0.5) / math.max(1, visible.X * 0.5), -1, 1),
                math.clamp((mouse.Y - visible.Y * 0.5) / math.max(1, visible.Y * 0.5), -1, 1)
            ) * maxOffset
        end
        -- Freeze while rotating the preview, so a captured drag cannot move its target.
        if paused then return end
        local parentSize = container.AbsoluteSize
        local extent = panel.AbsoluteSize
        local anchor = panel.AnchorPoint
        local origin = Vector2.new(
            parentSize.X * basePosition.X.Scale + basePosition.X.Offset,
            parentSize.Y * basePosition.Y.Scale + basePosition.Y.Offset
        )
        local left = origin.X - extent.X * anchor.X
        local top = origin.Y - extent.Y * anchor.Y
        local minX, maxX = padding - left, parentSize.X - padding - left - extent.X
        local minY, maxY = padding - top, parentSize.Y - padding - top - extent.Y
        if screenGui and screenGui.IgnoreGuiInset then
            local topLeft, bottomRight = GuiService:GetGuiInset()
            minX += topLeft.X; minY += topLeft.Y
            maxX -= bottomRight.X; maxY -= bottomRight.Y
        end
        target = Vector2.new(
            minX <= maxX and math.clamp(target.X, minX, maxX) or 0,
            minY <= maxY and math.clamp(target.Y, minY, maxY) or 0
        )
        local alpha = 1 - math.exp(-math.min(dt, 0.25) / math.max(0.001, smoothTime))
        offset = offset:Lerp(target, alpha)
        panel.Position = UDim2.new(basePosition.X.Scale, basePosition.X.Offset + offset.X,
            basePosition.Y.Scale, basePosition.Y.Offset + offset.Y)
    end)
    function self:destroy()
        if not alive then return end
        alive = false
        connection:Disconnect()
    end
    panel.Destroying:Once(function() self:destroy() end)
    return self
end

return FloatingUIController
