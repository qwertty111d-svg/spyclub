-- Server-owned configuration. Create products in THIS experience, then insert their real IDs.
-- Empty arrays intentionally hide unconfigured Robux offers. No paid Coins or random rewards.
return {
    -- Existing lobby pass; verified independently after teleport into Match.
    RollLuckPassId = 1998344385,
    Passes = {
        -- {id=YOUR_GAME_PASS_ID, key="vipPack", ids={"tuxedo","gilded_frame","supporter"}},
        -- {id=YOUR_EMOTE_PASS_ID, key="emotePack", ids={"wave","supporter"}},
    },
    Products = {
        -- {id=YOUR_SUPPORT_PRODUCT_ID, key="supportPack", ids={"supporter"}},
    },
}
