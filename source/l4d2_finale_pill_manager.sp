#include <sourcemod>
#include <sdktools>
#include <left4downtown>
#include <l4d2util_rounds>

public Plugin:myinfo =
{
	name = "[L4D2] Finale Pill Limiter",
	description = "Limits the amount of pills on a finale map. (Min: 0, Max: 4)",
	author = "Spoon",
	version = "2.0.9",
	url = "https://github.com/spoon-l4d2"
};

new Handle:ArrayPillSpawn;
new Handle:ArrayKitSpawn;
new Handle:cvarPillAmount;

public OnPluginStart()
{

	cvarPillAmount = CreateConVar("pm_finale_pill_limit", "2", "Amount of pills that will spawn on finales.", 0, true, 0.0, true, 4.0);

	HookEvent("round_start", RoundStart_Event, EventHookMode_Post);

	ArrayPillSpawn = CreateArray(128);
	ArrayKitSpawn = CreateArray(128);
}

public OnMapEnd()
{
	ClearArray(ArrayPillSpawn);
	ClearArray(ArrayKitSpawn);
}

public RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{		
	if(L4D_IsMissionFinalMap()){
		RemoveFinaleKitSpawns();
		RemoveFinalePillSpawns();
	}
}

public OnEntityCreated(entity, const String:classname[])
{
	if (!IsValidEntity(entity)) return Plugin_Continue;
	if (!L4D_IsMissionFinalMap()) return Plugin_Continue;

	if (StrEqual(classname, "weapon_pain_pills_spawn")) 
	{
		PushArrayCell(ArrayPillSpawn, entity);
	} 
	else if (StrEqual(classname, "weapon_first_aid_kit_spawn")) // Some maps you need to get the medkit spawns rather than pills. So it's best just to slap both on here
	{
		PushArrayCell(ArrayKitSpawn, entity);
	}

	return Plugin_Continue;
}

public void RemoveFinalePillSpawns()
{
	int count = GetArraySize(ArrayPillSpawn);

	decl String:mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	if (StrEqual(mapname, "c2m5_concert")) // for some reason this map is bugged i guess?
	{
		count += 1;
	}

	for (new i=0; i<(count-GetConVarInt(cvarPillAmount)); i++)
	{
		int index = GetArrayCell(ArrayPillSpawn, i);

		if (!IsValidEntity(index)) continue;

		AcceptEntityInput(index, "Kill");
	}
}

public void RemoveFinaleKitSpawns()
{
	int count = GetArraySize(ArrayKitSpawn);

	for (new i=0; i<(count-GetConVarInt(cvarPillAmount)); i++)
	{
		int index = GetArrayCell(ArrayKitSpawn, i);

		if (!IsValidEntity(index)) continue;

		AcceptEntityInput(index, "Kill");
	}
}

