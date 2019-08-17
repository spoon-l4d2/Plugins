#include <sourcemod>
#include <sdktools>
#include <l4d2_direct>
#include <left4downtown>
#include <builtinvotes>
#include <colors>
#include <l4d2util_rounds>
#include <bosspercent>
#include <readyup>

// ConVars
new Handle:cvar_Announce = INVALID_HANDLE;
new Handle:cvar_Cooldown = INVALID_HANDLE;

// Variables
new Handle:g_hVsBossBuffer;
new bool:g_bWitchEnabled;
new bool:g_bOnCooldown;
new Float:g_fWitchFlow;
new Float:g_fTankFlow;
new Handle:g_hStaticMaps;
new String:g_CurrentMap[64];
new Handle:g_hWitchVote = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "[L4D2] Witch Toggler",
	author = "Spoon",
	version = "1.2.6",
	description = "Allows players to vote on witch spawning at the start of a map. Created for NextMod."
};

public OnPluginStart()
{
	// Variable Setting
	g_hVsBossBuffer = FindConVar("versus_boss_buffer");
	g_hStaticMaps = CreateTrie();
	
	// ConVars
	cvar_Announce = CreateConVar("swt_command_announce", "1", "Enables/Disables the 'how to use command' message that is displayed to a user upon joining the server.");
	cvar_Cooldown = CreateConVar("swt_command_cooldown", "15", "Command cooldown length.");
	
	// Server Commands
	RegServerCmd("static_witch_map", StaticWitch_Command);
	
	// Console Commands
	RegConsoleCmd("sm_votewitch", VoteWitchCommand);
	RegConsoleCmd("sm_witchvote", VoteWitchCommand);
	
	// Admin Commands
	RegAdminCmd("sm_forcewitch", ForceWitchCommand, ADMFLAG_BAN);
	
	// Events
	HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);	
}

