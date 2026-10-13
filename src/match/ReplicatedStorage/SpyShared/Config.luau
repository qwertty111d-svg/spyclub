-- ReplicatedStorage > SpyShared > Config
-- Lobby больше НЕ содержит игровые столы.
-- Матчи теперь идут через SpyPartyServer -> отдельный Match Place.

return {
	Title = "КТО ШПИОН?",
	Subtitle = "НОЧНОЙ КЛУБ ДЕТЕКТИВОВ",

	-- Старая система Trio / Quartet / HighStakes отключена.
	Tables = {},

	Seconds = {
		Countdown = 6,
		Role = 7,
		Hint = 18,
		Discuss = 35,
		Vote = 20,
		Revote = 10,
		Result = 10,
	},

	HintLaps = 2,

	JoinDistance = 19,

	StudioNoChatSimulation = true,
}