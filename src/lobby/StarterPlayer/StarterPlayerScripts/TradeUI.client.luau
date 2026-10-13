-- Lobby-only, optional trade dossier. Server snapshots own items and consent.
-- It never participates in SpyClient's mandatory boot flow.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
if not player then return end
local pg = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 5)
if not pg or pg:FindFirstChild("SpyTradeUI") then return end

local C = {
    ink = Color3.fromRGB(26,28,32), panel = Color3.fromRGB(25,27,31),
    card = Color3.fromRGB(34,36,40), border = Color3.fromRGB(87,89,93),
    brass = Color3.fromRGB(221,193,151), paper = Color3.fromRGB(244,240,231),
    muted = Color3.fromRGB(188,187,181), green = Color3.fromRGB(110, 214, 148),
    warning = Color3.fromRGB(228, 159, 137),
}
local COPY = {
 title={"Обмен","Trade"},open={"Обмен","Trade"},close={"Закрыть","Close"},retry={"Обновить","Refresh"},
 give={"ТЫ ОТДАЁШЬ","YOU GIVE"},get={"ТЫ ПОЛУЧАЕШЬ","YOU RECEIVE"},inventory={"ТВОЙ ИНВЕНТАРЬ","YOUR INVENTORY"},
 search={"Найти предмет…","Search items…"},noResults={"Нет подходящих предметов.","No matching items."},
 selectPlayer={"ВЫБЕРИ УЧАСТНИКА","CHOOSE A PARTNER"},noPlayers={"В клубе пока нет других игроков.","There are no other players in this club yet."},
 invitesOn={"Приглашения: ВКЛ","Invitations: ON"},invitesOff={"Приглашения: ВЫКЛ","Invitations: OFF"},
 accept={"Принять","Accept"},decline={"Отклонить","Decline"},invited={"Приглашение · %d с","Invitation · %d s"},
 waitingInvite={"Ждём участника · %d с","Waiting for partner · %d s"},readyWaiting={"Готов · ждём участника","Ready · waiting for partner"},
 ready={"Готов","Ready"},unready={"Не готов","Not ready"},change={"Изменить","Change"},
 review={"Подтверждение через %d с","Confirm in %d s"},reviewReady={"Проверь оба предложения","Check both offers"},
 confirm={"Подтвердить","Confirm"},confirmed={"Подтверждено","Confirmed"},confirmGift={"Подарить","Give gift"},acceptGift={"Принять подарок","Accept gift"},
 cancel={"Отменить","Cancel"},saving={"Сохраняем · не закрывай Roblox","Saving · keep Roblox open"},savingLong={"Всё ещё сохраняем · обнови статус","Still saving · refresh to check"},
 complete={"ОБМЕН ЗАВЕРШЁН","EXCHANGE COMPLETE"},giftDelivered={"ПОДАРОК ПЕРЕДАН","GIFT DELIVERED"},giftReceived={"ПОДАРОК ПОЛУЧЕН","GIFT RECEIVED"},
 newTrade={"Новый обмен","New exchange"},cancelled={"Отменено · предметы не переданы","Cancelled · items unchanged"},
 empty={"Нет предметов для выбора.","No items to choose from."},protected={"Нельзя передавать","Cannot be traded"},locked={"Предмет уже зарезервирован","Item is reserved"},
 full={"Все четыре места заняты","All four slots are full"},disconnected={"Нет соединения · обнови","Not connected · refresh"},loading={"Проверяем обмен…","Checking exchange…"},
 timeout={"Ответ задерживается · обнови","Delayed response · refresh"},policyChecking={"Проверяем разрешение…","Checking trading permission…"},
 policyBlocked={"Аккаунту недоступен обмен","This account cannot trade"},policyFailed={"Ошибка проверки · обнови","Permission check failed · refresh"},
 profile={"Профиль загружается · обнови","Profile loading · refresh"},stale={"Предложение изменилось · проверь","Offer changed · check items"},busy={"Игрок уже в обмене","Player is already in a trade"},
 invitesDisabled={"Игрок отключил приглашения","Invitations disabled"},cooldown={"Подожди перед приглашением","Wait before inviting again"},departed={"Игрок вышел из клуба","Player left the club"},
 notOwned={"Предмет больше не твой","Item no longer owned"},invalid={"Предмет недоступен для обмена","Item unavailable for trading"},bothItems={"Выбери хотя бы один предмет","Choose at least one item"},
 nothing={"Ничего","Nothing"},inviteAction={"Пригласить","Invite"},playerBusy={"В обмене","In a trade"},playerLoading={"Загрузка","Loading"},unavailable={"Обмен недоступен · обнови","Trading unavailable · refresh"},
 addItems={"Добавить предметы","Add items"},done={"Готово","Done"},recentExchanges={"Недавние обмены клуба","recent club exchanges"},sampleCount={"%d примеров","%d samples"},
 noSamples={"Нет завершённых обменов с предметами с обеих сторон.","No completed item-for-item exchanges yet."},giftDetail={"Подарок · ничего в ответ","Gift · nothing in return"},
}
local ZH={title="交换",open="交换",close="关闭",retry="刷新",give="你给出",get="你收到",inventory="你的物品",search="搜索物品…",
 noResults="没有匹配物品",selectPlayer="选择玩家",noPlayers="俱乐部里还没有其他玩家",invitesOn="邀请：开",invitesOff="邀请：关",
 accept="接受",decline="拒绝",invited="邀请 · 剩余 %d 秒",waitingInvite="等待玩家 · %d 秒",readyWaiting="已准备 · 等待对方",
 ready="准备",unready="未准备",change="修改",readyMark="已准备",choosing="选择中",review="%d 秒后确认",reviewReady="检查双方物品",
 confirm="确认交换",confirmed="已确认",confirmGift="赠送礼物",acceptGift="接受礼物",cancel="取消",saving="正在保存交换… 请保持 Roblox 开启",
 savingLong="仍在保存。可关闭窗口；服务器会检查结果。",complete="交换完成",received="收到：%s",sent="给出：%s",
 giftDelivered="礼物已送出",giftReceived="礼物已收到",newTrade="新交换",cancelled="交换已取消，物品未转移",empty="没有可选择的物品",
 selected="已选",protected="不可交换",locked="物品已预留",full="已选满四件",disconnected="未连接。请刷新",loading="正在检查…",
 timeout="响应延迟。请刷新；本次交换仍保留。",policyChecking="正在检查交换权限…",policyBlocked="此账号不能交换",
 policyFailed="无法检查权限。请刷新",profile="资料加载中。请刷新",stale="物品已修改。请重新检查",busy="玩家正在交换",
 invitesDisabled="玩家已关闭邀请",cooldown="请稍后再邀请",departed="玩家已离开",notOwned="你已不再拥有该物品",invalid="物品不可交换",
 bothItems="请选择至少一件物品",nothing="无物品",inviteAction="邀请",playerBusy="交换中",playerLoading="加载中",unavailable="暂时无法交换。请刷新",
 addItems="添加物品",done="完成",recentExchanges="俱乐部近期交换",sampleCount="%d 个样本",noSamples="尚无完成的双方物品交换",giftDetail="礼物 · 无需回礼"}