// ------ Misc Method(s) ------
public bool:ConVarBoolValue(Handle:cvar) {
	new value = GetConVarInt(cvar);
	if (value == 1) {
		return true;
	} else {
		return false;
	}
}
stock Float:GetTankFlow(round)
{
	return L4D2Direct_GetVSTankFlowPercent(round) -
		( Float:GetConVarInt(g_hVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance() );
}

stock Float:GetWitchFlow(round)
{
	return L4D2Direct_GetVSWitchFlowPercent(round) - Float:GetConVarInt(g_hVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance();
}
public void PutOnCooldown() {
	// Set OnCoolDown to True
	g_bOnCooldown = true;
	
	// Get ConVar Time
	new Float:time;
	time = GetConVarFloat(cvar_Cooldown);
	
	// Start Timer
	if (time > 0) {
		CreateTimer(time, CooldownReset);
	}
}
public Action:CooldownReset(Handle:timer){
	g_bOnCooldown = false;
	return Plugin_Handled;
}
// ------------

// ------ Static Map Adding ------
public Action:StaticWitch_Command(args)
{
	decl String:mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	SetTrieValue(g_hStaticMaps, mapname, true);
}

// ------ Round Start Event ------
public RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Set Variable
	g_bWitchEnabled = true;
	
	// Set Witch Spawn to 'true'
	L4D2Direct_SetVSWitchToSpawnThisRound(0, true);
	L4D2Direct_SetVSWitchToSpawnThisRound(1, true);
	
	// Get Current Map
	GetCurrentMap(g_CurrentMap, sizeof(g_CurrentMap));
}

// ------ Announce Command -----
public void OnClientPutInServer(int client)
{
	if (ConVarBoolValue(cvar_Announce))
	CreateTimer(5.0, WitchCMDMessage, GetClientSerial(client));
}
public Action:WitchCMDMessage(Handle timer, any serial)
{
	int client = GetClientFromSerial(serial);
	if (client == 0) return Plugin_Stop;
	if (!InSecondHalfOfRound() && IsInReady()){
		CPrintToChat(client, "{green}<{blue}WitchVoter{green}>{default} You can use {green}`!witchvote`{default} to call a vote to toggle on/off the Witch!");
	}
	return Plugin_Handled;
}
// ------

// ------ Witch Vote Command ------
public Action:VoteWitchCommand(client, args){

	// Just In Case :)
	if (!client) return Plugin_Handled;
	
	// Check if round is in second half
	if (InSecondHalfOfRound()) {
		CPrintToChat(client, "{green}<{blue}WitchVoter{green}>{default} The Witch Vote can only be called at the start of a map.");
		return Plugin_Handled;
	}
	
	// Check if round is live
	if (!IsInReady())  {
		CPrintToChat(client, "{green}<{blue}WitchVoter{green}>{default} The Witch Vote can only be called during ready-up.");
		return Plugin_Handled;
	}
	
	// Check if command is on cooldown
	if (g_bOnCooldown == true)  {
		CPrintToChat(client, "{green}<{blue}WitchVoter{green}>{default} The Witch Vote is currently on cooldown. Please wait and try again...");
		return Plugin_Handled;
	}
	
	// Check if player is spectator
	if (GetClientTeam(client) == 1)
	{
		CPrintToChat(client, "{green}<{blue}WitchVoter{green}>{default} Witch Voting is not allowed for Spectators.");
		return Plugin_Handled;
	}
	
	// Start Vote
	if (StartWitchVote(client))
	{
		FakeClientCommand(client, "Vote Yes");
	}
	return Plugin_Handled;
}

// ------ Witch Vote Stuff ------
bool:StartWitchVote(client)
{
	if (!IsBuiltinVoteInProgress())
	{
		// Get All Non-Spectating Players
		new iNumPlayers;
		decl iPlayers[MaxClients];
		for (new i=1; i<=MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) == 1))
			{
				continue;
			}
			iPlayers[iNumPlayers++] = i;
		}
		
		// Create Vote
		new String:sBuffer[64];
		g_hWitchVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);	
		
		if (g_bWitchEnabled) {
			g_fWitchFlow = GetWitchFlow(1);
			Format(sBuffer, sizeof(sBuffer), "Disable the Witch on Current Map");	
		} else {
			Format(sBuffer, sizeof(sBuffer), "Enable the Witch on Current Map");	
		}		
		
		SetBuiltinVoteArgument(g_hWitchVote, sBuffer);
		SetBuiltinVoteInitiator(g_hWitchVote, client);
		SetBuiltinVoteResultCallback(g_hWitchVote, VoteResultHandler);
		DisplayBuiltinVote(g_hWitchVote, iPlayers, iNumPlayers, 20);
		
		return true;
	}
	CPrintToChat(client, "{green}<{blue}WitchVoter{green}>{default} Witch Vote cannot be started now.");
	return false;
}
public VoteActionHandler(Handle:vote, BuiltinVoteAction:action, param1, param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			g_hWitchVote = INVALID_HANDLE;
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, BuiltinVoteFailReason:param1);
		}
	}
}
public VoteResultHandler(Handle:vote, num_votes, num_clients, const client_info[][2], num_items, const item_info[][2])
{
	for (new i=0; i<num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_clients / 2))
			{
				// One last ready-up check.
				if (!IsInReady())  {
					DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
					CPrintToChatAll("{green}<{blue}WitchVoter{green}>{default} The Witch Vote can only be called during ready-up.");
					return;
				}
				
				// Put Command on cooldown
				PutOnCooldown();
				
				// Check if witch has been enabled or disabled
				if (g_bWitchEnabled)
				{
					// Set Vote Title
					DisplayBuiltinVotePass(vote, "Disabling the Witch...");
					
					// Disable the Witch
					DisableWitch();
			
					// Print result to all
					CPrintToChatAll("{green}<{blue}WitchVoter{green}>{default} The Witch has been {green}disabled{default}!");
					
					// Update boss percents
					UpdateBossPercents();	
					UpdateRUP();			
					return;			
					
				} else {
					// Set Vote Title
					DisplayBuiltinVotePass(vote, "Enabling the Witch...");			
					
					// Enable the Witch
					EnableWitch();
					
					// Print result to all
					CPrintToChatAll("{green}<{blue}WitchVoter{green}>{default} The Witch has been {green}enabled{default}!");
					
					// Update boss percents
					UpdateBossPercents();
					UpdateRUP();
					return;
				}
			}
		}
	}
	
	// Vote Failed
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return;
}
// ------------

