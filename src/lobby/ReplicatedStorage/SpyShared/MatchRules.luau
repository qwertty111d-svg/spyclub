-- Shared, pure validation. Lobby and Match use the same contract.
local Rules = {}
Rules.ThemeIds = {"cities","countries","animals","professions","food","brands","games","dota2_characters","movies","series","cartoons","anime_characters","superheroes","mythology","transport","sports","instruments","space","clothes","household","technology","places","school_subjects","game_characters","fairytale_characters","drinks","nature","emotions"}
local themes = {}
for _,id in ipairs(Rules.ThemeIds) do themes[id]=true end
function Rules.defaults()
 return {allowedThemes=table.clone(Rules.ThemeIds),topicMode="vote",discussionSeconds=30,hintSeconds=45,hintLaps=1,allowExtraRound=true,mode="classic"}
end
function Rules.sanitize(raw)
 if raw==nil then return Rules.defaults() end
 if type(raw)~="table" or type(raw.allowedThemes)~="table" or #raw.allowedThemes>64 then return nil end
 if raw.mode~=nil and raw.mode~="classic"and raw.mode~="case"then return nil end
 local allowed,seen={},{}
 for _,id in ipairs(raw.allowedThemes) do
  if type(id)~="string" or not themes[id] then return nil end
  if not seen[id] then seen[id]=true;table.insert(allowed,id) end
 end
 if #allowed==0 or (raw.topicMode~="vote" and raw.topicMode~="random") then return nil end
 if type(raw.allowExtraRound)~="boolean" then return nil end
 if not ({[20]=true,[30]=true,[45]=true,[60]=true})[raw.discussionSeconds] then return nil end
 local hintSeconds=raw.hintSeconds
 if hintSeconds==nil then hintSeconds=45 end
 if not ({[20]=true,[30]=true,[45]=true,[60]=true})[hintSeconds] then return nil end
 if raw.hintLaps~=1 and raw.hintLaps~=2 then return nil end
 return {allowedThemes=allowed,topicMode=raw.topicMode,discussionSeconds=raw.discussionSeconds,hintSeconds=hintSeconds,hintLaps=raw.hintLaps,allowExtraRound=raw.allowExtraRound,mode=raw.mode or"classic"}
end
function Rules.pool(rules,catalog,random)
 local pool={}
 for _,id in ipairs(rules.allowedThemes) do
  local theme=catalog.GetById(id)
  if theme and type(theme.words)=="table" and #theme.words>0 then table.insert(pool,theme) end
 end
 for i=#pool,2,-1 do
  local j=random:NextInteger(1,i);pool[i],pool[j]=pool[j],pool[i]
 end
 return pool
end
function Rules.canVote(voter,target,members)
 return type(target)=="number" and target==target and target%1==0 and voter~=target and members[voter]~=nil and members[target]~=nil
end
return Rules