local function tr(key, ...)
    local copy = COPY[key] or COPY.unavailable
    local lang=player:GetAttribute("SpyLanguage")
    return string.format(lang=="zh" and (ZH[key] or copy[2]) or copy[lang=="en" and 2 or 1], ...)
end
local function make(class, parent, properties)
    local object = Instance.new(class)
    for key, value in pairs(properties or {}) do object[key] = value end
    if object:IsA("GuiObject") then
        object.BorderSizePixel = 0
        if not properties.ZIndex then object.ZIndex = parent:IsA("GuiObject") and parent.ZIndex + 1 or 1 end
    end
    object.Parent = parent
    return object
end
local function round(object, radius)
    make("UICorner", object, {CornerRadius = UDim.new(0, math.max(radius or 12,12))})
end
local function stroke(object, color, transparency)
    make("UIStroke", object, {ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = color or C.border, Thickness = 1, Transparency = transparency or .3})
end
local function label(parent, name, text, pos, size, fontSize, color)
    return make("TextLabel", parent, {Name=name, Text=text, Position=pos, Size=size, TextSize=fontSize or 16,
        Font=Enum.Font.BuilderSansMedium, TextColor3=color or C.paper, BackgroundTransparency=1, RichText=false,
        TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Center})
end
local function button(parent, name, text, pos, size, callback, primary)
    local b=make("TextButton",parent,{Name=name,Text=text,Position=pos,Size=size,TextSize=16,
        Font=Enum.Font.BuilderSansBold,TextColor3=primary and C.ink or C.paper,
        BackgroundColor3=primary and C.brass or C.card,AutoButtonColor=true,TextWrapped=true,RichText=false})
    round(b,7);stroke(b,primary and C.brass or C.border,primary and .12 or .35)
    b.Activated:Connect(function() if b.Active and b.Visible then callback() end end)
    return b
end
local function clear(parent)
    for _, object in ipairs(parent:GetChildren()) do object:Destroy() end
end


