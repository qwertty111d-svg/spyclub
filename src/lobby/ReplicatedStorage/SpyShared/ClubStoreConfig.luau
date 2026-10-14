-- A permanent, deterministic collection. Never converts coins to random Rolls.
local Config={Version=1,Items={
    {id="burgundy_dossier",price=350,kind="card",rarity="uncommon",art="seal",ru="Бордовый архив",en="Burgundy dossier",color={176,109,105},dark={47,24,29}},
    {id="burnished_watch",price=750,kind="trinket",rarity="rare",art="watch",ru="Латунные часы",en="Burnished watch",color={204,174,117},dark={37,31,24}},
    {id="velvet_lapel_pin",price=600,kind="trinket",rarity="rare",art="pin",ru="Значок «Бархат»",en="Velvet lapel pin",color={177,69,78},dark={47,23,28}},
    {id="black_cipher_card",price=900,kind="card",rarity="epic",art="cipher",ru="Чёрный шифр",en="Black cipher",color={206,183,140},dark={23,24,28}},
},DailyItems={
    {id="noir_calling_card",price=0,kind="card",rarity="rare",art="file",ru="Приглашение в клуб",en="Club invitation",color={235,217,181},dark={44,32,29}},
    {id="club_seal_pin",price=0,kind="trinket",rarity="epic",art="pin",ru="Печать клуба",en="Club seal",color={220,188,125},dark={37,29,26}},
},ById={}}
for _,item in ipairs(Config.Items)do Config.ById[item.id]=item end
for _,item in ipairs(Config.DailyItems)do item.dailyOnly=true;Config.ById[item.id]=item end
return Config
