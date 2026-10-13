-- One saved wallet; test balancing is intentionally independent of old case odds.
local Config = {
    Version = 1,
    MaxRolls = 1000000000,
    ReceiptLimit = 512,
    Cooldown = .65,
    PreparationTimeout = 2,
    Rewards = {starter=5, completeMatch=1, win=1, daily=2},
    RarityOrder = {"common","uncommon","rare","epic","legendary","mythic"},
    Weights = {common=48,uncommon=30,rare=14,epic=6,legendary=1.7,mythic=.3},
    Categories = {
        {id="nationality",slot="nationality",identity=true,ru="Национальность",en="Nationality"},
        {id="firstName",slot="firstName",identity=true,ru="Имя",en="First name"},
        {id="lastName",slot="lastName",identity=true,ru="Фамилия",en="Surname"},
        {id="hair",slot="hair",ru="Причёски",en="Hair"},
        {id="hat",slot="hat",ru="Шляпы",en="Hats"},
        {id="glasses",slot="glasses",ru="Очки / маски",en="Glasses"},
        {id="tie",slot="tie",ru="Шея",en="Neck"},
        {id="gloves",slot="gloves",ru="Перчатки",en="Gloves"},
        {id="shoulder",slot="shoulder",ru="Плечо",en="Shoulder"},
        {id="outfit",slot="outfit",ru="Костюмы",en="Outfit"},
        {id="accessory",slot="accessory",ru="Аксессуары",en="Accessory"},
    },
    -- Add server event/promocode definitions here. They are never client grants.
    Events = {},
    PromoCodes = {},
}
Config.ById = {}
for _,category in ipairs(Config.Categories) do
    Config.ById[category.id] = category
    -- Optional category.weights and category.styleGroup override the defaults.
end
return Config