local gui=make("ScreenGui",pg,{Name="SpyTradeUI",ResetOnSpawn=false,DisplayOrder=90,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
pcall(function()gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets end)
local veil=make("Frame",gui,{Name="TradeVeil",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.76,Visible=false,Active=true})
local panel=make("Frame",gui,{Name="TradePanel",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(920,680),BackgroundColor3=C.panel,BackgroundTransparency=.16,Visible=false,ClipsDescendants=true,ZIndex=5})
round(panel,20);stroke(panel,C.border,.65)
local header=label(panel,"TradeTitle",tr("title"),UDim2.fromOffset(16,8),UDim2.new(1,-136,0,44),26,C.paper)
header.Font=Enum.Font.BuilderSansBold;header.TextWrapped=false;header.TextTruncate=Enum.TextTruncate.AtEnd
local content=make("ScrollingFrame",panel,{Name="TradeContent",Position=UDim2.fromOffset(16,64),Size=UDim2.new(1,-32,1,-148),BackgroundTransparency=1,CanvasSize=UDim2.new(),ScrollBarThickness=3,ScrollBarImageColor3=C.brass,ClipsDescendants=true})
local directory=make("Frame",content,{Name="TradePlayers",Size=UDim2.new(1,-4,0,100),BackgroundTransparency=1})
local selfOffer=make("Frame",content,{Name="SelfOffer",BackgroundColor3=C.card,BackgroundTransparency=.18,Visible=false})
local otherOffer=make("Frame",content,{Name="OtherOffer",BackgroundColor3=C.card,BackgroundTransparency=.18,Visible=false})
local chooser=make("Frame",content,{Name="TradeInventory",BackgroundColor3=C.card,BackgroundTransparency=.12,Visible=false})
local samplesPanel=make("Frame",content,{Name="RecentExchanges",BackgroundTransparency=1,Visible=false})
local giftDisclosure=label(content,"GiftDisclosure","",UDim2.new(),UDim2.new(1,-4,0,24),14,C.brass);giftDisclosure.Visible=false
local status=label(panel,"TradeStatus","",UDim2.new(0,16,1,-84),UDim2.new(1,-32,0,24),14,C.muted)
status.TextWrapped=false;status.TextTruncate=Enum.TextTruncate.AtEnd
local actions=make("Frame",panel,{Name="TradeActions",Position=UDim2.new(0,16,1,-56),Size=UDim2.new(1,-32,0,44),BackgroundTransparency=1})
local seal=label(panel,"SuccessSeal","",UDim2.new(0,16,1,-84),UDim2.new(1,-32,0,24),16,C.green);seal.Visible=false;seal.Font=Enum.Font.BuilderSansBold
local receivedSummary=label(panel,"ReceivedSummary","",UDim2.new(),UDim2.new(),14,C.paper);receivedSummary.Visible=false
local disposed=false
local snapshot={policy="checking",profile={},players={},invitesEnabled=true,exchangeSamples={}}
local current,inflight,errorKey,selectedTarget
local shared,actionRemote,stateRemote
local Catalog,Art,Preview3D,Wardrobe
local generation,epoch=0,0
local requests,retired,successful={},{},{}
local serverOffset,savingSince=0,nil
local lastSequence=0
local compact,shortHeight=false,false
local drawerOpen=false
local inventoryDraft,inventoryQuery="",""
local render,updateControls,request,connectShared,openTrade
local function now()return os.clock()+serverOffset end
local function policyReady()return snapshot.policy=="ready" or (type(snapshot.policy)=="table" and snapshot.policy.state=="ready")end
local function terminal(session)return session and (session.stage=="complete" or session.stage=="cancelled")end
local function canEdit()return current and current.stage=="offering" and policyReady() and not inflight and not snapshot.profile.pendingTrade end
local function friendly(code)
 local keys={protected_item="protected",not_tradeable="protected",not_tradable="protected",trade_locked="locked",inventory_locked="locked",pending_trade="locked",too_many_items="full",bad_offer="invalid",invalid_item="invalid",not_owned="notOwned",empty_offer="bothItems",both_offers_required="bothItems",stale_trade="stale",stale_revision="stale",wrong_revision="stale",early_confirm="reviewReady",review_wait="reviewReady",review_not_elapsed="reviewReady",trade_busy="busy",busy="busy",target_busy="busy",self_busy="busy",invites_disabled="invitesDisabled",cooldown="cooldown",invite_cooldown="cooldown",rate_limited="cooldown",player_left="departed",target_left="departed",target_missing="departed",trade_processing="locked",invalid_offer="invalid",policy_failed="policyFailed",policy_blocked="policyBlocked",policy_checking="policyChecking",profile_unavailable="profile"}
 return keys[code] or "unavailable"
end
local function itemName(id)
 local item=Catalog and Catalog.ById and Catalog.ById[id]
 local lang=player:GetAttribute("SpyLanguage")
 return item and (lang=="zh" and (item.zh or item.en or item.ru) or lang=="en" and item.en or item.ru or item.en) or tostring(id)
end
local function rarityOf(item)
 local rarity=item and Catalog and Catalog.Rarities and Catalog.Rarities[item.rarity]
 local lang=player:GetAttribute("SpyLanguage")
 local chinese={common="普通",uncommon="不常见",rare="稀有",epic="史诗",legendary="传说",mythic="神话"}
 return rarity and (lang=="zh" and (rarity.zh or chinese[item.rarity] or rarity.en) or lang=="en" and rarity.en or rarity.ru or rarity.en) or "",rarity and rarity.color and Color3.fromRGB(table.unpack(rarity.color)) or C.muted
end
local function offerItems(ids)
 local clean={};for _,id in ipairs(ids or {})do if type(id)=="string" and #clean<4 then table.insert(clean,id)end end;return clean
end
local function sendOffer(id)
 if not canEdit()then return end
 local ids=offerItems(current.selfOffer);local found=table.find(ids,id)
 if found then table.remove(ids,found)
 else
  if #ids>=4 then errorKey="full";updateControls();return end
  local item=Catalog and Catalog.ById and Catalog.ById[id]
  local ok,info=pcall(function()return Catalog.tradeInfo(id)end)
  if not item or not ok or not info or info.tradeable~=true or (snapshot.profile.owned or {})[id]~=true then return end
  table.insert(ids,id)
 end
 request("offer",{items=ids})
end
local function fit()
 local size=gui.AbsoluteSize
 if size.X<=0 or size.Y<=0 then size=Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1024,768)end
 compact=size.X<620
 local directoryMode=not current or current.stage=="cancelled"
 local rows=current and math.max(#(current.selfOffer or{}),#(current.otherOffer or{}))or 0
 local rowHeight=size.X<364 and 82 or 62
 local offerHeight=math.max(150,66+rows*(rowHeight+6))
 local sampleCount=type(snapshot.exchangeSamples)=="table"and #snapshot.exchangeSamples or 0
 local sampleHeight=sampleCount>0 and 36+math.min(3,sampleCount)*50 or 92
 local give,get=current and #(current.selfOffer or{})or 0,current and #(current.otherOffer or{})or 0
 local giftHeight=give+get>0 and (give==0 or get==0)and 36 or 0
 local h=directoryMode and 460 or current.stage=="invited"and 280 or drawerOpen and 720 or offerHeight+giftHeight+152+(current.stage=="offering"and sampleHeight+12 or 0)
 panel.Size=UDim2.fromOffset(math.min(directoryMode and 720 or 920,math.max(1,size.X-24)),math.min(h,math.max(1,size.Y-24)))
 shortHeight=size.Y<440
 local quietEdit=current and current.stage=="offering"and not inflight and not errorKey
 content.Position=UDim2.fromOffset(16,shortHeight and 56 or 60);content.Size=UDim2.new(1,-32,1,shortHeight and (quietEdit and -116 or -148)or -152)
 selfOffer.Position=UDim2.new();selfOffer.Size=UDim2.new(.5,-6,0,offerHeight)
 otherOffer.Position=UDim2.new(.5,6,0,0);otherOffer.Size=selfOffer.Size
 chooser.Position=UDim2.fromOffset(0,selfOffer.Size.Y.Offset+12);chooser.Size=UDim2.new(1,-4,0,math.max(284,panel.Size.Y.Offset-selfOffer.Size.Y.Offset-164))
end
local function preview(host, item)
    if not item then return end
    local token=generation
    local fallback=make("Frame",host,{Name="ItemArtFallback",Size=UDim2.fromScale(1,1),BackgroundColor3=C.ink,ClipsDescendants=true})
    local definition=Wardrobe and Wardrobe.Accessories and Wardrobe.Accessories[item.id]
    local assetId=item.wearable and tonumber(item.wearable.assetId) or definition and definition.id
    local image=assetId and ("rbxthumb://type=Asset&id="..assetId.."&w=420&h=420") or item.image or item.icon
    if type(image)=="string" and image~="" then
        make("ImageLabel",fallback,{Name="ItemImage",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Image=image,ScaleType=Enum.ScaleType.Fit})
    else
        label(fallback,"PreviewFallback",itemName(item.id),UDim2.fromOffset(6,4),UDim2.new(1,-12,1,-8),14,C.muted)
    end
    if Art and not assetId then
        pcall(function()
            local art=Art.draw(fallback,item)
            if art then art.Name="CosmeticArt" end
        end)
    end
    -- Each yielding 3D render has its own worker/deadline.
    if not Preview3D then return end
    local modelHost=make("Frame",host,{Name="ModelPreview",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false})
    local finished=false
    task.delay(4,function()
        if not finished then finished=true;pcall(function() modelHost:Destroy() end) end
    end)
    task.spawn(function()
        if generation~=token or not host.Parent then return end
        local ok,result=pcall(function() return Preview3D.mount(modelHost,item,nil,{motion=false}) end)
        if finished or generation~=token or not host.Parent then
            pcall(function() modelHost:Destroy() end);return
        end
        finished=true
        if ok and result then modelHost.Visible=true;fallback.Visible=false
        else modelHost:Destroy() end
    end)
end

local function buildSide(parent,mine)
 clear(parent);round(parent,14);stroke(parent,C.border,.7)
 local identity=mine and {name=player.Name,displayName=player.DisplayName} or current.partner or {}
 local title=label(parent,"OfferHeading",tr(mine and "give" or "get"),UDim2.fromOffset(10,8),UDim2.new(1,-20,0,22),compact and 14 or 16,mine and C.brass or C.paper)
 title.Font=Enum.Font.BuilderSansBold
 local username=label(parent,"ParticipantUsername","@"..tostring(identity.name or ""),UDim2.fromOffset(10,30),UDim2.new(1,-20,0,20),13,C.muted)
 username.TextWrapped=false;username.TextTruncate=Enum.TextTruncate.AtEnd
 local ready=mine and current.selfReady or not mine and current.otherReady
 label(parent,"Readiness",ready and "✓" or "",UDim2.new(1,-30,0,8),UDim2.fromOffset(20,22),18,C.green).TextXAlignment=Enum.TextXAlignment.Right
 local ids=mine and current.selfOffer or current.otherOffer or {}
 if #ids==0 then label(parent,"EmptyOffer",tr("nothing"),UDim2.fromOffset(10,58),UDim2.new(1,-20,0,44),16,C.muted)end
 for index=1,4 do
  local id=ids[index]
  local height=panel.Size.X.Offset<340 and 82 or 62
  local columns=1
  local row=math.floor((index-1)/columns);local col=(index-1)%columns
  local card=button(parent,(mine and "SelfSlot_" or "OtherSlot_")..index,"",UDim2.new(col/columns,8-col*4,0,58+row*(height+6)),UDim2.new(1/columns,-16,0,height),function()if mine and id then sendOffer(id)end end)
  card:SetAttribute("ItemId",id);card.Visible=id~=nil;card.Active=mine and id~=nil and canEdit()or false;card.AutoButtonColor=card.Active
  card.BackgroundTransparency=.25
  if id then
   local item=Catalog and Catalog.ById and Catalog.ById[id];local rarity,color=rarityOf(item)
   card:FindFirstChildOfClass("UIStroke").Color=color
   if not drawerOpen and not compact then
    local host=make("Frame",card,{Name="ItemPreview",Position=UDim2.fromOffset(6,10),Size=UDim2.fromOffset(compact and 32 or 42,42),BackgroundTransparency=1,ClipsDescendants=true});preview(host,item)
   end
   local x=(drawerOpen or compact)and 8 or 56
   local name=label(card,"ItemName",itemName(id),UDim2.fromOffset(x,3),UDim2.new(1,-x-8,0,height-28),compact and 14 or 16,C.paper)
   name.Font=Enum.Font.BuilderSansBold;name.TextTruncate=Enum.TextTruncate.AtEnd
   label(card,"ItemRarity",rarity,UDim2.fromOffset(x,height-23),UDim2.new(1,-x-26,0,20),12,color)
   if mine and not drawerOpen and canEdit()then label(card,"RemoveHint","×",UDim2.new(1,-20,1,-23),UDim2.fromOffset(18,18),16,C.muted)end
  end
 end
end
local function fold(value)
 local result={};for _,code in utf8.codes(string.lower(value))do if code>=1040 and code<=1071 then code+=32 elseif code==1025 then code=1105 end;table.insert(result,utf8.char(code))end;return table.concat(result)
end
local buildInventory
buildInventory=function()
 local chrome=chooser:FindFirstChild("InventoryChrome")
 if not chrome then
  round(chooser,14);stroke(chooser,C.border,.65)
  chrome=make("Frame",chooser,{Name="InventoryChrome",Size=UDim2.new(1,0,0,108),BackgroundTransparency=1})
  label(chrome,"InventoryHeading",tr("inventory"),UDim2.fromOffset(12,8),UDim2.new(1,-108,0,44),16,C.paper).Font=Enum.Font.BuilderSansBold
  button(chrome,"CloseInventory",tr("done"),UDim2.new(1,-92,0,8),UDim2.fromOffset(80,44),function()drawerOpen=false;content.CanvasPosition=Vector2.new();render()end)
  local search=make("TextBox",chrome,{Name="InventorySearch",Text=inventoryDraft,ClearTextOnFocus=false,TextSize=16,Font=Enum.Font.BuilderSansMedium,TextColor3=C.paper,PlaceholderColor3=C.muted,BackgroundColor3=C.ink,BackgroundTransparency=.2,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(12,60),Size=UDim2.new(1,-24,0,44)})
  round(search,12);make("UIPadding",search,{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)})
  search:GetPropertyChangedSignal("Text"):Connect(function()inventoryDraft=search.Text;local ok,q=pcall(fold,search.Text);inventoryQuery=ok and q or "";buildInventory()end)
 end
 chrome.InventoryHeading.Text=tr("inventory");chrome.CloseInventory.Text=tr("done");chrome.InventorySearch.PlaceholderText=tr("search")
 chrome.InventoryHeading.Visible=not shortHeight
 chrome.InventorySearch.Position=UDim2.fromOffset(12,shortHeight and 8 or 60)
 chrome.InventorySearch.Size=UDim2.new(1,shortHeight and -116 or -24,0,44)
 local list=chooser:FindFirstChild("InventoryItems")
 if not list then list=make("ScrollingFrame",chooser,{Name="InventoryItems",Position=UDim2.fromOffset(12,116),Size=UDim2.new(1,-24,1,-128),BackgroundTransparency=1,ScrollBarThickness=3,ScrollBarImageColor3=C.brass,ClipsDescendants=true})end
 clear(list)
 local listTop=shortHeight and 60 or 116
 list.Position=UDim2.fromOffset(12,listTop);list.Size=UDim2.new(1,-24,1,-listTop-12)
 local width=panel.Size.X.Offset-64;local columns=panel.Size.X.Offset<340 and 1 or math.max(2,math.floor((width+8)/154));local cellWidth=math.floor((width-8*(columns-1))/columns)
 local items={}
 for _,item in ipairs(Catalog and Catalog.Items or {})do
  if (snapshot.profile.owned or {})[item.id]==true and (inventoryQuery=="" or string.find(fold(itemName(item.id)),inventoryQuery,1,true))then table.insert(items,item)end
 end
 local h=shortHeight and 62 or 134;list.CanvasSize=UDim2.fromOffset(0,math.ceil(#items/columns)*(h+8))
 for index,item in ipairs(items)do
  local selected=table.find(current.selfOffer or {},item.id)~=nil
  local ok,info=pcall(function()return Catalog.tradeInfo(item.id)end);local eligible=ok and info and info.tradeable==true
  local col,row=(index-1)%columns,math.floor((index-1)/columns)
  local card=button(list,"Item_"..item.id,"",UDim2.fromOffset(col*(cellWidth+8),row*(h+8)),UDim2.fromOffset(cellWidth,h),function()sendOffer(item.id)end)
  card.Active=eligible and canEdit()and(selected or #(current.selfOffer or {})<4);card.AutoButtonColor=card.Active
  local rarity,color=rarityOf(item);local border=card:FindFirstChildOfClass("UIStroke");border.Color=selected and C.brass or color;border.Transparency=selected and .05 or .5
  if not shortHeight then local host=make("Frame",card,{Name="ItemPreview",Position=UDim2.fromOffset(8,6),Size=UDim2.new(1,-16,0,62),BackgroundTransparency=1,ClipsDescendants=true});preview(host,item)end
  label(card,"ItemName",itemName(item.id),UDim2.fromOffset(8,shortHeight and 3 or 72),UDim2.new(1,-16,0,34),14,C.paper).Font=Enum.Font.BuilderSansBold
  label(card,"ItemRarity",eligible and rarity or tr("protected"),UDim2.fromOffset(8,shortHeight and 39 or 106),UDim2.new(1,shortHeight and -70 or -16,0,20),12,eligible and color or C.muted)
  local copies=(snapshot.profile.itemCounts or {})[item.id]or 1
  local count=label(card,"CopyCount","×"..tostring(copies),shortHeight and UDim2.new(1,-50,0,38)or UDim2.fromOffset(6,4),UDim2.fromOffset(44,22),14,C.paper);count.ZIndex=card.ZIndex+8;count.Font=Enum.Font.BuilderSansBold;count.BackgroundColor3=C.ink;count.BackgroundTransparency=.15;round(count,8)
  if selected then local mark=label(card,"SelectedMark","✓",shortHeight and UDim2.new(1,-74,0,38)or UDim2.new(1,-28,0,4),UDim2.fromOffset(22,22),18,C.brass);mark.ZIndex=card.ZIndex+8 end
 end
 if #items==0 then label(list,"NoInventory",tr(inventoryQuery~="" and "noResults" or "empty"),UDim2.new(),UDim2.new(1,0,0,44),15,C.muted)end
end
local function buildSamples(top)
 clear(samplesPanel);samplesPanel.Position=UDim2.fromOffset(0,top);samplesPanel.Size=UDim2.new(1,-4,0,92)
 label(samplesPanel,"RecentExchangesTitle",tr("recentExchanges"),UDim2.fromOffset(0,4),UDim2.new(1,-88,0,28),14,C.muted).Font=Enum.Font.BuilderSansBold
 local valid={}
 for _,sample in ipairs(type(snapshot.exchangeSamples)=="table"and snapshot.exchangeSamples or {})do
  if type(sample)=="table"and type(sample.gave)=="table"and type(sample.received)=="table"and #sample.gave>0 and #sample.received>0 then table.insert(valid,sample)end
 end
 local countText=#valid==1 and player:GetAttribute("SpyLanguage")=="en"and "1 sample"or tr("sampleCount",#valid)
 label(samplesPanel,"ExchangeSampleCount",countText,UDim2.new(1,-88,0,4),UDim2.fromOffset(88,28),12,C.muted).TextXAlignment=Enum.TextXAlignment.Right
 if #valid==0 then label(samplesPanel,"NoExchangeSamples",tr("noSamples"),UDim2.fromOffset(0,36),UDim2.new(1,0,0,52),14,C.muted);return top+92 end
 for index=1,math.min(3,#valid)do
  local names={};for _,ids in ipairs({valid[index].gave,valid[index].received})do local side={};for _,id in ipairs(ids)do table.insert(side,itemName(id))end;table.insert(names,table.concat(side," + "))end
  label(samplesPanel,"ExchangeSample_"..index,table.concat(names,"  ↔  "),UDim2.fromOffset(0,36+(index-1)*50),UDim2.new(1,0,0,46),14,C.paper)
 end
 samplesPanel.Size=UDim2.new(1,-4,0,36+math.min(3,#valid)*50);return top+samplesPanel.Size.Y.Offset
end
local function buildDirectory()
 clear(directory);label(directory,"PlayersHeading",tr("selectPlayer"),UDim2.new(),UDim2.new(1,0,0,28),16,C.paper).Font=Enum.Font.BuilderSansBold
 local count=0;local columns=compact and 1 or 2
 for _,partner in ipairs(snapshot.players or {})do
  if tonumber(partner.id)and partner.id~=player.UserId then
   local index=count;count+=1
   local b=button(directory,"Invite_"..partner.id,"",UDim2.new((index%columns)/columns,0,0,40+math.floor(index/columns)*70),UDim2.new(1/columns,-8,0,62),function()if not current or terminal(current)then request("invite",{targetId=partner.id})end end)
   local name=label(b,"PartnerDisplayName",tostring(partner.displayName or partner.name or ""),UDim2.fromOffset(12,6),UDim2.new(1,-96,0,24),16,C.paper);name.Font=Enum.Font.BuilderSansBold;name.TextWrapped=false;name.TextTruncate=Enum.TextTruncate.AtEnd
   label(b,"PartnerUsername","@"..tostring(partner.name or ""),UDim2.fromOffset(12,32),UDim2.new(1,-96,0,22),13,C.muted).TextWrapped=false
   local available=not partner.busy and partner.available~=false
   label(b,"InviteAction",tr(partner.busy and "playerBusy"or partner.available==false and "playerLoading"or "inviteAction"),UDim2.new(1,-80,0,0),UDim2.fromOffset(68,62),14,available and C.brass or C.muted).TextXAlignment=Enum.TextXAlignment.Right
   b.Active=available and policyReady()and snapshot.profile.ready==true and not snapshot.profile.pendingTrade and not inflight;b.AutoButtonColor=b.Active
  end
 end
 if count==0 then label(directory,"NoPartners",tr("noPlayers"),UDim2.fromOffset(0,40),UDim2.new(1,0,0,62),15,C.muted)end
 local h=40+math.max(1,math.ceil(count/columns))*70;directory.Size=UDim2.new(1,-4,0,h)
 content.CanvasSize=UDim2.fromOffset(0,buildSamples(h+12)+8)
end
local readyButton=button(actions,"ReadyTrade",tr("ready"),UDim2.new(),UDim2.new(.5,-4,0,44),function()if canEdit()then request("ready",{ready=not current.selfReady})end end,true)
local addButton=button(actions,"AddTradeItems",tr("addItems"),UDim2.new(),UDim2.new(.5,-4,0,44),function()drawerOpen=not drawerOpen;render();content.CanvasPosition=Vector2.new(0,drawerOpen and shortHeight and selfOffer.Size.Y.Offset+12 or 0)end)
local confirmButton=button(actions,"ConfirmTrade",tr("confirm"),UDim2.new(),UDim2.new(.5,-4,0,44),function()if current and current.stage=="review"and now()>=(tonumber(current.confirmAt)or math.huge)and not current.selfConfirmed and not inflight then request("confirm")end end,true)
local changeButton=button(actions,"ChangeTradeOffer",tr("change"),UDim2.new(),UDim2.new(.5,-4,0,44),function()if current and current.stage=="review"and not inflight then request("ready",{ready=false})end end)
local acceptButton=button(actions,"AcceptInvite",tr("accept"),UDim2.new(),UDim2.new(.5,-4,0,44),function()if current and current.stage=="invited"and current.inviterId~=player.UserId and not inflight and policyReady()then request("respond",{accept=true})end end,true)
local declineButton=button(actions,"DeclineInvite",tr("decline"),UDim2.new(),UDim2.new(.5,-4,0,44),function()if current and current.stage=="invited"and not inflight then request("respond",{accept=false})end end)
local cancelButton=button(actions,"CancelTrade",tr("cancel"),UDim2.new(),UDim2.new(1,0,0,44),function()if current and current.stage~="saving"and not terminal(current)then request("cancel")end end)
local retryButton=button(panel,"RetryTrade","↻",UDim2.new(1,-108,0,8),UDim2.fromOffset(44,44),function()request("sync")end)
local invitesButton=button(actions,"ToggleInvites",tr("invitesOn"),UDim2.new(),UDim2.new(1,0,0,44),function()if not inflight then request("setInvites",{enabled=snapshot.invitesEnabled~=true})end end)
local newButton=button(actions,"NewTrade",tr("newTrade"),UDim2.new(),UDim2.new(1,0,0,44),function()if terminal(current)then retired[current.id]=true;current=nil;drawerOpen=false;savingSince=nil;epoch+=1;inflight=nil;errorKey=nil;render();request("sync")end end,true)
local launcher
local function backdrop()end
local function setOpen(value)
 if disposed then return end
 panel.Visible=value;veil.Visible=value;player:SetAttribute("SpyTradeOpen",value);launcher.Visible=not value and player:GetAttribute("SpyTradeDockReady")~=true
end
local function closeTrade()if current and current.stage~="saving"and not terminal(current)then request("cancel")end;setOpen(false)end
local closeButton=button(panel,"CloseTrade","×",UDim2.new(1,-60,0,8),UDim2.fromOffset(44,44),closeTrade);closeButton.TextSize=24
launcher=button(gui,"TradeLauncher",tr("open"),UDim2.new(1,-108,1,-112),UDim2.fromOffset(92,44),function()openTrade()end);launcher.ZIndex=2
local function updateLauncher()launcher.Visible=not panel.Visible and player:GetAttribute("SpyTradeDockReady")~=true end
player:GetAttributeChangedSignal("SpyTradeDockReady"):Connect(updateLauncher);updateLauncher()
gui.Destroying:Connect(function()disposed=true;player:SetAttribute("SpyTradeOpen",false)end)
updateControls=function()
 if disposed then return end
 local stage=current and current.stage;local idle=not inflight
 local give,get=current and #(current.selfOffer or {})or 0,current and #(current.otherOffer or {})or 0
 local gift=give+get>0 and (give==0 or get==0)
 readyButton.Visible=stage=="offering";readyButton.Text=tr(current and current.selfReady and "unready"or "ready");readyButton.Active=stage=="offering"and idle and policyReady()and give+get>0 and not snapshot.profile.pendingTrade
 addButton.Visible=stage=="offering"and not drawerOpen;addButton.Active=idle and policyReady()and not snapshot.profile.pendingTrade;addButton.Text=tr("addItems")
 confirmButton.Visible=stage=="review";confirmButton.Text=tr(current and current.selfConfirmed and "confirmed"or gift and (give>0 and "confirmGift"or "acceptGift")or "confirm")
 confirmButton.Active=stage=="review"and idle and not current.selfConfirmed and now()>=(tonumber(current.confirmAt)or math.huge)
 changeButton.Visible=stage=="review";changeButton.Active=changeButton.Visible and idle;changeButton.Text=tr("change")
 acceptButton.Visible=stage=="invited"and current.inviterId~=player.UserId;acceptButton.Active=acceptButton.Visible and idle and policyReady();acceptButton.Text=tr("accept")
 declineButton.Visible=acceptButton.Visible;declineButton.Active=idle;declineButton.Text=tr("decline")
 cancelButton.Visible=stage=="invited"and current.inviterId==player.UserId;cancelButton.Active=idle;cancelButton.Text=tr("cancel")
 newButton.Visible=terminal(current)==true;newButton.Active=idle;newButton.Text=tr("newTrade")
 invitesButton.Visible=not current;invitesButton.Active=idle and actionRemote~=nil;invitesButton.Text=tr(snapshot.invitesEnabled and "invitesOn"or "invitesOff")
 retryButton.Visible=errorKey~=nil or not actionRemote or not policyReady()or snapshot.profile.ready~=true or stage=="saving";retryButton.Active=idle
 local row={};for _,b in ipairs({addButton,readyButton,declineButton,acceptButton,changeButton,confirmButton,cancelButton,invitesButton,newButton})do if b.Visible then table.insert(row,b)end end
 for index,b in ipairs(row)do b.Position=UDim2.new((index-1)/#row,0,0,0);b.Size=UDim2.new(1/#row,index<#row and -6 or 0,0,44);b.TextSize=compact and 14 or 16;b.AutoButtonColor=b.Active;b.TextTransparency=b.Active and 0 or .45 end
 header.Size=UDim2.new(1,retryButton.Visible and -136 or -88,0,44)
 seal.Visible=stage=="complete";seal.Text=tr(gift and(give>0 and "giftDelivered"or "giftReceived")or "complete");status.Visible=not seal.Visible
 if stage=="saving"then status.Text=tr(savingSince and os.clock()-savingSince>=15 and "savingLong"or "saving");status.TextColor3=C.brass
 elseif errorKey then status.Text=tr(errorKey);status.TextColor3=C.warning
 elseif stage=="cancelled"then status.Text=tr("cancelled");status.TextColor3=C.muted
 elseif not actionRemote then status.Text=tr("disconnected");status.TextColor3=C.muted
 elseif not policyReady()then local p=type(snapshot.policy)=="table"and snapshot.policy.state or snapshot.policy;status.Text=tr(p=="blocked"and "policyBlocked"or p=="failed"and "policyFailed"or "policyChecking");status.TextColor3=C.muted
 elseif snapshot.profile.ready~=true then status.Text=tr("profile");status.TextColor3=C.muted
 elseif inflight then status.Text=tr("loading");status.TextColor3=C.muted
 elseif stage=="invited"then status.Text=tr(current.inviterId==player.UserId and "waitingInvite"or "invited",math.max(0,math.ceil((tonumber(current.expiresAt)or now())-now())));status.TextColor3=C.brass
 elseif stage=="review"then local remaining=math.max(0,math.ceil((tonumber(current.confirmAt)or math.huge)-now()));status.Text=remaining>0 and tr("review",remaining)or tr(current.selfConfirmed and "confirmed"or "reviewReady");status.TextColor3=C.brass
 elseif stage=="offering"then status.Text=current.selfReady and tr("readyWaiting")or "";status.TextColor3=C.muted
 else status.Text=""end
 panel:SetAttribute("TradeId",current and current.id or nil);panel:SetAttribute("Revision",current and current.revision or nil)
end
render=function()
 if disposed then return end
 generation+=1;if not current or current.stage~="offering"then drawerOpen=false end;fit();header.Text=tr("title");launcher.Text=tr("open")
 directory.Visible=not current or current.stage=="cancelled"
 local offers=current and current.stage~="invited"and current.stage~="cancelled"
 selfOffer.Visible=offers==true;otherOffer.Visible=offers==true;chooser.Visible=offers and drawerOpen or false;samplesPanel.Visible=directory.Visible or offers and current.stage=="offering"and not drawerOpen or false;giftDisclosure.Visible=false
 if directory.Visible then buildDirectory()
 elseif offers then
  buildSide(selfOffer,true);buildSide(otherOffer,false)
  local h=selfOffer.Size.Y.Offset
  local give,get=#(current.selfOffer or{}),#(current.otherOffer or{})
  if give+get>0 and (give==0 or get==0)then giftDisclosure.Visible=true;giftDisclosure.Text=tr("giftDetail");giftDisclosure.Position=UDim2.fromOffset(0,h+6);h+=36 end
  if drawerOpen then chooser.Position=UDim2.fromOffset(0,h+12);buildInventory();h+=12+chooser.Size.Y.Offset elseif current.stage=="offering"then h=buildSamples(h+12)end
  content.CanvasSize=UDim2.fromOffset(0,h+8)
 else
  clear(directory);directory.Visible=true;local partner=current and current.partner or {}
  label(directory,"InvitationIdentity",tostring(partner.displayName or partner.name or "").."\n@"..tostring(partner.name or ""),UDim2.fromOffset(8,8),UDim2.new(1,-16,0,94),24,C.paper).Font=Enum.Font.BuilderSansBold
  directory.Size=UDim2.new(1,-4,0,110);content.CanvasSize=UDim2.fromOffset(0,110)
 end
 updateControls()
end
local stageOrder={invited=1,offering=2,review=3,saving=4,complete=5,cancelled=5}
local function received(msg)
    if disposed then return end
    if type(msg)~="table" then return end
    if type(msg.sequence)=="number" and msg.sequence<lastSequence then return end
    local receipt=msg.requestId and requests[msg.requestId]
    if msg.requestId and (not receipt or receipt.epoch~=epoch) then return end
    local incoming=type(msg.session)=="table" and msg.session or nil
    if incoming and retired[incoming.id] and not current and receipt and receipt.action=="sync" and terminal(incoming) then
        incoming=nil -- Refresh profile/roster without restoring a dismissed receipt.
    end
    if incoming then
        if type(incoming.id)~="string" or retired[incoming.id] or not stageOrder[incoming.stage] then return end
        if current and incoming.id~=current.id then
            if not terminal(current) then return end
            retired[current.id]=true;epoch+=1
        elseif current then
            if (tonumber(incoming.revision) or -1)<(tonumber(current.revision) or 0) then return end
            if current.stage=="saving" and incoming.stage~="saving" and not terminal(incoming) then return end
            if terminal(current) and incoming.stage~=current.stage then return end
        end
    elseif current then
        -- Old nil snapshots cannot erase a live trade. Saving requires an
        -- explicit terminal result before its identity may be released.
        if not receipt or receipt.action~="sync" or receipt.id~=current.id or current.stage=="saving"
            or (receipt.revision or -1)<(current.revision or 0) then return end
        retired[current.id]=true;epoch+=1
    end
    if inflight and msg.requestId==inflight.token then inflight=nil end
    if type(msg.sequence)=="number" then lastSequence=msg.sequence end
    if tonumber(msg.serverNow) then serverOffset=msg.serverNow-os.clock() end
    local previous=current
    snapshot=msg;snapshot.profile=type(msg.profile)=="table" and msg.profile or {};snapshot.players=type(msg.players)=="table" and msg.players or {}
    current=incoming
    if current and current.stage=="saving" then
        if not previous or previous.id~=current.id or previous.stage~="saving" then savingSince=os.clock() end
    else savingSince=nil end
    errorKey=msg.ok==false and friendly(msg.code) or nil
    if current and current.stage=="invited" and (not previous or previous.id~=current.id) then setOpen(true) end
    render()
end
request=function(action, extra)
    if disposed then return end
    connectShared()
    if not actionRemote then errorKey="disconnected";updateControls();return end
    if inflight and action~="cancel" then return end
    local payload={action=action,requestId=HttpService:GenerateGUID(false)}
    if current then payload.id=current.id;payload.revision=current.revision end
    for key,value in pairs(extra or {}) do payload[key]=value end
    local token=payload.requestId
    requests[token]={epoch=epoch,id=payload.id,revision=payload.revision,action=action}
    inflight={token=token};errorKey=nil
    local ok=pcall(function()actionRemote:FireServer(payload)end)
    if not ok then inflight=nil;errorKey="disconnected" end
    render()
    task.delay(12,function()
        if inflight and inflight.token==token then inflight=nil;errorKey="timeout";render() end
    end)
end
local observed, loadingModules = {}, {}
local function loadOptional(name)
    if loadingModules[name] or not shared then return end
    local object=shared:FindFirstChild(name)
    if not object or not object:IsA("ModuleScript") then return end
    loadingModules[name]=true
    task.spawn(function()
        local ok,result=pcall(require,object)
        if ok and type(result)=="table" then
            if name=="Catalog" then Catalog=result elseif name=="Art" then Art=result elseif name=="Preview3D" then Preview3D=result elseif name=="Wardrobe" then Wardrobe=result end
            render()
        end
    end)
end
connectShared=function()
    if disposed then return end
    shared=ReplicatedStorage:FindFirstChild("SpyShared")
    if not shared then return end
    if not observed[shared] then
        observed[shared]=true
        shared.ChildAdded:Connect(function()
            local previous=actionRemote
            connectShared()
            if not previous and actionRemote then request("sync") else render() end
        end)
    end
    local action=shared:FindFirstChild("TradeAction")
    local state=shared:FindFirstChild("TradeState")
    if action and action:IsA("RemoteEvent") and state and state:IsA("RemoteEvent") then
        actionRemote=action
        if stateRemote~=state then stateRemote=state;state.OnClientEvent:Connect(received) end
    end
    for _,name in ipairs({"Catalog","Art","Preview3D","Wardrobe"}) do loadOptional(name) end
end
openTrade=function(targetId)
    if disposed then return end
    selectedTarget=tonumber(targetId)
    setOpen(true);render();request("sync")
end
local opener=pg:FindFirstChild("SpyOpenTrade")
if not opener then opener=make("BindableEvent",pg,{Name="SpyOpenTrade"}) end
if opener:IsA("BindableEvent") then opener.Event:Connect(openTrade) end
ReplicatedStorage.ChildAdded:Connect(function(object)
    if object.Name=="SpyShared" then connectShared();request("sync") end
end)
player:GetAttributeChangedSignal("SpyLanguage"):Connect(render)
player:GetAttributeChangedSignal("SpyReducedMotion"):Connect(function()backdrop();render()end)
player:GetAttributeChangedSignal("SpyEffects"):Connect(backdrop)
local function cameraChanged()
    local camera=Workspace.CurrentCamera
    if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(render) end
    render()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(cameraChanged)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()if not disposed then render()end end)
UserInputService.InputBegan:Connect(function(input,processed)
    if not processed and input.KeyCode==Enum.KeyCode.Escape and panel.Visible then closeTrade() end
end)
local lastTick=0
RunService.Heartbeat:Connect(function()
    if panel.Visible and os.clock()-lastTick>=.2 then lastTick=os.clock();updateControls() end
end)
cameraChanged();connectShared();request("sync")
