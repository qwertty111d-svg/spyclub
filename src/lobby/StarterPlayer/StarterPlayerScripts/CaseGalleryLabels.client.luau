-- Retired: the H dossier is the character collection entry point.
-- Remove only obsolete cosmetic showroom labels, including late replication.
local function retire(node)
 if node:IsA("BillboardGui")and node.Name=="CaseGalleryLabel"then node:Destroy()end
end
workspace.DescendantAdded:Connect(retire)
for _,node in ipairs(workspace:GetDescendants())do retire(node)end
