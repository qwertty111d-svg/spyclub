-- SPY CLUB PREMIUM SHOP V1
-- ServerStorage > SpyModules > MonetizationConfig

local Config = {
	Passes = {
		{
			id = 1998632381,
			key = "black_tie_collection",
			category = "collection",
			ids = {
				"founder_suit",
				"closed_club_fedora",
				"interrogation_glasses",
				"founder_tie",
				"inner_circle_frame",
				"club_founder",
			},
			previewPrice = 399,
		},

		{
			id = 1998344385,
			key = "case_luck_2x",
			category = "boosts",
			entitlement = "case_luck_2x",
			paidRandom = true,
			previewPrice = 299,
		},
	},

	Products = {
		{
			id = 3714674590,
			key = "level_plus_one",
			category = "boosts",
			reward = {
				xp = 100,
			},
			previewPrice = 49,
		},

		{
			id = 3714674680,
			key = "coins_500",
			category = "coins",
			paidRandom = true,
			reward = {
				coins = 500,
			},
			previewPrice = 49,
		},

		{
			id = 3714674731,
			key = "coins_1600",
			category = "coins",
			paidRandom = true,
			reward = {
				coins = 1600,
			},
			previewPrice = 129,
		},

		{
			id = 3714674783,
			key = "coins_5000",
			category = "coins",
			paidRandom = true,
			reward = {
				coins = 5000,
			},
			previewPrice = 299,
		},

		{
			id = 3714115805,
			key = "supportPack",
			category = "support",
			ids = {},
		},
	},
}

function Config.validateReward(def)
	local reward = def.reward or {}

	return (reward.coins or 0) >= 0
		and (reward.coins or 0) <= 1000000
		and (reward.xp or 0) >= 0
		and (reward.xp or 0) <= 100000
end

return Config