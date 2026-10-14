-- SPY CLUB PREMIUM SHOP V1 :: Catalog
-- SPY_COSMETICS_V1: Catalog
-- Public cosmetic catalogue. One wallet is shared by earned and purchased coins.
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
{id="hair_blonde_bob",kind="cosmetic",category="Причёска",equipSlot="hair",rarity="uncommon",ru="Пучок с острыми прядями",en="Y2K Messy Bun",price=0,caseOnly=true,art="hair",color={91,190,121},dark={20,26,34},styleGroup="female",wearable={builder="hair",assetId=9425360862},sourceUrl="https://www.roblox.com/catalog/9425360862"},
{id="hair_johnny",kind="cosmetic",category="Причёска",equipSlot="hair",rarity="uncommon",ru="Городской зачёс",en="Johnny Brown Hair",price=0,caseOnly=true,art="hair",color={91,190,121},dark={20,26,34},styleGroup="male",wearable={builder="hair",assetId=62692030},sourceUrl="https://www.roblox.com/catalog/62692030"},
{id="noir_beret",kind="cosmetic",category="Головной убор",equipSlot="hat",rarity="rare",ru="Чёрный берет",en="Black Beret",price=0,caseOnly=true,art="hat",color={76,139,238},dark={20,26,34},wearable={builder="hat",assetId=6841567996},sourceUrl="https://www.roblox.com/catalog/6841567996"},
{id="pearl_necklace",kind="cosmetic",category="Украшение",equipSlot="tie",rarity="epic",ru="Жемчужное ожерелье",en="Elegant Pearl Necklace",price=0,caseOnly=true,art="tie",color={169,91,232},dark={20,26,34},wearable={builder="tie",assetId=14693013851},sourceUrl="https://www.roblox.com/catalog/14693013851"},
{id="club_shades",kind="cosmetic",category="Очки",equipSlot="glasses",rarity="legendary",ru="Архивные очки",en="Clockwork Shades",price=0,caseOnly=true,art="glasses",color={238,181,73},dark={20,26,34},wearable={builder="glasses",assetId=11748356},sourceUrl="https://www.roblox.com/catalog/11748356"},
{id="hair_short_part",kind="cosmetic",category="Причёска",equipSlot="hair",rarity="uncommon",ru="Чёрный пробор",en="Black Short Parted Hair",price=0,caseOnly=true,art="hair",color={91,190,121},dark={20,26,34},styleGroup="male",wearable={builder="hair",assetId=4875445470},sourceUrl="https://www.roblox.com/catalog/4875445470"},
{id="hair_slick_brown",kind="cosmetic",category="Причёска",equipSlot="hair",rarity="rare",ru="Боковой пробор",en="Black Messy Side Part",price=0,caseOnly=true,art="hair",color={76,139,238},dark={20,26,34},styleGroup="male",wearable={builder="hair",assetId=6310032618},sourceUrl="https://www.roblox.com/catalog/6310032618"},
{id="hair_messy_brown",kind="cosmetic",category="Причёска",equipSlot="hair",rarity="legendary",ru="Небрежная чёлка",en="Black Messy Anime Hair",price=0,caseOnly=true,art="hair",color={76,139,238},dark={20,26,34},styleGroup="unisex",wearable={builder="hair",assetId=5508722522},sourceUrl="https://www.roblox.com/catalog/5508722522"},
{id="hair_pigtails",kind="cosmetic",category="Причёска",equipSlot="hair",rarity="epic",ru="Собранные полуволны",en="Aesthetic Half Up Hair",price=0,caseOnly=true,art="hair",color={169,91,232},dark={20,26,34},styleGroup="female",wearable={builder="hair",assetId=6066635677},sourceUrl="https://www.roblox.com/catalog/6066635677"},
{id="hair_pearl_bun",kind="cosmetic",category="Причёска",equipSlot="hair",rarity="legendary",ru="Объёмный низкий пучок",en="Fluffy Low Bun",price=0,caseOnly=true,art="hair",color={238,181,73},dark={20,26,34},styleGroup="female",wearable={builder="hair",assetId=12578379669},sourceUrl="https://www.roblox.com/catalog/12578379669"},
{id="hair_vampire",kind="cosmetic",category="Причёска",equipSlot="hair",rarity="mythic",ru="Химэ",en="Aesthetic Hime Hair",price=0,caseOnly=true,art="hair",color={224,55,78},dark={20,26,34},styleGroup="female",wearable={builder="hair",assetId=11169888014},sourceUrl="https://www.roblox.com/catalog/11169888014"},
{id="hair_red_long",kind="cosmetic",category="Причёска",equipSlot="hair",rarity="common",ru="Медные локоны",en="Belle Of Belfast Long Red Hair",price=0,caseOnly=true,art="hair",color={174,178,184},dark={20,26,34},styleGroup="female",wearable={builder="hair",assetId=2956239660},sourceUrl="https://www.roblox.com/catalog/2956239660"},
{id="hair_blonde_long",kind="cosmetic",category="Причёска",equipSlot="hair",rarity="common",ru="Светлые прямые",en="Straight Blonde Hair",price=0,caseOnly=true,art="hair",color={174,178,184},dark={20,26,34},styleGroup="female",wearable={builder="hair",assetId=376526888},sourceUrl="https://www.roblox.com/catalog/376526888"},
{id="archive_fedora",kind="cosmetic",category="Шляпа",equipSlot="hat",rarity="legendary",ru="Архивная федора",en="The Classic ROBLOX Fedora",price=0,caseOnly=true,art="fedora",color={238,181,73},dark={20,26,34},wearable={builder="hat",assetId=1029025},sourceUrl="https://www.roblox.com/catalog/1029025"},
{id="midnight_shades",kind="cosmetic",category="Очки",equipSlot="glasses",rarity="epic",ru="Полночные очки",en="Midnight Shades",price=0,caseOnly=true,art="glasses",color={169,91,232},dark={20,26,34},wearable={builder="glasses",assetId=30331986},sourceUrl="https://www.roblox.com/catalog/30331986"},
{id="hair_charmer",styleGroup="male",kind="cosmetic",category="Причёска",equipSlot="hair",rarity="common",ru="Каштановый пробор",en="Brown Charmer Hair",price=0,caseOnly=true,art="hair",color={174,178,184},dark={20,26,34},wearable={builder="hair",assetId=376548738},sourceUrl="https://www.roblox.com/catalog/376548738"},
{id="hair_spikes",styleGroup="male",kind="cosmetic",category="Причёска",equipSlot="hair",rarity="rare",ru="Короткие кудри",en="Black Curly Popstar Hair",price=0,caseOnly=true,art="hair",color={174,178,184},dark={20,26,34},wearable={builder="hair",assetId=6140774351},sourceUrl="https://www.roblox.com/catalog/6140774351"},
{id="hair_swept",styleGroup="male",kind="cosmetic",category="Причёска",equipSlot="hair",rarity="uncommon",ru="Зачёс назад",en="Swept Back",price=0,caseOnly=true,art="hair",color={91,190,121},dark={20,26,34},wearable={builder="hair",assetId=5163640422}},
{id="hair_ponytail",styleGroup="female",kind="cosmetic",category="Причёска",equipSlot="hair",rarity="uncommon",ru="Пучок с боковыми прядями",en="Black Hair Bun",price=0,caseOnly=true,art="hair",color={91,190,121},dark={20,26,34},wearable={builder="hair",assetId=7331217038},sourceUrl="https://www.roblox.com/catalog/7331217038"},
{id="hair_noir",styleGroup="female",kind="cosmetic",category="Причёска",equipSlot="hair",rarity="common",ru="Каштановое каре",en="Chestnut Bob",price=0,caseOnly=true,art="hair",color={76,139,238},dark={20,26,34},wearable={builder="hair",assetId=77799917},sourceUrl="https://www.roblox.com/catalog/77799917"},
{id="hair_ash",styleGroup="female",kind="cosmetic",category="Причёска",equipSlot="hair",rarity="epic",ru="Низкий пучок",en="Low Bun",price=0,caseOnly=true,art="hair",color={169,91,232},dark={20,26,34},wearable={builder="hair",assetId=9513453851}},
{id="hair_amber",styleGroup="male",kind="cosmetic",category="Причёска",equipSlot="hair",rarity="rare",ru="Объёмный зачёс",en="Full Comb Over",price=0,caseOnly=true,art="hair",color={238,181,73},dark={20,26,34},wearable={builder="hair",assetId=12299883619}},
{id="hair_crimson",styleGroup="female",kind="cosmetic",category="Причёска",equipSlot="hair",rarity="mythic",ru="Ретро-волны",en="Vintage Waves",price=0,caseOnly=true,art="hair",color={224,55,78},dark={20,26,34},wearable={builder="hair",assetId=10476395186}},
	{id="tuxedo",kind="outfit",rarity="rare",ru="Смокинг «Полночь»",en="Midnight tuxedo",price=0,dailyOnly=true,art="file",color={230,211,168},dark={24,27,31},outfit="tuxedo"},
	{id="tophat",kind="accessory",rarity="epic",ru="Цилиндр джентльмена",en="Gentleman's top hat",price=240,art="seal",color={212,184,122},dark={29,31,34}},
	{id="wave",kind="emote",rarity="common",ru="Приветствие сыщика",en="Detective greeting",price=160,art="orbit",color={133,212,177},dark={25,44,39}},
	{id="gilded_frame",kind="frame",rarity="rare",ru="Золочёная рамка",en="Gilded frame",price=300,art="eye",color={237,195,112},dark={51,38,25}},
	{id="night_guest",kind="title",rarity="uncommon",ru="Ночной гость",en="Night guest",price=180,art="moon",color={178,192,239},dark={29,35,54},titleColor={183,169,231}},
	{id="notebook",kind="gadget",rarity="common",ru="Блокнот подсказок",en="Clue notebook",price=60,quantity=3,art="file",color={211,198,157},dark={43,39,28}},
	{id="history",kind="gadget",rarity="common",ru="Архив голосований",en="Ballot archive",price=60,quantity=3,art="cipher",color={161,203,194},dark={29,44,45}},
	{id="archivist",kind="title",rarity="rare",ru="Архивариус",en="Archivist",price=0,art="file",color={166,213,191},dark={29,45,42},setReward=true,titleColor={147,218,185}},
	{id="noir_frame",kind="frame",rarity="legendary",ru="Рамка «Нуар»",en="Noir frame",price=0,art="eye",color={202,175,239},dark={40,31,51},setReward=true},
	{id="supporter",kind="title",rarity="legendary",ru="Меценат клуба",en="Club patron",price=0,art="seal",color={244,211,150},dark={48,40,26},premium=true,titleColor={232,201,145}},
	-- Former nonwearable case prizes keep a deterministic route in the coin shop.
	{id="obsidian_frame",kind="frame",rarity="legendary",ru="Обсидиановая рамка",en="Obsidian frame",price=1980,legacyStore=true,art="eye",color={107,232,190},dark={12,22,22}},
	{id="velvet_patron",kind="title",rarity="epic",ru="Хозяин бархата",en="Velvet patron",price=900,legacyStore=true,art="seal",color={220,151,178},dark={50,24,36},titleColor={224,145,178}},
	{id="black_tie",kind="cosmetic",category="Галстук",equipSlot="tie",rarity="common",ru="Чёрный галстук",en="Black tie",price=0,caseOnly=true,art="tie",color={180,183,188},dark={24,25,29},wearable={builder="tie",accent="black"}},
	{id="burgundy_tie",kind="cosmetic",category="Галстук",equipSlot="tie",rarity="uncommon",ru="Бордовый галстук",en="Burgundy tie",price=0,caseOnly=true,art="tie",color={137,46,64},dark={45,20,28},wearable={builder="tie",accent="burgundy"}},
	{id="agent_gloves",kind="cosmetic",category="Перчатки",equipSlot="gloves",rarity="common",ru="Перчатки агента",en="Agent gloves",price=0,caseOnly=true,art="gloves",color={180,183,188},dark={28,29,33},wearable={builder="gloves",accent="charcoal"}},
	{id="classic_glasses",kind="cosmetic",category="Очки",equipSlot="glasses",rarity="common",ru="Классические очки",en="Classic glasses",price=0,caseOnly=true,art="glasses",color={180,183,188},dark={29,31,35},wearable={builder="glasses",style="classic"}},
	{id="club_vest",kind="cosmetic",category="Костюм",equipSlot="outfit",rarity="uncommon",ru="Жилет клуба",en="Club vest",price=0,caseOnly=true,art="vest",color={91,190,121},dark={26,37,31},wearable={builder="outfit",shirtId=129538902582804,pantsId=4666394268,style="vest",embeddedTie=false}},
	{id="dark_fedora",kind="cosmetic",category="Шляпа",equipSlot="hat",rarity="uncommon",ru="Тёмная федора",en="Dark fedora",price=0,caseOnly=true,art="fedora",color={91,190,121},dark={22,31,27},wearable={builder="fedora",band="forest"}},
	{id="noir_glasses",kind="cosmetic",category="Очки",equipSlot="glasses",rarity="rare",ru="Очки «Нуар»",en="Noir glasses",price=0,caseOnly=true,art="glasses",color={76,139,238},dark={22,28,42},wearable={builder="glasses",style="noir"}},
	{id="agent_fedora",kind="cosmetic",category="Шляпа",equipSlot="hat",rarity="rare",ru="Федора агента",en="Agent fedora",price=0,caseOnly=true,art="fedora",color={76,139,238},dark={21,27,39},wearable={builder="fedora",band="navy"}},
	{id="shoulder_holster",kind="cosmetic",category="Кобура",equipSlot="shoulder",rarity="rare",ru="Плечевая кобура",en="Shoulder holster",price=0,caseOnly=true,art="holster",color={76,139,238},dark={35,27,23},wearable={builder="holster",leather="umber"}},
	{id="velvet_tuxedo",kind="cosmetic",category="Костюм",equipSlot="outfit",rarity="epic",ru="Бархатный смокинг",en="Velvet tuxedo",price=0,caseOnly=true,art="tuxedo",color={169,91,232},dark={39,22,45},wearable={builder="outfit",shirtId=12386048507,pantsId=4666394268,style="velvet",embeddedTie=false},effect={kind="aura",color={151,102,210},rate=1}},
	{id="midnight_tophat",kind="cosmetic",category="Шляпа",equipSlot="hat",rarity="epic",ru="Полуночный цилиндр",en="Midnight top hat",price=0,caseOnly=true,art="tophat",color={169,91,232},dark={27,22,39},wearable={builder="tophat",band="violet"},effect={kind="aura",color={151,102,210},rate=1}},
	{id="director_suit",kind="cosmetic",category="Костюм",equipSlot="outfit",rarity="legendary",ru="Костюм директора",en="Director's suit",price=0,caseOnly=true,art="director",color={238,181,73},dark={48,37,20},wearable={builder="outfit",shirtId=12779575121,pantsId=33210031,style="director",embeddedTie=false},effect={kind="embers",color={238,181,73},rate=2}},
	{id="crimson_fedora",kind="cosmetic",category="Шляпа",equipSlot="hat",rarity="mythic",ru="Багровая федора",en="Crimson fedora",price=0,caseOnly=true,art="fedora",color={224,55,78},dark={52,19,27},wearable={builder="hat",assetId=72082328,nativeAttachment=true},sourceUrl="https://www.roblox.com/catalog/72082328",effect={kind="embers",color={224,55,78},rate=3}},
	{id="founder_suit",kind="cosmetic",category="Костюм",equipSlot="outfit",rarity="legendary",premium=true,ru="Костюм «Чёрный протокол»",en="Black Protocol Suit",art="director",color={221,177,105},dark={30,24,21},wearable={builder="outfit",shirtId=199168526,pantsId=33210031,style="founder",embeddedTie=false},effect={kind="golden_signature",color={221,177,105},rate=2}},
	{id="closed_club_fedora",kind="cosmetic",category="Шляпа",equipSlot="hat",rarity="legendary",premium=true,ru="Федора закрытого клуба",en="Closed Club Fedora",art="fedora",color={221,177,105},dark={30,24,21},wearable={builder="fedora",band="champagne"}},
	{id="interrogation_glasses",kind="cosmetic",category="Очки",equipSlot="glasses",rarity="legendary",premium=true,ru="Очки «Допрос»",en="Interrogation Glasses",art="glasses",color={221,177,105},dark={30,24,21},wearable={builder="glasses",style="interrogation"}},
	{id="founder_tie",kind="cosmetic",category="Галстук",equipSlot="tie",rarity="legendary",premium=true,ru="Галстук основателя",en="Founder Tie",art="tie",color={221,177,105},dark={30,24,21},wearable={builder="tie",accent="founder"}},
	{id="inner_circle_frame",kind="frame",rarity="legendary",premium=true,ru="Рамка «Внутренний круг»",en="Inner Circle Frame",art="eye",color={221,177,105},dark={30,24,21}},
	{id="club_founder",kind="title",rarity="legendary",premium=true,ru="Учредитель клуба",en="Club Founder",art="seal",color={204,154,83},dark={30,24,21},titleColor={204,154,83}},
{["id"]="club_monocle",["kind"]="cosmetic",["category"]="Монокль",["equipSlot"]="glasses",["rarity"]="rare",["ru"]="Монокль архивариуса",["en"]="Archivist monocle",["price"]=0,["caseOnly"]=true,["art"]="glasses",["color"]={76,139,238},["dark"]={20,26,34},["collectionRu"]="Архив клуба",["collectionEn"]="Club Archive",["wearable"]={["builder"]="glasses",["assetId"]=30390853,["nativeAttachment"]=true},["sourceUrl"]="https://www.roblox.com/catalog/30390853"},
{["id"]="opera_mask",["kind"]="cosmetic",["category"]="Маска",["equipSlot"]="glasses",["rarity"]="epic",["ru"]="Маска «Призрак оперы»",["en"]="Phantom of the Opera mask",["price"]=0,["caseOnly"]=true,["art"]="glasses",["color"]={169,91,232},["dark"]={20,26,34},["collectionRu"]="Маскарад",["collectionEn"]="Masquerade",["wearable"]={["builder"]="glasses",["assetId"]=14129625,["nativeAttachment"]=true},["sourceUrl"]="https://www.roblox.com/catalog/14129625"},
{["id"]="black_pearl_mask",["kind"]="cosmetic",["category"]="Маска",["equipSlot"]="glasses",["rarity"]="epic",["ru"]="Маска «Чёрный жемчуг»",["en"]="Black Pearl mask",["price"]=0,["caseOnly"]=true,["art"]="glasses",["color"]={169,91,232},["dark"]={20,26,34},["collectionRu"]="Маскарад",["collectionEn"]="Masquerade",["wearable"]={["builder"]="glasses",["assetId"]=10327844086,["nativeAttachment"]=true},["sourceUrl"]="https://www.roblox.com/catalog/10327844086"},
{["id"]="clockwork_headphones",["kind"]="cosmetic",["category"]="Наушники",["equipSlot"]="hat",["rarity"]="legendary",["ru"]="Наушники Clockwork",["en"]="Clockwork headphones",["price"]=0,["caseOnly"]=true,["art"]="hat",["color"]={238,181,73},["dark"]={20,26,34},["collectionRu"]="Виниловый салон",["collectionEn"]="Vinyl Lounge",["wearable"]={["builder"]="hat",["assetId"]=1235488,["nativeAttachment"]=true},["sourceUrl"]="https://www.roblox.com/catalog/1235488"},
{["id"]="gold_clockwork_headphones",["kind"]="cosmetic",["category"]="Наушники",["equipSlot"]="hat",["rarity"]="legendary",["ru"]="Золотые наушники Clockwork",["en"]="Gold Clockwork headphones",["price"]=0,["caseOnly"]=true,["art"]="hat",["color"]={238,181,73},["dark"]={20,26,34},["collectionRu"]="Виниловый салон",["collectionEn"]="Vinyl Lounge",["wearable"]={["builder"]="hat",["assetId"]=16477149823,["nativeAttachment"]=true},["sourceUrl"]="https://www.roblox.com/catalog/16477149823"},
{["id"]="black_sparkle_fedora",["kind"]="cosmetic",["category"]="Шляпа",["equipSlot"]="hat",["rarity"]="mythic",["ru"]="Федора «Чёрная искра»",["en"]="Black Sparkle Fedora",["price"]=0,["caseOnly"]=true,["art"]="fedora",["color"]={224,55,78},["dark"]={20,26,34},["collectionRu"]="Закрытый архив",["collectionEn"]="Private Archive",["wearable"]={["builder"]="hat",["assetId"]=259423244,["nativeAttachment"]=true},["sourceUrl"]="https://www.roblox.com/catalog/259423244"},
{["id"]="nocturne_dominus",["kind"]="cosmetic",["category"]="Капюшон",["equipSlot"]="hat",["rarity"]="mythic",["ru"]="Капюшон «Ночной архив»",["en"]="Nocturne Dominus",["price"]=0,["caseOnly"]=true,["art"]="hat",["color"]={224,55,78},["dark"]={20,26,34},["collectionRu"]="Маскарад",["collectionEn"]="Masquerade",["wearable"]={["builder"]="hat",["assetId"]=96103379,["nativeAttachment"]=true},["sourceUrl"]="https://www.roblox.com/catalog/96103379"},
}
for _,item in ipairs(extra) do
	table.insert(Catalog.Items,item)
