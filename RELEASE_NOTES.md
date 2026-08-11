# AdiBags Ascension 3.3.5-ASCa

Ascension-focused fork of AdiBags for Project Ascension (3.3.5 client).

## Features

- **Ascension junk auto-sell** — When Ascension’s merchant Auto Sell Junk checkbox is enabled, also sell items AdiBags considers junk (including items dragged into the Junk section). Grey items remain handled by Ascension.
- **Empty Junk drop target** — Optional sticky Junk section header when empty so you can drag items onto it to mark them for sell.
- **One-shot drag marks** — Drag-to-Junk marks clear after auto-sell so buyback/recover is not sold again; manual Include list entries stay marked.
- **Bulk sell confirmation** — Selling more than 10 AdiBags junk stacks prompts a warning that Ascension recovery costs more than merchant buyback.
- **Reset new items on bag close** — Optional Track new items setting to clear “new” status when a bag closes.
- **Keyring support** — Keyring bag slot, hide-keyring character setting, and safer updates when the keyring is hidden.
- **Personal / Guild / Realm bank** — Bank type detection, session-safe guild bank tab handling, and layout/anchor fixes for personal bank.
- **Stack split** — Shift+left-click stack split for backpack, bank, and guild/personal bank without breaking modifier clicks (links, tradeskill use).
- **Worldforged section** — Tooltip-tagged Worldforged items are sorted into their own Equipment section.

## Fixes in 3.3.5-ASCa

- **Ascension vanity sorting** — Quality-6 Ascension/Vanity items are classified before Worldforged tooltip scanning, and SetHyperlink errors no longer abort the Ascension filter.

## Compatibility

- ElvUI / Masque: bag slot toggle created for personal bank (hidden) so skins expecting that widget do not error.
- Optional Scrap / BrainDead junk sources for detection only.

## Install

Extract so `AdiBags` and `AdiBags_Ascension` sit directly under `Interface\AddOns`, then fully restart the client.
