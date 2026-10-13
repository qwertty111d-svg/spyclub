-- Changing identity must use the same durable wallet/retry contract as cosmetics.
local Catalog=loadModule("Catalog")
local Economy=loadModule("Economy")
local initial=Economy.new(Catalog)
check(type(initial.identity)=="table","new profiles include a saved character identity")
local Identity=loadModule("CharacterIdentity")
local Config=loadModule("AccessoryRollConfig")
local Rules=loadModule("AccessoryRollRules")
local Profiles=loadModule("Profiles")
local Service=loadModule("AccessoryRollService")

check(Identity.validate(initial.identity),"default nationality and names belong together")
check(initial.identity.nationality==Economy.new(Catalog).identity.nationality
    and initial.identity.firstName==Economy.new(Catalog).identity.firstName,"defaults are deterministic")
check(initial.rolls==5,"default identity is free")
local legacy=clone(initial);legacy.identity=nil;legacy.coins=777;legacy.rolls=8
legacy.equipped.hair="hair_charmer";legacy.itemCounts.gold=3
Economy.migrate(legacy,Catalog)
check(Identity.validate(legacy.identity),"legacy profiles receive valid identity")
check(legacy.coins==777 and legacy.rolls==8 and legacy.equipped.hair=="hair_charmer"
    and legacy.itemCounts.gold==3,"identity migration preserves wallet and equipment")
local before=clone(legacy.identity);Economy.migrate(legacy,Catalog)
check(legacy.identity.firstName==before.firstName and legacy.rolls==8,"identity migration is repeatable")

