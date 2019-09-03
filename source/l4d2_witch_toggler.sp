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
new Handle:g_hWitchVote = INVALID_HANDLE;
new Handle:g_hDisabledMap;
new Float:EntityOrigin[3];
new iEnt;

public Plugin:myinfo =
{
	name = "[L4D2] Witch Toggler",
	author = "Spoon",
	version = "2.2.9",
	description = "Allows players to vote on witch spawning at the start of a map. Created for NextMod."
};

public OnPluginStart()
{
	// Variable Setting
	g_hVsBossBuffer = FindConVar("versus_boss_buffer");
	g_hDisabledMap = CreateTrie();
	
	// ConVars
	cvar_Announce = CreateConVar("swt_command_announce", "1", "Enables/Disables the 'how to use command' message that is displayed to a user upon joining the server.");
	cvar_Cooldown = CreateConVar("swt_command_cooldown", "15", "Command cooldown length.");
	
	// Console Commands
	RegConsoleCmd("sm_votewitch", VoteWitchCommand);
	RegConsoleCmd("sm_witchvote", VoteWitchCommand);
	
	// Server Commands
	RegServerCmd("no_witch_vote_map", NoWitchVoteMap_Command);
	
	// Admin Commands
	RegAdminCmd("sm_forcewitch", ForceWitchCommand, ADMFLAG_BAN);
	
	// Events
	HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
}

// ========================================================
// =================== No Witch Vote ======================
// ========================================================
// Server Command - When it is executed it will add a static tank map name to a list.
public Action:NoWitchVoteMap_Command(args)
{
	decl String:mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	SetTrieValue(g_hDisabledMap, mapname, true);
}

public bool:WitchVoteAllowed(){
	new String:g_sCurrentMap[64];
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
	new tempValue;
	if (!GetTrieValue(g_hDisabledMap, g_sCurrentMap, tempValue)) {
		return true;				
	}
	else {
		return false;
	}
}

// ========================================================
// ======================== Events ========================
// ========================================================

public RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{	
	if (InSecondHalfOfRound())
		CreateTimer(8.0, DisableRoundTwoStaticWitch);
}

public OnMapStart()
{
	// Set Variable
	g_bWitchEnabled = true;
}

// ========================================================
// ========================= Misc =========================
// ========================================================

public void OnUpdateBosses(){
	new Float:newFlow = GetWitchFlow(0);
	
	if (g_bWitchEnabled == false) {
		if (newFlow > 0) {
			g_fWitchFlow = newFlow;
			if (InSecondHalfOfRound()) {
				DisableWitch();
			} else {
				EnableWitch();
				CPrintToChatAll("{green}<{blue}WitchVoter{green}>{default} The Witch has been {green}enabled{default}!");
			}
		}
	}
}

public bool:ConVarBoolValue(Handle:cvar) {
	new value = GetConVarInt(cvar);
	if (value == 1) {
		return true;
	} else {
		return false;
	}
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

// ========================================================
// ===================== Annonuce Cmd =====================
// ========================================================

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

// ========================================================
// ================== Witch Voting Command ================
// ========================================================

public Action:VoteWitchCommand(client, args){

	// Just In Case :)
	if (!client) return Plugin_Handled;
	
	// Check if round is in second half
	if (!WitchVoteAllowed()) {
		CPrintToChat(client, "{green}<{blue}WitchVoter{green}>{default} The Witch Vote is not available on this map.");
		return Plugin_Handled;
	}
	
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

// ========================================================
// ===================== Witch Voting =====================
// ========================================================

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
			g_fWitchFlow = GetWitchFlow(0);
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
			
					return;			
					
				} else {

					// Set Vote Title
					DisplayBuiltinVotePass(vote, "Enabling the Witch...");			

					// Enable the Witch
					EnableWitch();
					
					// Print result to all
					CPrintToChatAll("{green}<{blue}WitchVoter{green}>{default} The Witch has been {green}enabled{default}!");

					return;
				}
			}
		}
	}
	
	// Vote Failed
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return;
}


// ========================================================
// =============== Witch Controling Methods ===============
// ========================================================

public Action:DisableRoundTwoStaticWitch(Handle:timer) {
	if (InSecondHalfOfRound())
	{
		if (g_bWitchEnabled == false) 
		{
			if (IsStaticWitchMap()) 
			{
				GetEmOuttaHea(FindWitchEntity());
			}
		}
	}
}


public void DisableWitch()
{
	CreateTimer(0.1, DisableWitchT);
	return;
}

public void EnableWitch()
{
	CreateTimer(0.1, EnableWitchT);
	return;
}

