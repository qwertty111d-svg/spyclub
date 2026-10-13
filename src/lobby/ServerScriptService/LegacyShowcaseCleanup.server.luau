-- Retire cosmetic progression showcases without touching investigation cases.
local retired={ClassicCase=true,SilverCase=true,GoldCase=true,AtelierDisplay=true,FeaturedCases=true}
local function retire(node)
 if retired[node.Name]and (node:IsA("Model")or node:IsA("Folder")or node:IsA("BasePart"))then
  node:Destroy()
 end
end
-- Authored geometry can arrive after scripts start or while the lobby is built.
workspace.DescendantAdded:Connect(function(node)
 if retired[node.Name]then task.defer(function()if node.Parent then retire(node)end end)end
end)
for _,node in ipairs(workspace:GetDescendants())do if node.Parent then retire(node)end end
