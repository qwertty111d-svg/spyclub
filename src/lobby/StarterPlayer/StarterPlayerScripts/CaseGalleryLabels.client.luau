-- Legacy showcases are entry points to category Rolls; no case coin price is shown.
local Players=game:GetService("Players")
local Storage=game:GetService("ReplicatedStorage")
local touch=game:GetService("UserInputService").TouchEnabled
local player=Players.LocalPlayer
local shared=Storage:WaitForChild("SpyShared",20)
local catalogModule=shared and shared:WaitForChild("Catalog",10)
if not catalogModule then return end
local Catalog=require(catalogModule)
local translationModule=shared:FindFirstChild("I18n")
local ok,I18n=pcall(function()return translationModule and require(translationModule)end)
local labels={}
local modelCase={AtelierCase="atelier",ClassicCase="midnight",SilverCase="velvet",GoldCase="blackvault"}
local names={atelier={"Ателье","Atelier"},midnight={"Образ агента","Agent appearance"},velvet={"Коллекция клуба","Club collection"},blackvault={"Закрытый архив","Private archive"}}
local function translate(case,id)
 local language=player:GetAttribute("SpyLanguage") or "ru"
 local en=language=="en"
 local title=(names[id] or {id,id})[en and 2 or 1]
 return title,en
end
local function refresh()
 for model,record in pairs(labels) do
  if not model:IsDescendantOf(workspace) then record.gui:Destroy();labels[model]=nil
  else
   local case=Catalog.Cases[record.id]
   if case then
    local title,en=translate(case,record.id)
    record.title.Text=title
    record.category.Text=en and (record.id=="atelier" and "HAIRSTYLES" or "CLUB COLLECTION") or (record.id=="atelier" and "ПРИЧЁСКИ" or "КОЛЛЕКЦИЯ КЛУБА")
    local language=player:GetAttribute("SpyLanguage") or "ru"
    record.price.Text="↻  1 Roll"
    record.prompt.ObjectText=title.." · "..record.price.Text
    record.prompt.ActionText=language=="zh" and "自定义" or en and "CUSTOMIZE" or "ИЗМЕНИТЬ ОБРАЗ"
   end
  end
 end
end
local function bind(model)
 if not model:IsA("Model") or labels[model] then return end
 local id=model:GetAttribute("CaseId") or modelCase[model.Name]
 if not id or not Catalog.Cases[id] then return end
 local prompt=model:FindFirstChild("CasePrompt",true)
 if not prompt and id=="atelier" and model.Parent then prompt=model.Parent:FindFirstChild("CasePrompt",true) end
 local anchor=prompt and prompt.Parent
 if not anchor or not anchor:IsA("BasePart") then return end
 local old=model:FindFirstChild("CaseGalleryLabel")
 if old then old:Destroy() end
 local gui=Instance.new("BillboardGui")
 gui.Name="CaseGalleryLabel";gui.Adornee=anchor;gui.Size=UDim2.fromOffset(touch and 158 or 190,touch and 60 or 72)
 gui.StudsOffsetWorldSpace=Vector3.new(0,2.8,0);gui.MaxDistance=42;gui.AlwaysOnTop=false;gui.LightInfluence=0;gui.Parent=model
 local plate=Instance.new("Frame");plate.Size=UDim2.fromScale(1,1);plate.BackgroundColor3=Color3.fromRGB(20,22,26);plate.BackgroundTransparency=1;plate.BorderSizePixel=0;plate.Parent=gui
 Instance.new("UICorner",plate).CornerRadius=UDim.new(0,6)
 local line=Instance.new("UIStroke",plate);line.Color=Color3.fromRGB(120,115,102);line.Transparency=1;line.Thickness=1
 local function text(y,height,size,color)
  local label=Instance.new("TextLabel");label.BackgroundTransparency=1;label.Position=UDim2.fromOffset(10,y);label.Size=UDim2.new(1,-20,0,height)
  label.Font=Enum.Font.GothamBold;label.TextSize=size;label.TextColor3=color;label.TextTruncate=Enum.TextTruncate.AtEnd
  label.TextStrokeColor3=Color3.fromRGB(11,12,14);label.TextStrokeTransparency=.65;label.Parent=plate;return label
 end
 local category=text(0,1,10,Color3.fromRGB(175,176,171));category.Visible=false
 local title=text(touch and 4 or 6,touch and 26 or 31,touch and 15 or 18,Color3.fromRGB(239,234,224))
 local price=text(touch and 30 or 38,touch and 24 or 27,touch and 14 or 17,Color3.fromRGB(211,191,151));price.Font=Enum.Font.Gotham
 title.Name="CaseName";price.Name="CaseCost"
 labels[model]={id=id,gui=gui,title=title,price=price,category=category,prompt=prompt}
 refresh()
end
local function scan()
 for _,item in ipairs(workspace:GetDescendants()) do
  if item:IsA("Model") and (modelCase[item.Name] or item:GetAttribute("CaseId")) then bind(item) end
 end
end
player:GetAttributeChangedSignal("SpyLanguage"):Connect(refresh)
local scanPending=false
workspace.DescendantAdded:Connect(function(item)
 if (item:IsA("Model") or item:IsA("ProximityPrompt"))and not scanPending then
  scanPending=true;task.defer(function()scanPending=false;scan()end)
 end
end)
scan()
