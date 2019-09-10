# Hello there! 👋
This is a small repo where I keep all of my plugins. Still pretty new to creating plugins so you can expect a few nooby errors in my code 😄

---
### l4d2_sounds_blocker.smx
Sounds Blocker is a plugin that allows you to block certain sounds from being played. It's very useful for blocking loud unnecessary sounds. It comes with some built in presets and also allows you to add custom sounds. If a sound is blocked in a preset and you don't want that one specific sound to be blocked, you can whitelist it! View comments in source-code for more information.

---
### l4d2_witch_toggler.smx
The Witch Toggle plugin allows players to vote on whether or not they want the witch to spawn. Admins can force the toggle using `sm_forcewitch` or `!forcewitch`.

---
### readyup.smx
Custom version of readyup that allows more control over the footers. Creates new Natives that allow you to edit a footer.

---

### l4d2_boss_percents.smx
This is my custom version of both the `l4d_boss_percent.smx` plugin, as well as the vote boss plugin. It is updated to work with my **Witch Voter** plugin, as well as my custom ready up plugin. Meaning when you change boss percents, they will no longer stack on top of each other on the ready up panel! Boss vote commands are however slightly different now.

######	For admins:
When you type `!voteboss x y` it will no longer force those boss percents, it will call a vote like it does for any other player. If you wish to force boss percents, you can use the following commands:

`!fwitch x` This will force the Witch's spawn point to the specified percent.
`!ftank x` This will force the Tank's spawn point to the specified percent.

---

### l4d2_charger_getup_fix.smx
Allows control over long charger get ups. It will add god frames and allows for config developers to enable/disable them, and replace all long get-ups with normal animations. View source for more info and cvars.