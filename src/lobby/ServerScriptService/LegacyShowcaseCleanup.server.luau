-- Retire cosmetic progression showcases without touching investigation cases.
local retired={ClassicCase=true,SilverCase=true,GoldCase=true,AtelierDisplay=true,FeaturedCases=true}
-- The imported cases have separate, generically named podiums. Match the
-- authored base AND cap; nearby furniture and investigation props stay intact.
local podiums={
 {base={37.1096,1.5102,-1.7960},cap={37.1596,3.4402,-1.7860}},
 {base={37.6299,1.2235,-17.6060},cap={37.6799,3.1535,-17.5960}},
 {base={37.4321,1.2885,-10.1400},cap={37.4821,3.2185,-10.1300}},
}
local function near(vector,expected)
 return math.abs(vector.X-expected[1])<=.02
  and math.abs(vector.Y-expected[2])<=.02
  and math.abs(vector.Z-expected[3])<=.02
end
local function isPodiumRoot(node)
 return node.Parent==workspace and node.Name=="Model"and node:IsA("Model")
end
local function isRetiredPodium(node)
 if not isPodiumRoot(node)then return false end
 local children=node:GetChildren()
 for _,signature in ipairs(podiums)do
  local base,cap=false,false
  for _,piece in ipairs(children)do
   if piece:IsA("Part")and near(piece.Size,{2.99,1,2.86})and near(piece.Position,signature.base)then base=true
   elseif piece:IsA("WedgePart")and near(piece.Size,{3.82,.79,1.94})and near(piece.Position,signature.cap)then cap=true end
  end
  if base and cap then return true end
 end
 return false
end
local function retire(node)
 if retired[node.Name]and (node:IsA("Model")or node:IsA("Folder")or node:IsA("BasePart"))then
  node:Destroy()
 elseif isRetiredPodium(node)then
  node:Destroy()
 end
end
-- Authored geometry can arrive after scripts start or while the lobby is built.
local pending=setmetatable({},{__mode="k"})
workspace.DescendantAdded:Connect(function(node)
 local candidate=node
 if not retired[node.Name]then
  while candidate.Parent and candidate.Parent~=workspace do candidate=candidate.Parent end
  if not isPodiumRoot(candidate)then return end
 end
 if pending[candidate]then return end
 pending[candidate]=true
 task.defer(function()
  pending[candidate]=nil
  if candidate.Parent then retire(candidate)end
 end)
end)
for _,node in ipairs(workspace:GetDescendants())do if node.Parent then retire(node)end end
