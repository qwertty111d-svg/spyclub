-- SPY CLUB PREMIUM SHOP V1 :: Monetization
-- ServerStorage > SpyModules > Monetization
-- FULL REPLACEMENT
--
-- Fixes:
-- 1) Developer Product receipts grant rewards in Studio test purchases.
-- 2) Studio Game Pass purchases are simulated for the current server session.
-- 3) Production purchases remain receipt-driven and idempotent.

local Marketplace = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Config = require(script.Parent.MonetizationConfig)

local Monetization = {}

function Monetization.new(profiles, onChange)
	local self = {
		passes = {},
		products = {},
		definitions = {},
		policy = {},
		entitlements = {},
		studioPasses = {},
	}

	for _, def in ipairs(Config.Passes) do
		self.definitions[#self.definitions + 1] = {
			id = def.id,
			key = def.key,
			kind = "pass",
			category = def.category,
			ids = def.ids,
			entitlement = def.entitlement,
			paidRandom = def.paidRandom,
			previewPrice = def.previewPrice,
		}

		if type(def.id) == "number" and def.id > 0 then
			self.passes[def.id] = def
		end
	end

	for _, def in ipairs(Config.Products) do
		self.definitions[#self.definitions + 1] = {
			id = def.id,
			key = def.key,
			kind = "product",
			category = def.category,
			ids = def.ids,
			reward = def.reward,
			paidRandom = def.paidRandom,
			previewPrice = def.previewPrice,
		}

		if type(def.id) == "number" and def.id > 0 then
			self.products[def.id] = def
		end
	end

	local function policyFor(player)
		-- Studio is a development sandbox. Paid-random restrictions are
		-- enforced in published servers, but they must not block local testing
		-- of the shop/reward pipeline.
		if RunService:IsStudio() then
			self.policy[player.UserId] = false
			player:SetAttribute("SpyPaidRandomRestricted", false)
			return false
		end

		local cached = self.policy[player.UserId]
		if cached ~= nil then
			return cached
		end

		local restricted = true
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)

		if ok and type(info) == "table" then
			restricted = info.ArePaidRandomItemsRestricted == true
		end

		self.policy[player.UserId] = restricted
		player:SetAttribute("SpyPaidRandomRestricted", restricted)
		return restricted
	end

	function self.offersFor(first, second)
		local player = second or first
		local restricted = policyFor(player)
		local offers = {}

		for _, def in ipairs(self.definitions) do
			local validId = def.id > 0 or RunService:IsStudio()
			local blockedByPolicy = restricted and def.paidRandom

			if validId and not blockedByPolicy then
				offers[#offers + 1] = def
			end
		end

		return offers
	end

	function self:hasEntitlement(player, key)
		if key == "case_luck_2x" and policyFor(player) then
			return false
		end

		return self.entitlements[player.UserId]
			and self.entitlements[player.UserId][key] == true
	end

	function self:isPaidRandomRestricted(player)
		return policyFor(player)
	end

	local function ownsPassInStudio(player, passId)
		local userPasses = self.studioPasses[player.UserId]
		return userPasses and userPasses[passId] == true
	end

	local function setStudioPassOwned(player, passId)
		local userPasses = self.studioPasses[player.UserId]
		if not userPasses then
			userPasses = {}
			self.studioPasses[player.UserId] = userPasses
		end

		userPasses[passId] = true
	end

	function self:sync(player)
		local restricted = policyFor(player)
		local owned = self.entitlements[player.UserId] or {}
		self.entitlements[player.UserId] = owned

		for _, def in ipairs(Config.Passes) do
			local owns = false

			if def.id > 0 then
				if RunService:IsStudio() then
					owns = ownsPassInStudio(player, def.id)
				else
					local ok, result = pcall(
						Marketplace.UserOwnsGamePassAsync,
						Marketplace,
						player.UserId,
						def.id
					)
					owns = ok and result == true
				end
			end

			local key = def.entitlement or def.key
			owned[key] = owns and not (key == "case_luck_2x" and restricted)

			if owns and def.ids and #def.ids > 0 then
				local receipt = profiles:transact(
					player.UserId,
					"pass:" .. tostring(def.id),
					{
						kind = "grantCosmetics",
						ids = def.ids,
					}
				)

				if receipt.ok then
					onChange(player, receipt)
				end
			end
		end

		player:SetAttribute("SpyCaseLuck2x", owned.case_luck_2x == true)
		onChange(player, {
			ok = true,
			code = "monetizationSynced",
		})
	end

	Marketplace.PromptGamePassPurchaseFinished:Connect(function(player, id, purchased)
		local def = self.passes[id]
		if not purchased or not def then
			return
		end

		if RunService:IsStudio() then
			setStudioPassOwned(player, id)
		end

		-- BLACK TIE is equipped once, immediately when the pass is purchased.
		-- Normal syncs on future joins only restore ownership and never override
		-- whatever outfit the player chose later.
		if def.key == "black_tie_collection" and def.ids and #def.ids > 0 then
			local operationId
			if RunService:IsStudio() then
				operationId = "studioPassPurchase:" .. tostring(id) .. ":" .. HttpService:GenerateGUID(false)
			else
				operationId = "passPurchase:" .. tostring(id)
			end

			local ok, receipt = pcall(function()
				return profiles:transact(
					player.UserId,
					operationId,
					{
						kind = "grantCosmetics",
						ids = def.ids,
						autoEquip = true,
					}
				)
			end)

			if ok and receipt and receipt.ok then
				onChange(player, receipt)
			elseif not ok then
				warn("SpyClub: Black Tie purchase grant failed", receipt)
			end
		end

		task.spawn(function()
			self:sync(player)
		end)
	end)

	Marketplace.ProcessReceipt = function(info)
		local def = self.products[info.ProductId]
		local player = Players:GetPlayerByUserId(info.PlayerId)

		if not def or not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local publicProfile = profiles:public(info.PlayerId)
		if not publicProfile or publicProfile.ready ~= true then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		if not Config.validateReward(def) then
			warn("SpyClub: invalid monetization reward for product", info.ProductId)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		if def.paidRandom and policyFor(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local reward = def.reward or {}

		-- Real receipts must use Roblox PurchaseId so retries are idempotent.
		-- Studio sometimes supplies a weak/empty receipt identity, so give the
		-- simulated purchase its own session GUID when necessary.
		local purchaseId
		if RunService:IsStudio() then
			-- Every simulated Studio purchase is a fresh test purchase.
			purchaseId = "studio:" .. HttpService:GenerateGUID(false)
		else
			purchaseId = info.PurchaseId and tostring(info.PurchaseId) or ""
			if purchaseId == "" or purchaseId == "nil" then
				warn("SpyClub: live receipt has no PurchaseId", info.ProductId, info.PlayerId)
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
		end

		local operationId = "purchase:" .. purchaseId
		local ok, receipt = pcall(function()
			return profiles:transact(
				info.PlayerId,
				operationId,
				{
					kind = "paidGrant",
					coins = reward.coins,
					xp = reward.xp,
					ids = def.ids,
					robux = info.CurrencySpent,
					purchaseId = purchaseId,
				}
			)
		end)

		if ok and receipt and receipt.ok then
			onChange(player, receipt)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		if not ok then
			warn("SpyClub: ProcessReceipt transaction failed", info.ProductId, receipt)
		end

		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	Players.PlayerRemoving:Connect(function(player)
		self.policy[player.UserId] = nil
		self.entitlements[player.UserId] = nil
		self.studioPasses[player.UserId] = nil
	end)

	return self
end

return Monetization