end
local clubCollection=require(script and script.Parent.ClubStoreConfig or "ClubStoreConfig")
for _,group in ipairs({clubCollection.Items,clubCollection.DailyItems})do
 for _,definition in ipairs(group)do
  local item=table.clone(definition)
  item.noSell=true;item.coinOnly=true
  item.dailyOnly=group==clubCollection.DailyItems
  item.collectionRu="Клубная коллекция";item.collectionEn="Club collection"
  table.insert(Catalog.Items,item)
 end
end
-- Curatorial series are visual metadata, never a new currency or ownership namespace.
local SERIES={common={ru="Основы",en="Essentials"},uncommon={ru="Город",en="City"},rare={ru="Ателье",en="Atelier"},
 epic={ru="Вечер",en="Evening"},legendary={ru="Подпись",en="Signature"},mythic={ru="Закрытый архив",en="Private Archive"}}
for _,item in ipairs(Catalog.Items) do
 if item.equipSlot=="hair" then
  local rarity=Catalog.Rarities[item.rarity];if rarity then item.color=rarity.color end
  local series=SERIES[item.rarity];item.collectionRu=series.ru;item.collectionEn=series.en
 end
end
local UTILITY_BY_SLOT={
	card={ru="Досье на поясе и карта на игровом столе",en="Dossier on your belt and card at the table"},
	effect={ru="Персонаж и финал матча",en="Character aura and match result"},
	trinket={ru="На поясе и рядом с картой на игровом столе",en="On your belt and beside your card at the table"},
	outfit={ru="Костюм персонажа",en="Character outfit"},
	accessory={ru="Аксессуар персонажа",en="Character accessory"},
	emote={ru="Эмоция персонажа",en="Character emote"},
	frame={ru="Досье, табличка над головой и состав клуба",en="Dossier, overhead tag and club roster"},
	title={ru="Табличка над головой и состав клуба",en="Overhead tag and club roster"},
	hair={ru="Причёска персонажа; носится вместе со шляпой",en="Character hairstyle; can be worn with hats"},
	hat={ru="Головной убор персонажа",en="Character headwear"},
	glasses={ru="Очки или маска персонажа",en="Character glasses or mask"},
	tie={ru="Галстук персонажа",en="Character tie"},
	gloves={ru="Перчатки персонажа",en="Character gloves"},
	shoulder={ru="Плечевой аксессуар персонажа",en="Character shoulder accessory"},
	gadget={ru="Расходуемый инструмент матча",en="Consumable match tool"},
}
for _, item in ipairs(Catalog.Items) do
	Catalog.ById[item.id] = item
	local utility=UTILITY_BY_SLOT[item.equipSlot or item.kind]
	if utility then item.useRu,item.useEn=utility.ru,utility.en end
