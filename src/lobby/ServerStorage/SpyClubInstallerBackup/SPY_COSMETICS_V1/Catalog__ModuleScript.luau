-- Public cosmetic catalogue. All coins are earned in play, never bought with Robux.
local Catalog = {
    CapsulePrice = 200, DuplicateRefund = 45,
    DuplicateRefundByRarity = {starter=0, common=25, uncommon=50, rare=100, epic=250, legendary=600, mythic=1500},
    Rarities = {
        starter={rank=0,color={166,166,171},ru="Стартовый",en="Starter"},
        common={rank=1,color={174,178,184},ru="Обычный",en="Common"},
        uncommon={rank=2,color={91,190,121},ru="Необычный",en="Uncommon"},
        rare={rank=3,color={76,139,238},ru="Редкий",en="Rare"},
        epic={rank=4,color={169,91,232},ru="Эпический",en="Epic"},
        legendary={rank=5,color={238,181,73},ru="Легендарный",en="Legendary"},
        mythic={rank=6,color={224,55,78},ru="Мифический",en="Mythic"},
    },
    WelcomeCoins = 120,
    RoundCoins = 20, WinCoins = 15, MilestoneRounds = 3, MilestoneCoins = 50,
    Items = {
        {id="classic", kind="card", rarity="starter", ru="Личное дело", en="Personal file", price=0, art="file", color={151,177,190}, dark={27,38,49}},
        {id="soft", kind="effect", rarity="starter", ru="Тихий свет", en="Quiet light", price=0, art="orbit", color={150,212,199}, dark={26,46,47}},
        {id="copper", kind="card", rarity="common", ru="Медный шифр", en="Copper cipher", price=120, weight=25, art="cipher", color={223,162,97}, dark={56,38,30}},
        {id="mint", kind="card", rarity="common", ru="Зелёный код", en="Jade code", price=120, weight=25, art="cipher", color={124,225,187}, dark={22,48,42}},
        {id="moon", kind="card", rarity="uncommon", ru="Лунное дело", en="Moon dossier", price=200, weight=18, art="moon", color={174,195,243}, dark={28,38,64}},
        {id="seal", kind="card", rarity="uncommon", ru="Красная печать", en="Crimson seal", price=200, weight=15, art="seal", color={246,135,145}, dark={60,29,38}},
        {id="violet", kind="card", rarity="rare", ru="Полночный архив", en="Midnight archive", price=360, weight=10, art="orbit", color={189,153,246}, dark={40,29,63}},
        {id="gold", kind="card", rarity="legendary", ru="Всевидящее око", en="Golden eye", price=900, weight=2, art="eye", color={251,207,121}, dark={57,43,22}},
        {id="mint_burst", kind="effect", rarity="rare", ru="Изумрудная вспышка", en="Emerald flare", price=400, weight=4, art="orbit", color={115,241,189}, dark={21,52,44}},
        {id="embers", kind="effect", rarity="legendary", ru="Золотые искры", en="Golden embers", price=1000, weight=1, art="seal", color={255,187,94}, dark={65,36,20}},
        {id="watch", kind="trinket", rarity="uncommon", ru="Карманные часы", en="Pocket watch", price=220, art="watch", color={223,188,121}, dark={47,38,28}},
        {id="lens", kind="trinket", rarity="common", ru="Лупа сыщика", en="Detective lens", price=160, art="lens", color={142,207,213}, dark={24,43,49}},
        {id="dice", kind="trinket", rarity="uncommon", ru="Кость подозрений", en="Dice of doubt", price=180, art="dice", color={233,224,204}, dark={48,45,43}},
    },
    ById = {},
}
local extra={
    {id="tuxedo",kind="outfit",rarity="rare",ru="Смокинг «Полночь»",en="Midnight tuxedo",price=0,dailyOnly=true,art="file",color={230,211,168},dark={24,27,31},outfit="tuxedo"},
    {id="tophat",kind="accessory",rarity="epic",ru="Цилиндр джентльмена",en="Gentleman's top hat",price=240,art="seal",color={212,184,122},dark={29,31,34}},
    {id="wave",kind="emote",rarity="common",ru="Приветствие сыщика",en="Detective greeting",price=160,art="orbit",color={133,212,177},dark={25,44,39}},
    {id="gilded_frame",kind="frame",rarity="rare",ru="Золочёная рамка",en="Gilded frame",price=300,art="eye",color={237,195,112},dark={51,38,25}},
    {id="night_guest",kind="title",rarity="uncommon",ru="Ночной гость",en="Night guest",price=180,art="moon",color={178,192,239},dark={29,35,54}},
    {id="notebook",kind="gadget",rarity="common",ru="Блокнот подсказок",en="Clue notebook",price=60,quantity=3,art="file",color={211,198,157},dark={43,39,28}},
    {id="history",kind="gadget",rarity="common",ru="Архив голосований",en="Ballot archive",price=60,quantity=3,art="cipher",color={161,203,194},dark={29,44,45}},
    {id="archivist",kind="title",rarity="rare",ru="Архивариус",en="Archivist",price=0,art="file",color={166,213,191},dark={29,45,42},setReward=true},
    {id="noir_frame",kind="frame",rarity="legendary",ru="Рамка «Нуар»",en="Noir frame",price=0,art="eye",color={202,175,239},dark={40,31,51},setReward=true},
    {id="supporter",kind="title",rarity="legendary",ru="Меценат клуба",en="Club patron",price=0,art="seal",color={244,211,150},dark={48,40,26},premium=true},
    {id="obsidian_frame",kind="frame",rarity="legendary",ru="Обсидиановая рамка",en="Obsidian frame",price=0,caseOnly=true,art="eye",color={107,232,190},dark={12,22,22}},
    {id="velvet_patron",kind="title",rarity="epic",ru="Хозяин бархата",en="Velvet patron",price=0,caseOnly=true,art="seal",color={220,151,178},dark={50,24,36}},
    {id="black_tie",kind="cosmetic",category="Галстук",equipSlot="tie",rarity="common",ru="Чёрный галстук",en="Black tie",price=0,caseOnly=true,art="tie",color={180,183,188},dark={24,25,29},wearable={builder="tie",accent="black"}},
    {id="burgundy_tie",kind="cosmetic",category="Галстук",equipSlot="tie",rarity="legendary",ru="Бордовый галстук",en="Burgundy tie",price=0,caseOnly=true,art="tie",color={137,46,64},dark={45,20,28},wearable={builder="tie",accent="burgundy"}},
    {id="agent_gloves",kind="cosmetic",category="Перчатки",equipSlot="gloves",rarity="common",ru="Перчатки агента",en="Agent gloves",price=0,caseOnly=true,art="gloves",color={180,183,188},dark={28,29,33},wearable={builder="gloves",accent="charcoal"}},
    {id="classic_glasses",kind="cosmetic",category="Очки",equipSlot="glasses",rarity="common",ru="Классические очки",en="Classic glasses",price=0,caseOnly=true,art="glasses",color={180,183,188},dark={29,31,35},wearable={builder="glasses",style="classic"}},
    {id="club_vest",kind="cosmetic",category="Костюм",equipSlot="outfit",rarity="uncommon",ru="Жилет клуба",en="Club vest",price=0,caseOnly=true,art="vest",color={91,190,121},dark={26,37,31},wearable={builder="outfit",shirtId=33209767,pantsId=12786204,style="vest"}},
    {id="dark_fedora",kind="cosmetic",category="Шляпа",equipSlot="hat",rarity="uncommon",ru="Тёмная федора",en="Dark fedora",price=0,caseOnly=true,art="fedora",color={91,190,121},dark={22,31,27},wearable={builder="fedora",band="forest"}},
    {id="noir_glasses",kind="cosmetic",category="Очки",equipSlot="glasses",rarity="rare",ru="Очки «Нуар»",en="Noir glasses",price=0,caseOnly=true,art="glasses",color={76,139,238},dark={22,28,42},wearable={builder="glasses",style="noir"}},
    {id="agent_fedora",kind="cosmetic",category="Шляпа",equipSlot="hat",rarity="rare",ru="Федора агента",en="Agent fedora",price=0,caseOnly=true,art="fedora",color={76,139,238},dark={21,27,39},wearable={builder="fedora",band="navy"}},
    {id="shoulder_holster",kind="cosmetic",category="Кобура",equipSlot="shoulder",rarity="rare",ru="Плечевая кобура",en="Shoulder holster",price=0,caseOnly=true,art="holster",color={76,139,238},dark={35,27,23},wearable={builder="holster",leather="umber"}},
    {id="velvet_tuxedo",kind="cosmetic",category="Костюм",equipSlot="outfit",rarity="epic",ru="Бархатный смокинг",en="Velvet tuxedo",price=0,caseOnly=true,art="tuxedo",color={169,91,232},dark={39,22,45},wearable={builder="outfit",shirtId=10268730314,pantsId=12786204,style="velvet"},effect={kind="aura",color={151,102,210},rate=1}},
    {id="midnight_tophat",kind="cosmetic",category="Шляпа",equipSlot="hat",rarity="epic",ru="Полуночный цилиндр",en="Midnight top hat",price=0,caseOnly=true,art="tophat",color={169,91,232},dark={27,22,39},wearable={builder="tophat",assetId=14289642462,band="violet"},effect={kind="aura",color={151,102,210},rate=1}},
    {id="director_suit",kind="cosmetic",category="Костюм",equipSlot="outfit",rarity="legendary",ru="Костюм директора",en="Director's suit",price=0,caseOnly=true,art="director",color={238,181,73},dark={48,37,20},wearable={builder="outfit",shirtId=33209767,pantsId=12786204,style="director"},effect={kind="embers",color={238,181,73},rate=2}},
    {id="crimson_fedora",kind="cosmetic",category="Шляпа",equipSlot="hat",rarity="mythic",ru="Багровая федора",en="Crimson fedora",price=0,caseOnly=true,art="fedora",color={224,55,78},dark={52,19,27},wearable={builder="fedora",band="crimson"},effect={kind="embers",color={224,55,78},rate=3}},
}
for _,item in ipairs(extra) do table.insert(Catalog.Items,item) end
for _, item in ipairs(Catalog.Items) do Catalog.ById[item.id] = item end
Catalog.Cases={
    midnight={id="midnight",nameKey="agentDossier",price=200,drops={
        {id="black_tie",weight=15},{id="agent_gloves",weight=15},{id="classic_glasses",weight=15},{id="club_vest",weight=14},{id="dark_fedora",weight=13},{id="noir_glasses",weight=5},{id="agent_fedora",weight=5},{id="shoulder_holster",weight=5},{id="velvet_tuxedo",weight=4},{id="midnight_tophat",weight=4},{id="director_suit",weight=4},{id="burgundy_tie",weight=1},
    }},
    velvet={id="velvet",nameKey="velvetCase",price=550,drops={
        {id="moon",weight=18},{id="seal",weight=18},{id="night_guest",weight=12},{id="violet",weight=18},{id="gilded_frame",weight=14},{id="mint_burst",weight=7},{id="tophat",weight=10},{id="gold",weight=3},
    }},
    blackvault={id="blackvault",nameKey="blackVault",price=1200,drops={
        {id="violet",weight=16},{id="gilded_frame",weight=15},{id="mint_burst",weight=14},{id="tophat",weight=13},{id="velvet_patron",weight=12},{id="gold",weight=10},{id="embers",weight=8},{id="obsidian_frame",weight=7},{id="crimson_fedora",weight=5},
    }},
}
Catalog.CaseOrder={"midnight","velvet","blackvault"}
Catalog.Sets={
    {id="midnight_records",nameKey="setRecords",items={"copper","mint","moon","seal"},reward="archivist"},
    {id="secret_society",nameKey="setSociety",items={"violet","gold"},reward="noir_frame"},
}
Catalog.Slots={"card","effect","trinket","outfit","accessory","emote","frame","title","gadget","hat","glasses","tie","gloves","shoulder"}
return Catalog
