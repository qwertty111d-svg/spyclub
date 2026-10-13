-- Curated fictional dossier identities. Nationality changes names, never abilities.
local Identity = {}
Identity.Nations = {
    {id="british",ru="Великобритания",en="United Kingdom",firstNames={"James","Oliver","Arthur","George","Henry","Edward","William","Thomas"},lastNames={"Bennett","Clarke","Foster","Hughes","Morgan","Reed","Turner","Walker"}},
    {id="french",ru="Франция",en="France",firstNames={"Luc","Antoine","Gabriel","Louis","Julien","Nicolas","Pierre","Victor"},lastNames={"Moreau","Laurent","Dubois","Lefevre","Martin","Bernard","Rousseau","Girard"}},
    {id="italian",ru="Италия",en="Italy",firstNames={"Luca","Marco","Matteo","Alessandro","Giovanni","Leonardo","Lorenzo","Riccardo"},lastNames={"Rossi","Conti","Ferrari","Romano","Ricci","Marino","Greco","Costa"}},
    {id="german",ru="Германия",en="Germany",firstNames={"Lukas","Felix","Jonas","Leon","Maximilian","Paul","Emil","Karl"},lastNames={"Weber","Schmidt","Fischer","Wagner","Becker","Hoffmann","Klein","Wolf"}},
    {id="spanish",ru="Испания",en="Spain",firstNames={"Alejandro","Diego","Javier","Mateo","Pablo","Rafael","Sergio","Adrian"},lastNames={"Garcia","Lopez","Fernandez","Sanchez","Romero","Torres","Moreno","Ruiz"}},
    {id="portuguese",ru="Португалия",en="Portugal",firstNames={"Tiago","Miguel","Diogo","Duarte","Francisco","Afonso","Rui","Pedro"},lastNames={"Silva","Santos","Pereira","Ferreira","Oliveira","Costa","Rodrigues","Almeida"}},
    {id="russian",ru="Россия",en="Russia",firstNames={"Алексей","Дмитрий","Андрей","Михаил","Никита","Илья","Сергей","Виктор"},lastNames={"Волков","Соколов","Орлов","Морозов","Белов","Лебедев","Новиков","Романов"}},
    {id="polish",ru="Польша",en="Poland",firstNames={"Jan","Jakub","Piotr","Pawel","Tomasz","Adam","Michal","Kacper"},lastNames={"Nowak","Kowalski","Wisniewski","Wojcik","Kaminski","Lewandowski","Zielinski","Szymanski"}},
    {id="japanese",ru="Япония",en="Japan",firstNames={"Haruto","Ren","Takumi","Akira","Hiroshi","Kaito","Sota","Yuki"},lastNames={"Sato","Suzuki","Takahashi","Tanaka","Watanabe","Ito","Yamamoto","Nakamura"}},
    {id="korean",ru="Южная Корея",en="South Korea",firstNames={"Min-jun","Ji-ho","Seo-jun","Do-yun","Hyun-woo","Joon-ho","Tae-hyun","Seung-min"},lastNames={"Kim","Lee","Park","Choi","Jung","Kang","Yoon","Han"}},
    {id="chinese",ru="Китай",en="China",firstNames={"Wei","Jun","Ming","Hao","Jian","Tao","Lei","Chen"},lastNames={"Wang","Li","Zhang","Liu","Chen","Yang","Huang","Zhao"}},
    {id="american",ru="США",en="United States",firstNames={"Ethan","Logan","Mason","Noah","Caleb","Miles","Owen","Nathan"},lastNames={"Miller","Johnson","Carter","Brooks","Parker","Hayes","Cooper","Reed"}},
}
Identity.ById = {}
for _, nation in ipairs(Identity.Nations) do
    nation.firstNameSet, nation.lastNameSet = {}, {}
    for _, value in ipairs(nation.firstNames) do nation.firstNameSet[value] = true end
    for _, value in ipairs(nation.lastNames) do nation.lastNameSet[value] = true end
    Identity.ById[nation.id] = nation
end

function Identity.default()
    local nation = Identity.Nations[1]
    return {nationality=nation.id,firstName=nation.firstNames[1],lastName=nation.lastNames[1]}
end
function Identity.validate(value)
    if type(value) ~= "table" then return false end
    local nation = Identity.ById[value.nationality]
    return nation ~= nil and nation.firstNameSet[value.firstName] == true and nation.lastNameSet[value.lastName] == true
end
function Identity.sanitize(value)
    value = type(value) == "table" and value or {}
    local nation = Identity.ById[value.nationality] or Identity.Nations[1]
    return {nationality=nation.id,
        firstName=nation.firstNameSet[value.firstName] and value.firstName or nation.firstNames[1],
        lastName=nation.lastNameSet[value.lastName] and value.lastName or nation.lastNames[1]}
end
function Identity.label(value,language)
    local id = type(value) == "table" and value.nationality or value
    local nation = Identity.ById[id]
    return nation and (language == "en" and nation.en or nation.ru) or "—"
end
function Identity.pool(category,current)
    local entries = {}
    if category == "nationality" then
        for _, nation in ipairs(Identity.Nations) do
            table.insert(entries,{item={id=nation.id,label=nation.en,labelRu=nation.ru,labelEn=nation.en},chance=100/#Identity.Nations})
        end
    elseif category == "firstName" or category == "lastName" then
        local nation = Identity.ById[Identity.sanitize(current).nationality]
        local names = category == "firstName" and nation.firstNames or nation.lastNames
        for _, name in ipairs(names) do
            table.insert(entries,{item={id=name,label=name,labelRu=name,labelEn=name},chance=100/#names})
        end
    end
    return entries,{}
end
return Identity
