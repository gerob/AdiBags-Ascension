# AdiBags for Project Ascension

**AdiBags Ascension** is a fork of AdiBags for the Project Ascension 3.3.5 client. It keeps the filtered-section bag UI from Adirelle’s original addon (via the [WoTLK 3.3.5 backport](https://github.com/Sattva-108/AdiBags-WoTLK-3.3.5)) and adds Ascension-specific bank, keyring, junk, and merchant behavior.

**Version:** `3.3.5-ASCc`  
**Repository:** [gerob/AdiBags-Ascension](https://github.com/gerob/AdiBags-Ascension)

---

## Installation

### 1. Download

Get the latest release ZIP from [Releases](https://github.com/gerob/AdiBags-Ascension/releases). Prefer a **Release** asset over cloning the raw repository unless you need a development build.

### 2. Extract and place folders

Extract the ZIP. You should see **two** addon folders. Copy both into your Ascension `Interface\AddOns` directory, keeping the folder names exactly as they are:


| Folder              | Required?   | Purpose                         |
| ------------------- | ----------- | ------------------------------- |
| `AdiBags`           | Yes         | Core bag addon                  |
| `AdiBags_Ascension` | Recommended | Ascension-specific item filters |


Typical path:

`...\Ascension\resources\ascension-live\Interface\AddOns`

**Correct layout:**

```text
Interface\AddOns\
  AdiBags\
  AdiBags_Ascension\
```

**Common mistakes:**

- Nesting an extra folder (e.g. `AddOns\AdiBags_Ascension-v3.3.5-ASCa\AdiBags\…`) — Ascension will not load it.
- Renaming folders or only copying the outer ZIP folder.
- Leaving an older `AdiBags` folder next to a new one with a different name.



### 3. Restart the client

Fully quit and restart Ascension (a UI reload alone is not enough for a first install).

### 4. Confirm it loaded

1. At the character select screen (or in-game), open the addon list and ensure **AdiBags** (and **AdiBags - Ascension support** if installed) are enabled.
2. Log in and open your bags, or run `/adibags` / `/adi` to open configuration.

---



## Usage


| Action                             | What it does                                          |
| ---------------------------------- | ----------------------------------------------------- |
| `/adibags` or `/adi`               | Open the AdiBags configuration panel                  |
| Left-click the bag icon (top-left) | Manage equipped bags / keyring                        |
| Drag an item onto a section header | Assign that item to that section (Manual Filtering)   |
| Drag an item onto **Junk**         | Mark it as junk (for sorting and Ascension auto-sell) |


Enable or configure modules under **Filters** and **Modules** in the `/adi` options.

---



## Ascension features

- **Merchant junk sell** — With Ascension’s merchant **Auto Sell Junk** checkbox enabled, AdiBags also sells items it considers junk (including items dragged into Junk). Greys stay handled by Ascension. Toggle under **Filters → Junk**.
- **Empty Junk section** — Keep a Junk header visible when empty so you always have a drop target (**Show empty Junk section**).
- **One-shot drag marks** — Drag-to-Junk marks clear after auto-sell so buyback/recover is not sold again; items on the Junk **Include list** stay marked permanently.
- **Reset new items on bag close** — Optional setting under **Filters → Track new items**.
- **Keyring** — Dedicated keyring slot button and character option to hide the keyring section.
- **Personal / Guild / Realm bank** — Bank type detection, safer guild/personal bank tab handling, and layout fixes (including ElvUI skin compatibility for personal bank).
- **Stack split** — Shift+left-click stack split on backpack, bank, and guild/personal bank without breaking chat links or other modifier clicks.
- **Worldforged section** — Items tagged Worldforged in their tooltip are grouped under Equipment → Worldforged (AdiBags_Ascension filter).

See [RELEASE_NOTES.md](RELEASE_NOTES.md) for the current release summary.

---



## Optional dependencies

AdiBags works alone. Optional integrations include **Masque**, **Scrap**, **BrainDead**, **LibSharedMedia-3.0**, and ElvUI skins.

---



## Credits

- [AdiAddons / AdiBags](https://github.com/AdiAddons/AdiBags) — original addon by Adirelle
- [Sattva-108/AdiBags-WoTLK-3.3.5](https://github.com/Sattva-108/AdiBags-WoTLK-3.3.5) — 3.3.5 backport this fork builds on
- Ascension filter plugin authors (AdiBags_Ascension)



## Support & issues

- Releases and downloads: [github.com/gerob/AdiBags-Ascension/releases](https://github.com/gerob/AdiBags-Ascension/releases)
- Bugs and requests: [Issues](https://github.com/gerob/AdiBags-Ascension/issues)