end
Catalog.Cases={
 atelier={id="atelier",nameKey="atelierCase",price=150,rollMax=200,rarityTargets={common=45,uncommon=32,rare=10,epic=8,legendary=4,mythic=1},duplicateRefundByRarity={common=30,uncommon=45,rare=75,epic=125,legendary=290,mythic=625},drops={
  {id="hair_charmer",weight=14},{id="hair_noir",weight=7},{id="hair_red_long",weight=12},{id="hair_blonde_long",weight=12},
  {id="hair_swept",weight=8},{id="hair_ponytail",weight=8},{id="hair_short_part",weight=8},{id="hair_blonde_bob",weight=4},{id="hair_johnny",weight=4},
  {id="hair_spikes",weight=4},{id="hair_slick_brown",weight=4},{id="hair_amber",weight=2},
  {id="hair_ash",weight=4},{id="hair_pigtails",weight=4},{id="hair_messy_brown",weight=2},{id="hair_pearl_bun",weight=2},{id="hair_crimson",weight=.5},{id="hair_vampire",weight=.5}}},
	midnight={id="midnight",nameKey="agentDossier",price=200,rarityTargets={common=40,uncommon=32,rare=20,epic=8},duplicateRefundByRarity={common=60,uncommon=90,rare=130,epic=250,legendary=600,mythic=1500},drops={
  {id="black_tie",weight=10},{id="agent_gloves",weight=15},{id="classic_glasses",weight=15},{id="club_vest",weight=14},{id="dark_fedora",weight=13},{id="noir_glasses",weight=4},{id="agent_fedora",weight=4},{id="shoulder_holster",weight=4},{id="noir_beret",weight=3},{id="velvet_tuxedo",weight=4},{id="midnight_tophat",weight=4},{id="gilded_frame",weight=2},{id="burgundy_tie",weight=5},{id="club_monocle",weight=3},
	}},
	velvet={id="velvet",nameKey="velvetCase",price=550,rarityTargets={uncommon=24,rare=36,epic=27,legendary=13},duplicateRefundByRarity={uncommon=180,rare=240,epic=330,legendary=650,mythic=1500},drops={
  {id="moon",weight=12},{id="seal",weight=12},{id="noir_glasses",weight=10},{id="agent_fedora",weight=10},{id="shoulder_holster",weight=8},{id="gilded_frame",weight=4},{id="club_monocle",weight=4},{id="velvet_tuxedo",weight=7},{id="midnight_tophat",weight=6},{id="velvet_patron",weight=4},{id="pearl_necklace",weight=3},{id="midnight_shades",weight=3},{id="opera_mask",weight=2},{id="black_pearl_mask",weight=2},{id="director_suit",weight=5},{id="obsidian_frame",weight=5},{id="clockwork_headphones",weight=3},
	}},
 blackvault={id="blackvault",nameKey="blackVault",price=1200,rarityTargets={rare=25,epic=32,legendary=35,mythic=8},duplicateRefundByRarity={rare=480,epic=560,legendary=750,mythic=1600},drops={
  {id="noir_glasses",weight=5},{id="shoulder_holster",weight=3},{id="gilded_frame",weight=3},{id="noir_beret",weight=5},{id="agent_fedora",weight=5},{id="club_monocle",weight=4},{id="velvet_tuxedo",weight=5},{id="midnight_tophat",weight=5},{id="velvet_patron",weight=3},{id="midnight_shades",weight=4},{id="pearl_necklace",weight=6},{id="opera_mask",weight=4},{id="black_pearl_mask",weight=5},{id="director_suit",weight=4},{id="gold",weight=3},{id="embers",weight=2},{id="obsidian_frame",weight=5},{id="archive_fedora",weight=6},{id="club_shades",weight=6},{id="clockwork_headphones",weight=4},{id="gold_clockwork_headphones",weight=5},{id="crimson_fedora",weight=3},{id="black_sparkle_fedora",weight=3},{id="nocturne_dominus",weight=2},
 }},
}
Catalog.CaseOrder={"atelier","midnight","velvet","blackvault"}
Catalog.Sets={
	{id="midnight_records",nameKey="setRecords",items={"copper","mint","moon","seal"},reward="archivist"},
	{id="secret_society",nameKey="setSociety",items={"violet","gold"},reward="noir_frame"},
}
Catalog.Slots={"card","effect","trinket","outfit","accessory","emote","frame","title","gadget","hat","glasses","tie","gloves","shoulder","hair"}