// ------ Update RUP Menu ------
public void UpdateRUP(){
	new String:newFooter[65];
	new tankPercent;
	new witchPercent;
	tankPercent = RoundToNearest(g_fTankFlow*100.0);
	witchPercent = RoundToNearest(g_fWitchFlow*100.0);
	
	// Usually the index of Boss Percents Will be 1, but just in case lets check.
	int index;
	index = FindIndexOfFooterString("Tank:");
	
	if (g_bWitchEnabled){
		Format(newFooter, sizeof(newFooter), "Tank: %d%%, Witch: %d%%", tankPercent, witchPercent);		
	} else {
		Format(newFooter, sizeof(newFooter), "Tank: %d%%, Witch: Disabled", tankPercent);
	}
	
	EditFooterStringAtIndex(index, newFooter);
}


// ------ Witch Enable/Disable Methods ------
public void DisableWitch(){			
	// Store the Flow before disabling - doing it here incase it's changed via !voteboss'
	g_fWitchFlow = GetWitchFlow(1);
	g_fTankFlow = GetTankFlow(1);
	
	// Set Witch to Spawn as false, and set witch flow to 0
	L4D2Direct_SetVSWitchFlowPercent(0, 0.0);
	L4D2Direct_SetVSWitchFlowPercent(1, 0.0);
	L4D2Direct_SetVSWitchToSpawnThisRound(0, false);
	L4D2Direct_SetVSWitchToSpawnThisRound(1, false);
	
	// Set Witch Enabled to false
	g_bWitchEnabled = false;
}

public void EnableWitch(){

	// For Storing our trie value
	new tempValue;
	
	// Check if map has static witch spawn
	if (!GetTrieValue(g_hStaticMaps, g_CurrentMap, tempValue))
	{
		// Non-Static Witch Map - Set Flow
		L4D2Direct_SetVSWitchFlowPercent(0, g_fWitchFlow);
		L4D2Direct_SetVSWitchFlowPercent(1, g_fWitchFlow);					
	}
	
	// Enable Witch Spawning
	L4D2Direct_SetVSWitchToSpawnThisRound(0, true);
	L4D2Direct_SetVSWitchToSpawnThisRound(1, true);
	
	// Set Witch Enabled to true
	g_bWitchEnabled = true;
}
// ------------

// ------ Admin Command ------
public Action:ForceWitchCommand(client, args){
	// Check if round is live
	if (!IsInReady())  {
		CPrintToChat(client, "{green}<{blue}WitchVoter{green}>{default} The Witch can only be toggled during ready-up.");
		return Plugin_Handled;
	}
	
	// Get Admin Name
	new String:clientName[32];
	GetClientName(client, clientName, sizeof(clientName));

	if (g_bWitchEnabled){
	
		// Disable Witch
		DisableWitch();
		
		// Print result to all
		CPrintToChatAll("{green}<{blue}WitchVoter{green}>{default} The Witch has been {green}disabled{default} by Admin {blue}%s{default}!", clientName);
		
		// Set Witch Enabled to true
		g_bWitchEnabled = false;
		
		// Update boss percents
		UpdateBossPercents();	
		
		
	} else {
	
		// Enable Witch
		EnableWitch();
		
		// Print result to all
		CPrintToChatAll("{green}<{blue}WitchVoter{green}>{default} The Witch has been {green}enabled{default} by Admin {blue}%s{default}!", clientName);
		
		// Set Witch Enabled to true
		g_bWitchEnabled = true;
		
		// Update boss percents
		UpdateBossPercents();	
		
	}
	return Plugin_Handled;
}
