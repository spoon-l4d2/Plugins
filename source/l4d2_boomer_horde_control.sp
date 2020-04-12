/*
*
*	So, how does this thing work?
*	Welp, it's fairly easy you simply load the plugin, and use these commands in your config's files.
* 	' bhc_boom_horde_set <amount of boomed survivors> <amount of horde to spawn> '
*	
*	@param boomed - The amount of survivors that will need to be boomed.
*	@param horde - The amount of horde that will spawn as a result.
*	bhc_boom_horde_set <boomed> <horde>
*
* ----------------------------------------------------------------------------------------------------------------
*
*	Please note, the amount of specified horde will spawn once the boomed survivor count reaches that amount. 
*	Meaning, if you want a TOTAL of 15 common to spawn when two survivors are boomed you would need to do this:
*
*	bhc_boom_horde_set 	1 	5 		-		Spawn 5 common when 1 survivor gets boomed
*	bhc_boom_horde_set 	2 	10 		-		Spawn 10 common when 2nd survivor gets boomed (Total of 15 spawned.)
*
*	(or however else you want to divide it up, could be 1 3 and 2 12 if you want it to be.)
*
*/

#include <sourcemod>
#include <left4downtown>

new BoomHordeEvents[32];
new BoomedCount;

public Plugin:myinfo =
{
	name = "[L4D2] Boomer Horde Control",
	description = "Allows control over boomer horde sizes.",
	author = "Spoon",
	version = "1.2.1",
	url = "https://github.com/spoon-l4d2"
};

public OnPluginStart()
{
	RegServerCmd("bhc_boom_horde_set", ServerCommand_SetBoomHorde, "Usage: bhc_boom_horde_set <amount of boomed survivors> <amount of horde to spawn>"); // Just so there can be some support for configs that have more than 4 survivors
	HookEvent("player_no_longer_it", Event_PlayerBoomedExpired);
}

public Action:ServerCommand_SetBoomHorde(args)
{
	new String:survBoomed[32];
	new String:boomSize[252];
	GetCmdArg(1, survBoomed, sizeof(survBoomed));
	GetCmdArg(2, boomSize, sizeof(boomSize));
	BoomHordeEvents[StringToInt(survBoomed, 10)] = StringToInt(boomSize, 10);
}

public Action:L4D_OnSpawnITMob(&amount)
{
	BoomedCount += 1;
	if (BoomHordeEvents[BoomedCount] != amount) amount = BoomHordeEvents[BoomedCount];
	if (!amount) amount = 10;
}

public Event_PlayerBoomedExpired(Handle:event, String:name[], bool:dontBroadcast)
{
	BoomedCount -= 1;
}

 