function Catalog.resolveCaseRoll(caseId,roll)
	local case=Catalog.Cases and Catalog.Cases[caseId]
	if not case or type(roll)~="number" or roll%1~=0 or roll<1 or roll>(case.rollMax or 100) then return nil end
	local ticket=roll/((case.rollMax or 100)/100)
	local total=0
	for _,drop in ipairs(case.drops) do
		total+=drop.weight
		if ticket<=total then 
return Catalog.ById[drop.id],drop end
	end
	return nil
end

function Catalog.resolveLuckyRoll(caseId,rollA,rollB)
	local first=Catalog.resolveCaseRoll(caseId,rollA)
	local second=Catalog.resolveCaseRoll(caseId,rollB)
	if not first or not second then return first or second end
	local firstRank=(Catalog.Rarities[first.rarity] or {}).rank or 0
	local secondRank=(Catalog.Rarities[second.rarity] or {}).rank or 0
	return secondRank>firstRank and second or first
end

function Catalog.caseOdds(caseId,lucky)
	local case=Catalog.Cases and Catalog.Cases[caseId]
	if not case then return {} end
	local counts,total={},0
	if lucky then
		for rollA=1,(case.rollMax or 100) do
			for rollB=1,(case.rollMax or 100) do
				local item=Catalog.resolveLuckyRoll(caseId,rollA,rollB)
				if item then counts[item.id]=(counts[item.id] or 0)+1 total+=1 end
			end
		end
	else
		for roll=1,(case.rollMax or 100) do
			local item=Catalog.resolveCaseRoll(caseId,roll)
			if item then counts[item.id]=(counts[item.id] or 0)+1 total+=1 end
		end
	end
	local result={}
	for order,drop in ipairs(case.drops) do
		local item=Catalog.ById[drop.id]
		result[#result+1]={id=drop.id,chance=total>0 and ((counts[drop.id] or 0)/total*100) or 0,order=order,rarity=item and item.rarity or "common"}
	end
	return result
end


-- V44 :: server-authoritative resale valuation. Purchase price and resale value are intentionally separate.
Catalog.ResaleRate = 0.30
Catalog.ResaleFallbackValues = {
	common=180, uncommon=315, rare=540, epic=900, legendary=1980, mythic=4500,
}

-- Atelier is an entry case; its resale valuation uses that cheaper tier.
Catalog.HairResaleValues = {common=85,uncommon=150,rare=257,epic=428,legendary=942,mythic=2142}

function Catalog.valueFor(item)
	if type(item) ~= "table" then return 0 end
	local explicit = tonumber(item.value)
	if explicit and explicit > 0 then return math.floor(explicit) end
	local price = tonumber(item.price)
	if price and price > 0 then return math.floor(price) end
	if item.caseOnly == true then
		local values=item.equipSlot=="hair" and Catalog.HairResaleValues or Catalog.ResaleFallbackValues
		return math.floor(values[item.rarity] or 0)
	end
	return 0
end

function Catalog.sellInfo(itemId)
	local item = type(itemId) == "table" and itemId or Catalog.ById[itemId]
	if not item then return {sellable=false, code="invalid_item", value=0, offer=0} end
	if item.id == "classic" or item.id == "soft" then
		return {sellable=false, code="protected_item", value=0, offer=0, item=item}
	end
	if item.kind == "gadget" or item.premium == true or item.dailyOnly == true or item.setReward == true
		or item.achievementOnly == true or item.uniqueReward == true or item.noSell == true then
		return {sellable=false, code="protected_item", value=0, offer=0, item=item}
	end
	local value = Catalog.valueFor(item)
	if value <= 0 then return {sellable=false, code="no_value", value=0, offer=0, item=item} end
	return {sellable=true, code="sellable", value=value, offer=math.max(1, math.floor(value * Catalog.ResaleRate)), item=item}
end

-- Explicit server-authored allowlist. New shop/case entries default to locked.
local tradeIds={
 club_monocle=true,opera_mask=true,black_pearl_mask=true,clockwork_headphones=true,gold_clockwork_headphones=true,black_sparkle_fedora=true,nocturne_dominus=true,
 hair_blonde_bob=true,
 hair_johnny=true,
 noir_beret=true,
 pearl_necklace=true,
 club_shades=true,
 hair_short_part=true,
 hair_slick_brown=true,
 hair_messy_brown=true,
 hair_pigtails=true,
 hair_pearl_bun=true,
 hair_vampire=true,
 hair_red_long=true,
 hair_blonde_long=true,
 archive_fedora=true,
 midnight_shades=true,

 agent_fedora=true,
 agent_gloves=true,
 black_tie=true,
 burgundy_tie=true,
 classic_glasses=true,
 club_vest=true,
 copper=true,
 crimson_fedora=true,
 dark_fedora=true,
 dice=true,
 director_suit=true,
 embers=true,
 gilded_frame=true,
 gold=true,
 hair_amber=true,
 hair_ash=true,
 hair_charmer=true,
 hair_crimson=true,
 hair_noir=true,
 hair_ponytail=true,
 hair_spikes=true,
 hair_swept=true,
 lens=true,
 midnight_tophat=true,
 mint=true,
 mint_burst=true,
 moon=true,
 night_guest=true,
 noir_glasses=true,
 obsidian_frame=true,
 seal=true,
 shoulder_holster=true,
 tophat=true,
 velvet_patron=true,
 velvet_tuxedo=true,
 violet=true,
 watch=true,
 wave=true,
}
for _,item in ipairs(Catalog.Items) do
 item.tradeable=tradeIds[item.id]==true and Catalog.sellInfo(item.id).sellable==true
end
function Catalog.tradeInfo(id)
 local item=type(id)=="string" and Catalog.ById[id]
 return {tradeable=item~=nil and item.tradeable==true,code=item and item.tradeable and "ok" or "protected_item"}
end


-- Shared discovery rules. Gender labels describe styles, never account restrictions.
local APPEARANCE={hair=true,hat=true,outfit=true,accessory=true,glasses=true,tie=true,gloves=true,shoulder=true}
function Catalog.itemGroup(item)
 return APPEARANCE[item.equipSlot or item.kind] and "appearance" or "loadout"
end
function Catalog.fold(value)
 local codes={}
 for _,code in utf8.codes(string.lower(tostring(value or ""))) do
  if code>=1040 and code<=1071 then code+=32 elseif code==1025 then code=1105 end
  codes[#codes+1]=utf8.char(code)
 end
 return table.concat(codes)
end
function Catalog.matches(item,query,group,slot,style,tier)
 if not item then return false end
 if group and group~="all" and group~="collection" and Catalog.itemGroup(item)~=group then return false end
 if slot and slot~="all" and (item.equipSlot or item.kind)~=slot then return false end
 if style and style~="all" and item.styleGroup~=style then return false end
 if tier and tier~="all" and item.rarity~=tier then return false end
 local wanted=Catalog.fold(query)
 return wanted=="" or Catalog.fold((item.ru or "").." "..(item.en or "").." "..item.id):find(wanted,1,true)~=nil
end
function Catalog.itemSources(id,lucky)
 local sources={}
 for _,caseId in ipairs(Catalog.CaseOrder) do
  for _,odds in ipairs(Catalog.caseOdds(caseId,lucky)) do
   if odds.id==id then sources[#sources+1]={caseId=caseId,chance=odds.chance or odds.percent or odds.probability} end
  end
 end
 return sources
end

-- Collection browsing and tier summaries share the same definitions as server rewards.
function Catalog.inventoryItems(profile,options)
 profile=type(profile)=="table"and profile or {};options=options or {}
 local result={};local owned=profile.owned or {};local counts=profile.itemCounts or {}
 for _,item in ipairs(Catalog.Items)do
  if (options.group=="collection"or owned[item.id]==true)
   and (not options.duplicates or (counts[item.id]or(owned[item.id]and 1 or 0))>1)
   and Catalog.matches(item,options.query,options.group,options.slot,options.style,options.tier)then
   result[#result+1]=item
  end
 end
 local sort=options.sort or "rarity"
 table.sort(result,function(a,b)
  if sort=="value"then
   local av,bv=Catalog.valueFor(a),Catalog.valueFor(b);if av~=bv then return av>bv end
  elseif sort~="name"then
   local ar,br=Catalog.Rarities[a.rarity].rank,Catalog.Rarities[b.rarity].rank;if ar~=br then return ar>br end
  end
  local an,bn=Catalog.fold(options.language=="en"and a.en or a.ru),Catalog.fold(options.language=="en"and b.en or b.ru)
  return an==bn and a.id<b.id or an<bn
 end)
 return result
end
function Catalog.caseTiers(caseId,lucky)
 local tiers,byRarity={},{}
 for _,entry in ipairs(Catalog.caseOdds(caseId,lucky))do
  local item=Catalog.ById[entry.id];local key=item.rarity
  local tier=byRarity[key]
  if not tier then tier={rarity=key,chance=0,items={}};byRarity[key]=tier;tiers[#tiers+1]=tier end
  tier.chance+=entry.chance;tier.items[#tier.items+1]={id=entry.id,chance=entry.chance,value=Catalog.valueFor(item)}
 end
 table.sort(tiers,function(a,b)return Catalog.Rarities[a.rarity].rank>Catalog.Rarities[b.rarity].rank end)
 return tiers
end
Catalog.DuplicatePolicy="copies"
Catalog.DuplicateRefund=0
for key in pairs(Catalog.DuplicateRefundByRarity)do Catalog.DuplicateRefundByRarity[key]=0 end
for _,case in pairs(Catalog.Cases)do for key in pairs(case.duplicateRefundByRarity or{})do case.duplicateRefundByRarity[key]=0 end end
return Catalog