public Action:DisableWitchT(Handle:timer){	
	// If it's a static map move the witch out of bounds
	
	// Store the Flow before disabling - doing it here incase it's changed via !voteboss
	if (!IsDarkCarniRemix())
	{
		g_fWitchFlow = GetWitchFlow(0);
	}
	
	if (IsStaticWitchMap()) {
		int index;
		index = FindWitchEntity();
		
		if (index > -1)
		{
			GetEmOuttaHea(index);		
		}
		else
		{
			CPrintToChatAll("{green}<{blue}WitchVoter{green}>{default} Error: Witch Voting is not available on this map.");
			return Plugin_Handled;
		}
	}

	// Set Flow to 0
	L4D2Direct_SetVSWitchFlowPercent(0, 0.0);
	L4D2Direct_SetVSWitchFlowPercent(1, 0.0);

	// Set Witch to Spawn False
	L4D2Direct_SetVSWitchToSpawnThisRound(0, false);
	L4D2Direct_SetVSWitchToSpawnThisRound(1, false);
	
	// Set Witch Enabled to false
	g_bWitchEnabled = false;
	
	// Update Boss Percents
	SetWitchDisabled(1);
	UpdateBossPercents();
	
	return Plugin_Handled;
}

public Action:EnableWitchT(Handle:timer){
	// Set Witch Flow - If non-static
	if (!IsStaticWitchMap()){
	
		L4D2Direct_SetVSWitchFlowPercent(0, g_fWitchFlow);
		L4D2Direct_SetVSWitchFlowPercent(1, g_fWitchFlow);	
		
	} else {
		int index;
		index = FindWitchEntity();
		if (index > -1)
		{
			BringEmBackHea(FindWitchEntity(), EntityOrigin);	
		}
		else
		{
			CPrintToChatAll("{green}<{blue}WitchVoter{green}>{default} Error: Witch Voting is not available on this map.");
			return Plugin_Handled;
		}
	}
	
	// Enable Witch Spawning
	L4D2Direct_SetVSWitchToSpawnThisRound(0, true);
	L4D2Direct_SetVSWitchToSpawnThisRound(1, true);
	
	// Set Witch Enabled to true
	g_bWitchEnabled = true;
	
	// Update Boss Percents
	SetWitchDisabled(0);
	UpdateBossPercents();
	
	return Plugin_Handled;
}

// ========================================================
// ==================== Admin Commands ====================
// ========================================================

public Action:ForceWitchCommand(client, args){

	// Check if round is in second half
	if (!WitchVoteAllowed()) {
		CPrintToChat(client, "{green}<{blue}WitchVoter{green}>{default} The Witch Vote is not available on this map.");
		return Plugin_Handled;
	}

	// Check if round is live
	if (!IsInReady())  {
		CPrintToChat(client, "{green}<{blue}WitchVoter{green}>{default} The Witch can only be toggled during ready-up.");
		return Plugin_Handled;
	}
	
	// Check if round is in second half
	if (InSecondHalfOfRound()) {
		CPrintToChat(client, "{green}<{blue}WitchVoter{green}>{default} The Witch can only be toggled at the start of a map.");
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
		
	} else {
	
		// Enable Witch
		EnableWitch();
		
		// Print result to all
		CPrintToChatAll("{green}<{blue}WitchVoter{green}>{default} The Witch has been {green}enabled{default} by Admin {blue}%s{default}!", clientName);
		
	}
	return Plugin_Handled;
}
// ========================================================
// ==================== Entity Control 1 ==================
// ========================================================

public Action:L4D_OnSpawnWitch(const Float:vector[3], const Float:qangle[3])
{
	EntityOrigin = vector;
}

public Action:L4D_OnSpawnWitchBride(const Float:vector[3], const Float:qangle[3])
{
	EntityOrigin = vector;
}

// ========================================================
// ===================== Entity Control ===================
// ========================================================

public int FindWitchEntity() {
	while (iEnt = FindEntityByClassname(-1, "witch"))
    {
		if (!IsValidEntity(iEnt)) continue;

		return iEnt;
    }
	return -1;
}

// Move Witch Out Of Bounds -- Hacky, but works.
public GetEmOuttaHea(int ent){
	new Float:dest[3] = {-9999.0, -9999.0, -9999.0};
	TeleportEntity(ent, dest, NULL_VECTOR, NULL_VECTOR);
}

// Move Witch Back
public BringEmBackHea(int ent, Float:dest[3]){
	TeleportEntity(ent, dest, NULL_VECTOR, NULL_VECTOR);
}