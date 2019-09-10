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

// Cvars
new Handle:cvar_longChargeGetUpFixEnabled = INVALID_HANDLE;
new Handle:cvar_keepWallSlamLongGetUp = INVALID_HANDLE;
new Handle:cvar_keepLongChargeLongGetUp = INVALID_HANDLE;

// Fake godframe event variables
new g_gfcSurvivor;
new g_gfcCharger;
new g_gfcRescuer;

// Variables
new ChargerTarget[MAXPLAYERS+1];

public Plugin:myinfo = 
{
	name = "[L4D2] Long Charger Get-Up Fix",
	author = "Spoon",
	description = "Allows control over long charger get ups.",
	version = "2",
	url = "https://github.com/spoon-l4d2"
};

public OnPluginStart()
{
	// Event Hooks
	HookEvent("charger_killed", Event_ChargerKilled, EventHookMode_Post);
	HookEvent("charger_carry_start", Event_ChargeCarryStart, EventHookMode_Post);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("charger_pummel_start", Event_PummelStart, EventHookMode_Post);
	HookEvent("charger_pummel_end", Event_PummelStart, EventHookMode_Post);
	
	// Cvars
	cvar_longChargeGetUpFixEnabled = CreateConVar("charger_long_getup_fix", "1", "Enable the long Charger get-up fix?");
	cvar_keepWallSlamLongGetUp = CreateConVar("charger_keep_wall_charge_animation", "1", "Enable the long wall slam animation (with god frames)");
	cvar_keepLongChargeLongGetUp = CreateConVar("charger_keep_far_charge_animation", "0", "Enable the long 'far' slam animation (with god frames)");
}

// ==========================================
// ================= Events =================
// ==========================================

public PlayClientGetUpAnimation(client)
{
	L4D2Direct_DoAnimationEvent(client, 78);
}

public CancelGetUpAnimation(client)
{
	SetEntPropFloat(client, Prop_Send, "m_flCycle", 1000.0);
}

public FireGodFrameEvent()
{
	Event fakeGodFrameEvent = CreateEvent("charger_pummel_end", true);
	fakeGodFrameEvent.SetInt("userid", g_gfcCharger);
	fakeGodFrameEvent.SetInt("victim", g_gfcSurvivor);
	fakeGodFrameEvent.SetInt("rescuer", g_gfcRescuer);
	fakeGodFrameEvent.Fire(true);
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{	
	for (new i = 0; i < MAXPLAYERS+1; i++)
	{
		if (ChargerTarget[i] != -1)
			ChargerTarget[i] = -1;
	}
}

public Event_PummelStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(cvar_longChargeGetUpFixEnabled)) return;

	new chargerClient = GetClientOfUserId(GetEventInt(event, "userid"));
	new survivorClient = GetClientOfUserId(GetEventInt(event, "victim"));

	ChargerTarget[chargerClient] = survivorClient;
}

public Event_ChargerKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(cvar_longChargeGetUpFixEnabled)) return;

	new chargerClient = GetClientOfUserId(GetEventInt(event, "userid"));
	new survivorClient = ChargerTarget[chargerClient];

	if (survivorClient > -1)
	{
		// God Frame Event Variables
		g_gfcRescuer = GetEventInt(event, "attacker");
		g_gfcSurvivor = GetClientUserId(survivorClient);
	
		if (IsPlayingGetUpAnimation(survivorClient, 2))
		{ // Long Charge Get Up
			if (GetConVarBool(cvar_keepLongChargeLongGetUp))
			{
				FireGodFrameEvent();
			}
			else
			{
				CancelGetUpAnimation(survivorClient)
				PlayClientGetUpAnimation(survivorClient);
				FireGodFrameEvent();
			}
		} 
		else if (IsPlayingGetUpAnimation(survivorClient, 1))
		{ // Wall Slam Get Up
			if (GetConVarBool(cvar_keepWallSlamLongGetUp))
			{
				FireGodFrameEvent();
			}
			else
			{
				CancelGetUpAnimation(survivorClient)
				PlayClientGetUpAnimation(survivorClient);
				FireGodFrameEvent();
			}
		}
		else
		{
			// There's a weird case, where the game won't register the client as playing the animation, it's once in a blue moon
			CreateTimer(0.02, BlueMoonCaseCheck, survivorClient);
		}
	}
	
	ChargerTarget[chargerClient] = -1;
}

public Action:BlueMoonCaseCheck(Handle:timer, survivorClient)
{
	if (IsPlayingGetUpAnimation(survivorClient, 2))
	{ // Long Charge Get Up
		if (GetConVarBool(cvar_keepLongChargeLongGetUp))
		{
			FireGodFrameEvent();
		}
		else
		{
			CancelGetUpAnimation(survivorClient)
			PlayClientGetUpAnimation(survivorClient);
			FireGodFrameEvent();
		}
	} 
	else if (IsPlayingGetUpAnimation(survivorClient, 1))
	{ // Wall Slam Get Up
		if (GetConVarBool(cvar_keepWallSlamLongGetUp))
		{
			FireGodFrameEvent();
		}
		else
		{
			CancelGetUpAnimation(survivorClient)
			PlayClientGetUpAnimation(survivorClient);
			FireGodFrameEvent();
		}
	}
}

public Event_ChargeCarryStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(cvar_longChargeGetUpFixEnabled)) return;

	new chargerClient = GetClientOfUserId(GetEventInt(event, "userid"));
	new survivorClient = GetClientOfUserId(GetEventInt(event, "victim"));
	
	ChargerTarget[chargerClient] = survivorClient;
}

public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{ // Wall Slam Charge Checks

	if (!GetConVarBool(cvar_longChargeGetUpFixEnabled)) return;

	new survivorClient;
	new chargerClient;
	new survivorUserId =  GetEventInt(event, "userid");
	new chargerUserId = GetEventInt(event, "attacker");
	
	if (survivorUserId)
		survivorClient = GetClientOfUserId(survivorUserId);
	if (chargerUserId)
		chargerClient = GetClientOfUserId(chargerUserId);
		
	if (!IsCharger(chargerClient) && !IsSurvivor(survivorClient)) return;

	// God Frame Variables
	if (survivorClient > 0)
		g_gfcSurvivor = GetClientUserId(survivorClient);
	if (chargerClient > 0)
		g_gfcCharger = GetClientUserId(chargerClient);
	
	ChargerTarget[chargerClient] = survivorClient; 
}

// ==========================================
// ================= Checks =================
// ==========================================

stock GetSequenceInt(client, type)
{
	if (client < 1) return -1;

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
	if (survivor < 1)
		return false;

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
