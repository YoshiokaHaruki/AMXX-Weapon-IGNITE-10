# AMXX-Weapon-IGNITE-10
Grenade IGNITE-10 from Counter-Strike: Online for Counter-Strike 1.6 (based on AMX Mod X)

About this weapon: [Link](https://cso.fandom.com/wiki/IGNITE-10)

---
### Demo Video
[![IMAGE ALT TEXT HERE](https://img.youtube.com/vi/T3LLU10fCas/0.jpg)](https://youtu.be/T3LLU10fCas)

---
### Requirements
ReAPI version:
- ReHLDS, ReGameDLL, Metamod-R (or Metamod-P), AMX Mod X (≥ 1.8.2), ReAPI.

Non-ReAPI version:
- HLDS (> 6153), Metamod (or Metamod-P), AMX Mod X (≥ 1.8.2)

❗ Tip: Recommend using the latest versions.

---
### Install
- Pull all resources from the `extra` folder and move them to your server folder `cstrike`
- Pull all files from the `source` folder and move them to the `scripting` folder
- Open the file `zp_grenade_ignitebomb.sma` and configure it
  * **NB!** If your server does not support Re modules, find the line #include <reapi> and you should delete it or turn it off (using //)
  ```Pawn
  // #include <reapi>
  ```
- Compile `zp_grenade_ignitebomb.sma` file
- Compiled plugin, put it in the `plugins` folder on your server
