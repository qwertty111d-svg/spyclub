-- Lobby cleanup guard.
-- The real match room lives in the separate Match place.
-- This script intentionally removes legacy physical tables and any accidental match-room build from the lobby.

local Workspace = game:GetService("Workspace")

local function cleanup()
    local strayMatch = Workspace:FindFirstChild("SpyMatch")
    if strayMatch then
        strayMatch:Destroy()
    end

    local club = Workspace:FindFirstChild("SpyClub")
    if not club then
        return
    end

    for _, legacyName in ipairs({"Trio", "Quartet", "HighStakes"}) do
        local legacy = club:FindFirstChild(legacyName)
        if legacy then
            legacy:Destroy()
        end
    end

    for _, descendant in ipairs(club:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") and descendant.Name == "JoinTable" then
            descendant.Enabled = false
        end
    end
end

-- Run immediately, then briefly keep guarding while the other bootstrap scripts finish.
cleanup()
for _ = 1, 30 do
    task.wait(0.1)
    cleanup()
end
