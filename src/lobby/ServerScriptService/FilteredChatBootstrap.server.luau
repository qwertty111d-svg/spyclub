-- SPY CLUB / BROADCAST CHAT RELAY V5      
local R=game:GetService("ReplicatedStorage")
local P=game:GetService("Players")
local T=game:GetService("TextService")
R:SetAttribute("SpyChatTransport","server_filtered")
local old=R:FindFirstChild("SpyChatFilterProbe");if old then old:Destroy() end
local e=R:FindFirstChild("SpyChatRelay")
if e and not e:IsA("RemoteEvent") then e:Destroy();e=nil end
if not e then e=Instance.new("RemoteEvent");e.Name="SpyChatRelay";e.Parent=R end
local last={}
local function phase(p)
 local t=tostring(p:GetAttribute("SpyRelayTableId") or "");if t=="" then return true end
 local x=p:GetAttribute("SpyRelayTablePhase")
 return x=="Waiting" or x=="Discuss" or x=="Result" or (x=="Hint" and p:GetAttribute("SpyRelayTableTurn")==p.UserId)
end
local function reply(p,id,ok,code,data)e:FireClient(p,{kind="status",id=id,ok=ok,code=code,data=data})end
e.OnServerEvent:Connect(function(p,v)
 if type(v)~="table" or type(v.text)~="string" then return end
 local id=tostring(v.id or ""):sub(1,80);local text=v.text;local n=utf8.len(text)
 if id=="" or not n or n<1 or n>180 or not text:match("%S") then reply(p,id,false,"bad_text");return end
 if p:GetAttribute("SpyAdminMuted")==true or not phase(p) then reply(p,id,false,"blocked");return end
 local now=os.clock();if now-(last[p.UserId] or -1000)<.8 then reply(p,id,false,"rate_limited");return end;last[p.UserId]=now
 local fOk,res=pcall(function()return T:FilterStringAsync(text,p.UserId)end)
 if not fOk or not res then reply(p,id,false,"filter_failed");return end
 local a,msg=pcall(function()return res:GetNonChatStringForBroadcastAsync()end)
 if not a or type(msg)~="string" or not msg:match("%S") then reply(p,id,false,"empty_filtered");return end
 local delivered=0
 for _,to in ipairs(P:GetPlayers()) do
  delivered+=1
  e:FireClient(to,{kind="message",id=id,fromUserId=p.UserId,name=p.DisplayName,text=msg})
 end
 print("[SPY CHAT RELAY] sender="..p.UserId.." broadcast_delivered="..delivered)
 reply(p,id,true,"ok",{delivered=delivered,attempted=delivered})
                                                                                                                                        end)
P.PlayerRemoving:Connect(function(p)last[p.UserId]=nil end)
