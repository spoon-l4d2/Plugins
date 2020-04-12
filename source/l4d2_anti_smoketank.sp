#include <sourcemod>
#include <sdktools>
#include <l4d2util>
#include <pause>

int SmokedPlayer[MAXPLAYERS+1];
new Handle:cvarTime = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "[L4D2] Anti Insta-Smoke After Tank Punch",
	description = "Gives smoker a full cooldown when a tank punches their target.",
	author = "Spoon",
	version = "2.1.1",
	url = "https://github.com/spoon-l4d2"
};

public OnPluginStart()
{
	HookEvent("tongue_grab", TongueGrab, EventHookMode_Post);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
	cvarTime = CreateConVar("ast_recharge_duration", "13.0", "The duration of the Smoker recharge after a Tank Insta-clear. (13 = Full Normal Recharge)");
}

public TongueGrab(Handle:event, const String:name[], bool:dontBroadcast)
{	
	new Float:timeStamp = GetGameTime();
	new smoker = GetClientOfUserId(GetEventInt(event, "userid"));
	new survivorClient = GetClientOfUserId(GetEventInt(event, "victim"));

	if (IsTankUp())
	{
		SmokedPlayer[survivorClient] = smoker;
		ResetStatus(survivorClient, timeStamp);
	}
}

public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{ 
	new survivor = GetClientOfUserId(GetEventInt(event, "userid"));
	new tank = GetClientOfUserId(GetEventInt(event, "attacker"));
		
	if (!IsValidClient(survivor)) return Plugin_Continue;
	if (!IsValidClient(tank)) return Plugin_Continue;

	if (!IsTank(tank) || !IsSurvivor(survivor))
		return Plugin_Continue;

	if (IsTankUp())
	{
		if (SmokedPlayer[survivor] > 0)
		{
			new smoker = SmokedPlayer[survivor];
			
			if (IsInPause()) return Plugin_Continue;
			if (!IsValidClient(smoker)) return Plugin_Continue;
			
			SetSmokerAbility(smoker);
			SmokedPlayer[survivor] = -1;
		}
	}

	return Plugin_Continue;
}	

public void ResetStatus(int client, Float:TimeStamp)
{
	if (GetGameTime() < TimeStamp + 1.2) return;
	if (IsInPause()) return;
	
	if (SmokedPlayer[client] > 0)
	{
		SmokedPlayer[client] = -1;
	}
}

public SetSmokerAbility(int smoker)
{
	new time = GetGameTime() + GetConVarFloat(cvarTime); // this game is so weird (also thanks Daroot [aka they guy that made Spite])
	if(SetInfectedAbilityTimer(smoker, time, GetConVarFloat(cvarTime)))
	{
		PrintToServer("SetSmokerAbility [!] Success");
	}
	else
	{
		PrintToServer("SetSmokerAbility [!] Failed");
	}
}

public bool:IsValidClient(int client)
{
	if (client < 0 || client > MaxClients)
	{
		return false;
	}
	return IsClientInGame(client);
}

public bool:IsTankUp()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && GetEntProp(i, Prop_Send, "m_zombieClass") == 8 && IsPlayerAlive(i))
		{
			return true;
		}
	}
	return false;
}