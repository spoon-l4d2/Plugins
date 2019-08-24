#include <sourcemod>
#include <sdktools>
#include <left4downtown>

public Plugin:myinfo = 
{
	name = "[L4D2] Unsilent Hunters",
	author = "Spoon",
	description = "Makes Hunters emit a sound to all players upon spawning, to nerf wallkicks a bit more. Made for NextMod.",
	version = "1.0.2",
	url = "https://github.com/spoon-l4d2"
};

new String:g_aHunterSounds[5][]= 
{
	"player/hunter/voice/alert/hunter_alert_01.wav",
	"player/hunter/voice/alert/hunter_alert_02.wav",
	"player/hunter/voice/alert/hunter_alert_03.wav",
	"player/hunter/voice/alert/hunter_alert_04.wav",
	"player/hunter/voice/alert/hunter_alert_05.wav"
}

public OnPluginStart()
{
	HookEvent("player_spawn", PlayerSpawn_Event);
}


public OnMapStart()
{
	for (new i = 0; i < 5; i++)
	{
		PrefetchSound(g_aHunterSounds[i]);
		PrecacheSound(g_aHunterSounds[i], true);
	}
}

public Action:PlayerSpawn_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	// Check if client is hunter
	
	if (!IsHunter(client)) return Plugin_Continue;

	// Pick random hunter sound and play it
	new randomSound = GetRandomInt(0, 5);
	EmitSoundToAll(g_aHunterSounds[randomSound], client, SNDCHAN_AUTO, SNDLEVEL_NORMAL);

	return Plugin_Continue;
}

stock bool:IsHunter(client)  
{
	if (GetEntProp(client, Prop_Send, "m_zombieClass") != 3)
		return false;

	return true;
}