#include <sourcemod>
#include <left4downtown>
#include <l4d2_direct>
#include <events>

// Charges that land against a wall and are cleared instantly
#define SEQ_INSTANT_NICK 671
#define SEQ_INSTANT_COACH 660
#define SEQ_INSTANT_ELLIS 675
#define SEQ_INSTANT_ROCHELLE 678
#define SEQ_INSTANT_ZOEY 823
#define SEQ_INSTANT_BILL 763
#define SEQ_INSTANT_LOUIS 763
#define SEQ_INSTANT_FRANCIS 766

// Charges charge all the way and are then cleared instantly
#define SEQ_LONG_NICK 672
#define SEQ_LONG_COACH 661
#define SEQ_LONG_ELLIS 676
#define SEQ_LONG_ROCHELLE 679
#define SEQ_LONG_ZOEY 824
#define SEQ_LONG_BILL 764
#define SEQ_LONG_LOUIS 764
#define SEQ_LONG_FRANCIS 765


public Plugin:myinfo = 
{
	name = "[L4D2] Charger Get-Up Fix",
	author = "Spoon",
	description = "Prevents long charger get ups.",
	version = "1",
	url = "https://github.com/spoon-l4d2"
};

// Cvars
new Handle:cvar_longGetUpFixEnabled;
new Handle:cvar_playNormalAnimation;
new Handle:cvar_godFrameNormalAnimation;
new Handle:cvar_instantChargeAnimBuffer;

// Handle
new ChargerTargets[MAXPLAYERS+1];

// Variables
new gfc_fakeUserID;
new gfc_fakeVictim;
new gfc_fakeRescuer;

public OnPluginStart()
{
	// Event Hooks
	HookEvent("charger_killed", Event_ChargerKilled, EventHookMode_Post);
	HookEvent("charger_carry_start", Event_ChargeStart, EventHookMode_Post);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	
	// ConVars
	cvar_longGetUpFixEnabled = CreateConVar("long_charger_getup_fix", "1", "Stop long charger get ups.");
	cvar_playNormalAnimation = CreateConVar("long_charger_getup_replace_anim", "1", "Replace long charger get-ups with normal ones.");
	cvar_godFrameNormalAnimation = CreateConVar("long_charger_getup_replace_godframes", "1", "Apply fake god frames to replaced animation.");
	cvar_instantChargeAnimBuffer = CreateConVar("long_charger_instant_charge_getup_buffer", "0.0");
}

public RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{	
	// Reset our variables right quick
	
	for (new i = 0; i < MAXPLAYERS+1; i++)
	{
		if (ChargerTargets[i] != -1)
			ChargerTargets[i] = -1;
	}
}

public PlayNormalGetUpAnimation(client)
{
	
	if (GetConVarBool(cvar_playNormalAnimation))
		L4D2Direct_DoAnimationEvent(client, 78);
	
	if (GetConVarBool(cvar_godFrameNormalAnimation))
	{
		Event fakeGodFrameEvent = CreateEvent("charger_pummel_end", true);
		gfc_fakeVictim = GetClientUserId(client);
		fakeGodFrameEvent.SetInt("userid", gfc_fakeUserID);
		fakeGodFrameEvent.SetInt("victim", gfc_fakeVictim);
		fakeGodFrameEvent.SetInt("rescuer", gfc_fakeRescuer);
		fakeGodFrameEvent.Fire(true);
	}
}

public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(cvar_longGetUpFixEnabled))
		return;

	new survivorClient = GetClientOfUserId(GetEventInt(event, "userid"));
	new chargerClient = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (IsCharger(chargerClient) && IsSurvivor(survivorClient))
	{
		gfc_fakeUserID = GetClientUserId(chargerClient);
		CreateTimer(GetConVarFloat(cvar_instantChargeAnimBuffer), CancelAnim, survivorClient);
	}
}

