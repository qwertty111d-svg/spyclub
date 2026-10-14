# Club Identity Implementation Plan

> **For agentic workers:** Use native execution in this existing isolated checkout. Track steps below.

**Goal:** Give SPY CLUB a distinctive usable dossier, useful coins, varied rewards and a coherent atmosphere.

**Architecture:** Shared DailyRewardConfig and ClubStoreConfig drive server/UI values. Existing Economy/Profiles own all wallet mutations; the receipt controller remains unchanged. Dossier, coin store and paid shop retain existing modal/request contracts.

**Tech Stack:** Luau 0.742, Roblox instances/services, Python place builder.

**Spec:** ../specs/2026-10-14-club-identity-design.md

## Global Constraints

- One existing Profiles/DataStore and receipt owner per scene.
- Paid packs remain 99/279/449 for 1/3/5; no invented product IDs.
- Coin collection never enters random pools or buys Rolls.
- Minimum primary touch targets 44 px; actual server pool probabilities.
- Native implementation in /workspace/spyclub; no new worktree or implementation agents.

## Review Focus

- Repeated weekly items show compensation that equals the actual saved grant.
- Restricted paid Rolls still allow deterministic coin purchases and earned spending.
- Missing assets/categories/prices produce explicit unavailable states without invented values.
- Lost purchase/equip acknowledgements cannot double spend or falsely grant.
- Entry audio, unavailable tracks, phone/trade and narrow screens preserve usable controls.

## 1. Rewards and collection

- [x] Add failing actual-module tests for the 7-day cycle, repeat compensation, claim replay, coin store whitelist/insufficient funds/trade locks and pool exclusion.
- [x] Add both shared configs, six themed catalog entries and native pin/watch support.
- [x] Replace Daily's forced daily=2 logic; add Economy clubBuy and mirror both scenes.
- [x] Run focused economy tests; update dependency loaders to load the real new configs.

## 2. Dossier and shop

- [x] Add failing GUI tests for visible rarity odds and individual/identity odds, plus coin purchase/equip.
- [x] Recompose AccessoryRollUI portrait/typography/materials and clear chance controls.
- [x] Add ClubStoreUI and connect lobby/match/phone/H with the existing paid shop.
- [x] Recompose daily week and paid shop, retaining native prompt and recovery contracts.
- [x] Run real GUI geometry/lifecycle tests and inspect a headless layout render where possible.

## 3. Atmosphere and release

- [x] Exercise generation of unlettered rugs and audio transitions with minimal service stubs.
- [x] Remove runner lettering, modestly increase room light, add rotating verified music with failure recovery.
- [x] Full validation, binary build V131/V92, independent property comparison and ZIP verification.
- [x] Update docs/environment filenames, commit and push main; confirm remote SHA and clean worktree.