for _,id in ipairs({"nationality","firstName","lastName"})do
    check(Config.ById[id] and Config.ById[id].identity==true,"identity category "..id)
    local entries=Identity.pool(id,initial.identity)
    check(#entries>1,"every identity field has choices: "..id)
    local total=0
    for _,entry in ipairs(entries)do
        total+=entry.chance
        check(math.abs(entry.chance-100/#entries)<1e-8,"identity probability is uniform")
        check(type(entry.item.labelEn)=="string" and type(entry.item.labelRu)=="string","choice labels available")
    end
    check(math.abs(total-100)<1e-8,"identity probabilities total 100")
    check(Rules.select(entries,0).id==entries[1].item.id
        and Rules.select(entries,100).id==entries[#entries].item.id,"identity boundary selection")
end
local public=Economy.public(initial)
check(Identity.validate(public.identity),"public profile includes identity")
public.identity.firstName="tampered"
check(Identity.validate(initial.identity),"public identity is isolated from durable state")

local function identityCommand(profile,sequence,category,result)
    return {kind="accessoryRoll",category=category,requestId=tostring(sequence).."-identitytest0001",
        sequence=sequence,prepared=true,identity=clone(result),sourceNationality=profile.identity.nationality}
end
local function transact(profile,command,suffix)
    return select(2,Economy.transaction(profile,"identity:"..command.requestId..(suffix or ""),command,Catalog))
end
local sameNation=Economy.new(Catalog)
local differentNames=clone(sameNation.identity)
local defaultNation=Identity.ById[differentNames.nationality]
differentNames.firstName=defaultNation.firstNames[2]
differentNames.lastName=defaultNation.lastNames[2]
local sameNationReceipt=transact(sameNation,identityCommand(sameNation,1,"nationality",differentNames))
check(sameNationReceipt.ok and not sameNationReceipt.duplicate,"same nationality with new names is a changed dossier")
local unchangedReceipt=transact(sameNation,identityCommand(sameNation,2,"nationality",sameNation.identity))
check(unchangedReceipt.ok and unchangedReceipt.duplicate,"only identical full identity is a duplicate dossier")
local nation=Identity.Nations[2]
local nextIdentity={nationality=nation.id,firstName=nation.firstNames[2],lastName=nation.lastNames[2]}
local changed=clone(initial)
local nationalityCommand=identityCommand(changed,1,"nationality",nextIdentity)
local receipt=transact(changed,nationalityCommand)
check(receipt.ok and receipt.code=="identityRolled" and Identity.validate(changed.identity),"nationality updates all consistent fields")
check(changed.identity.nationality==nation.id and changed.identity.firstName==nation.firstNames[2]
    and changed.identity.lastName==nation.lastNames[2],"server selected identity becomes saved identity")
check(changed.rolls==4 and changed.rollSequence==1 and receipt.rollsSpent==1,"nationality costs exactly one roll")
check(changed.equipped.card==initial.equipped.card and changed.itemCounts.classic==initial.itemCounts.classic,
    "identity never changes inventory or appearance")
local replay=transact(changed,nationalityCommand,"-replay")
check(replay.ok and changed.rolls==4 and replay.identity.firstName==receipt.identity.firstName,"same identifier cannot spend twice")
local conflict=clone(nationalityCommand);conflict.category="firstName"
check(transact(changed,conflict,"-conflict").code=="roll_request_conflict" and changed.rolls==4,"same request cannot change category")

local first=clone(changed.identity);first.firstName=nation.firstNames[3]
local firstReceipt=transact(changed,identityCommand(changed,2,"firstName",first))
check(firstReceipt.ok and changed.identity.firstName==first.firstName and changed.identity.lastName==nextIdentity.lastName
    and changed.identity.nationality==nation.id,"first name rerolls only within nationality")
local last=clone(changed.identity);last.lastName=nation.lastNames[3]
check(transact(changed,identityCommand(changed,3,"lastName",last)).ok and changed.identity.firstName==first.firstName
    and changed.identity.lastName==last.lastName,"surname preserves first name")
local balance=changed.rolls
local invalid=clone(changed.identity);invalid.firstName="not in curated pool"
check(not transact(changed,identityCommand(changed,4,"firstName",invalid)).ok and changed.rolls==balance,"invalid name never spends")
local wrong=clone(changed.identity);wrong.nationality=Identity.Nations[1].id
check(not transact(changed,identityCommand(changed,4,"firstName",wrong),"-wrongnation").ok
    and changed.rolls==balance,"name category cannot change nationality")
local stale=identityCommand(changed,4,"lastName",last);stale.sourceNationality=Identity.Nations[1].id
check(transact(changed,stale,"-stale").code=="roll_stale_request" and changed.rolls==balance,"nationality race rejects stale pool")
local both=clone(changed.identity);both.lastName=nation.lastNames[4];both.firstName=nation.firstNames[4]
check(not transact(changed,identityCommand(changed,4,"lastName",both),"-twofields").ok
    and changed.rolls==balance,"name roll cannot mutate another field")
changed.pendingTrade={id="pending"}
check(transact(changed,identityCommand(changed,4,"lastName",last),"-trade").code=="trade_processing"
    and changed.rolls==balance,"trade lock cannot consume identity roll")
changed.pendingTrade=nil;changed.rolls=0
check(transact(changed,identityCommand(changed,4,"lastName",last),"-empty").code=="roll_empty", "empty identity wallet cannot spend")

-- Avatar assets deliberately throw: identity DTOs/rolls must not touch them.
Wardrobe.prepare=function()error("identity attempted avatar preparation")end
Wardrobe.validate=function()error("identity attempted avatar validation")end
local function fresh()
    store.data=nil;store.mode=nil;store.writes=0;draws=0;clock+=2
    player.Character=nil
    local profiles=Profiles.new();check(profiles:load(7),"identity service profile loaded")
    return profiles,Service.new(profiles,{hasLuck=function()return true end})
end
local profiles,service=fresh()
local dto=service:snapshot(player,profiles:public(7))
check(Identity.validate(dto.identity),"snapshot exposes identity without an avatar")
local identityRows=0
for _,row in ipairs(dto.categories)do
    if row.identity then
        identityRows+=1
        check(row.available and row.lucky==false and row.distribution=="uniform","identity available with no rarity/luck advantage")
        check(#row.items>1 and next(row.chances)==nil,"snapshot exposes actual uniform choices")
    else check(not row.available,"cosmetics remain unavailable until avatar ready")end
end
check(identityRows==3,"all three identity fields exposed")
local rolled=service:roll(player,"nationality","1-serviceidentity0001")
check(rolled.ok and Identity.validate(store.data.identity) and store.data.rolls==4,"identity succeeds without character")
check(draws==3,"nationality draws nation and two names once despite luck perk")
clock+=2
local nameResult=service:roll(player,"firstName","2-serviceidentity0002")
check(nameResult.ok and draws==4,"name uses one uniform server draw")
local nameDTO=service:snapshot(player,profiles:public(7))
check(nameDTO.identity.firstName==nameResult.identity.firstName,"snapshot cache refreshes identity names")
clock+=2
check(service:roll(player,"hat","3-servicecosmetic0003").code=="appearanceLoading","cosmetic remains gated by avatar")

profiles,service=fresh();store.mode="after"
local uncertain=service:roll(player,"nationality","1-lostidentity00001")
check(uncertain.code=="save_failed" and profiles.cache[7]==nil,"uncertain identity write invalidates cache")
check(store.data.rolls==4 and draws==3 and Identity.validate(store.data.identity),"retry callbacks never redraw or charge again")
store.mode=nil
local recovered=service:roll(player,"nationality","1-lostidentity00001")
check(recovered.ok and recovered.replayed and store.data.rolls==4 and draws==3,"lost reply recovers same identity without spending")
local reloaded=Economy.migrate(clone(store.data),Catalog)
check(Identity.validate(reloaded.identity) and reloaded.identity.firstName==recovered.identity.firstName,"identity survives reconnect migration")

-- A match phase gate forbids new spending, while saved replies remain recoverable.
profiles,service=fresh()
local allowed=false
service.options.canRoll=function()return allowed end
local closed=service:roll(player,"nationality","1-phaseidentity0001")
check(closed.code=="roll_match_active" and store.data.rolls==5 and draws==0,"closed phase cannot draw or spend a new roll")
allowed=true
local beforeClosure=service:roll(player,"nationality","1-phaseidentity0001")
check(beforeClosure.ok and store.data.rolls==4 and draws==3,"open phase accepts identity roll")
allowed=false
local afterClosure=service:roll(player,"nationality","1-phaseidentity0001")
check(afterClosure.ok and afterClosure.replayed and store.data.rolls==4 and draws==3,"saved receipt replays after phase closes")
local late=service:roll(player,"firstName","2-phaseidentity0002")
check(late.code=="roll_match_active" and store.data.rolls==4 and draws==3,"closed phase still denies the next sequence")
local staleClosed=service:roll(player,"firstName","1-phaseotherguid0001")
check(staleClosed.code=="roll_stale_request","stale sequence validation precedes phase denial")

-- Catalog preparation can yield while the match begins; check the gate again.
profiles,service=fresh();player.Character=character
allowed=true;service.options.canRoll=function()return allowed end
Wardrobe.Accessories.black_tie={id=1}
local assetReady=false
Wardrobe.prepare=function(_,timeout)
    if timeout>0 then allowed=false;assetReady=true end
    return assetReady
end
Wardrobe.validate=function()return true end
local beganDuringPreparation=service:roll(player,"tie","1-phasepreparation001")
check(beganDuringPreparation.code=="roll_match_active" and store.data.rolls==5
    and draws==0 and not store.data.owned.black_tie,"phase closing during asset preparation prevents draw and spending")
print("Identity roll integration: "..assertions.." assertions passed (Roblox service stubs; no Studio Play Test)")