public Action:CancelAnim(Handle:timer, client)
{
	if (IsPlayingGetUpAnimation(client, 1))
	{
		SetEntPropFloat(client, Prop_Send, "m_flCycle", 1000.0);
		PlayNormalGetUpAnimation(client);
	}
}

public Event_ChargeStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(cvar_longGetUpFixEnabled))
		return;

	new chargerClient = GetClientOfUserId(GetEventInt(event, "userid"));
	new chargerTarget = GetClientOfUserId(GetEventInt(event, "victim"));
	
	ChargerTargets[chargerClient] = chargerTarget;
}

public Event_ChargerKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(cvar_longGetUpFixEnabled))
		return;

	new chargerClient = GetClientOfUserId(GetEventInt(event, "userid"));
	new chargerTarget = ChargerTargets[chargerClient];


	if (chargerTarget > -1)
	{
		if (IsPlayingGetUpAnimation(chargerTarget, 2))
		{
			gfc_fakeRescuer = GetEventInt(event, "attacker");
			SetEntPropFloat(chargerTarget, Prop_Send, "m_flCycle", 1000.0);
			PlayNormalGetUpAnimation(chargerTarget);
		}
	}
	
	ChargerTargets[chargerClient] = -1;
}


stock bool:IsCharger(client)  
{
	if (!IsInfected(client))
		return false;

	if (GetEntProp(client, Prop_Send, "m_zombieClass") != 6)
		return false;

	return true;
}

bool:IsPlayingGetUpAnimation(survivor, type)  
{
	new sequence = GetEntProp(survivor, Prop_Send, "m_nSequence");
	if (sequence == GetSequenceInt(survivor, type)) return true;
	return false;
}

stock bool:IsSurvivor(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

stock bool:IsInfected(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3;
}

stock GetSequenceInt(client, type)
{
	decl String:survivorModel[PLATFORM_MAX_PATH];
	GetClientModel(client, survivorModel, sizeof(survivorModel));
	
	if(StrEqual(survivorModel, "models/survivors/survivor_coach.mdl", false))
	{
		switch(type)
		{
			case 1: return SEQ_INSTANT_COACH;
			case 2: return SEQ_LONG_COACH;
		}
	}
	else if(StrEqual(survivorModel, "models/survivors/survivor_gambler.mdl", false))
	{
		switch(type)
		{
			case 1: return SEQ_INSTANT_NICK;
			case 2: return SEQ_LONG_NICK;
		}
	}
	else if(StrEqual(survivorModel, "models/survivors/survivor_producer.mdl", false))
	{
		switch(type)
		{
			case 1: return SEQ_INSTANT_ROCHELLE;
			case 2: return SEQ_LONG_ROCHELLE;
		}
	}
	else if(StrEqual(survivorModel, "models/survivors/survivor_mechanic.mdl", false))
	{
		switch(type)
		{
			case 1: return SEQ_INSTANT_ELLIS;
			case 2: return SEQ_LONG_ELLIS;
		}
	}
	else if(StrEqual(survivorModel, "models/survivors/survivor_manager.mdl", false))
	{
		switch(type)
		{
			case 1: return SEQ_INSTANT_LOUIS;
			case 2: return SEQ_LONG_LOUIS;
		}
	}
	else if(StrEqual(survivorModel, "models/survivors/survivor_teenangst.mdl", false))
	{
		switch(type)
		{
			case 1: return SEQ_INSTANT_ZOEY;
			case 2: return SEQ_LONG_ZOEY;
		}
	}
	else if(StrEqual(survivorModel, "models/survivors/survivor_namvet.mdl", false))
	{
		switch(type)
		{
			case 1: return SEQ_INSTANT_BILL;
			case 2: return SEQ_LONG_BILL;
		}
	}
	else if(StrEqual(survivorModel, "models/survivors/survivor_biker.mdl", false))
	{
		switch(type)
		{
			case 1: return SEQ_INSTANT_FRANCIS;
			case 2: return SEQ_LONG_FRANCIS;
		}
	}
	
	return -1;
}
