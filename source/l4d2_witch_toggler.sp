#define L4D_TEAM_SPECTATE	1
#include <sourcemod>
#include <sdktools>
#include <l4d2_direct>
#include <left4downtown>
#include <builtinvotes>
#include <colors>
#include <l4d2util_rounds>
#include <bosspercent>
#include <readyup>

public Plugin:myinfo =
{
	name = "Witch Toggler",
	author = "Spoon",
	version = "0.1.2",
	description = "Allows players to vote on witch spawning at the start of a map."
};

new Handle:g_hVsBossBuffer;
new Handle:g_hWitchVoteE = INVALID_HANDLE;
new Handle:g_hWitchVoteD = INVALID_HANDLE;
new bool:w_enabled;
new Float:fWitchFlow;

public OnPluginStart()
{
	w_enabled = true;
	g_hVsBossBuffer = FindConVar("versus_boss_buffer");
	RegConsoleCmd("sm_votewitch", VoteWitchCommand);
	RegConsoleCmd("sm_witchvote", VoteWitchCommand);
	HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
}

public RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	w_enabled = true;
	L4D2Direct_SetVSWitchToSpawnThisRound(0, true);
	L4D2Direct_SetVSWitchToSpawnThisRound(1, true);
}
 
public void OnClientPutInServer(int client)
{
	CreateTimer(5.0, WitchCMDMessage, GetClientSerial(client));
}

public Action:WitchCMDMessage(Handle timer, any serial)
{
	int client = GetClientFromSerial(serial);
	if (client == 0)
	{
		return Plugin_Stop;
	}
	if (!InSecondHalfOfRound() && IsInReady()){
		CPrintToChat(client, "{green}<{blue}WitchVoter{green}>{default} You can use {green}`!witchvote`{default} to call a vote to toggle on/off the Witch!");
	}
	return Plugin_Handled;	
}

stock Float:GetWitchFlow(round)
{
	return L4D2Direct_GetVSWitchFlowPercent(round) - Float:GetConVarInt(g_hVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance();
}

// ==========================================
// |	Witch Voting Stuff Down hea 		|
// ==========================================


public Action:VoteWitchCommand(client, args){

	if (!client) return Plugin_Handled;
	if (InSecondHalfOfRound()) {
		CPrintToChat(client, "{green}<{blue}WitchVoter{green}>{default} The Witch Vote can only be called at the start of a map.");
		return Plugin_Handled;
	}

	if (!IsInReady())  {
		CPrintToChat(client, "{green}<{blue}WitchVoter{green}>{default} The Witch Vote can only be called during ready-up.");
		return Plugin_Handled;
	}
	
	if (StartWitchVote(client))
	{
		FakeClientCommand(client, "Vote Yes");
	}
	return Plugin_Handled;
}

bool:StartWitchVote(client)
{
	if (GetClientTeam(client) == L4D_TEAM_SPECTATE)
	{
		CPrintToChat(client, "{green}<{blue}WitchVoter{green}>{default} Witch voting isn't allowed for spectators.");
		return false;
	}
	
	if (canVote == false){
		CPrintToChat(client, "{green}<{blue}WitchVoter{green}>{default} Witch Voting is currently on cooldown. Please wait...");
		return false;
	}
	
	if (!IsBuiltinVoteInProgress() && IsNewBuiltinVoteAllowed())
	{
		new iNumPlayers;
		decl iPlayers[MaxClients];
		for (new i=1; i<=MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) == L4D_TEAM_SPECTATE))
			{
				continue;
			}
			iPlayers[iNumPlayers++] = i;
		}
		new String:sBuffer[64];
		
		if (w_enabled == false) {
			g_hWitchVoteE = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);	
			Format(sBuffer, sizeof(sBuffer), "Enable the Witch");
			SetBuiltinVoteArgument(g_hWitchVoteE, sBuffer);
			SetBuiltinVoteInitiator(g_hWitchVoteE, client);
			SetBuiltinVoteResultCallback(g_hWitchVoteE, VoteResultHandler);
			DisplayBuiltinVote(g_hWitchVoteE, iPlayers, iNumPlayers, 20);		
		} else {
			fWitchFlow = GetWitchFlow(1);
			g_hWitchVoteD = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);	
			Format(sBuffer, sizeof(sBuffer), "Disable the Witch");
			SetBuiltinVoteArgument(g_hWitchVoteD, sBuffer);
			SetBuiltinVoteInitiator(g_hWitchVoteD, client);
			SetBuiltinVoteResultCallback(g_hWitchVoteD, VoteResultHandler);
			DisplayBuiltinVote(g_hWitchVoteD, iPlayers, iNumPlayers, 20);				
		}		
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
			g_hWitchVoteD = INVALID_HANDLE;
			g_hWitchVoteE = INVALID_HANDLE;
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
				// One Last Check
				if (!IsInReady())  {
					DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
					CPrintToChatAll("{green}<{blue}WitchVoter{green}>{default} The Witch Vote can only be called during ready-up.");
					return;
				}
				if (vote == g_hWitchVoteE)
				{
					DisplayBuiltinVotePass(vote, "Enabling the Witch...");
					L4D2Direct_SetVSWitchFlowPercent(0, fWitchFlow);
					L4D2Direct_SetVSWitchFlowPercent(1, fWitchFlow);
					L4D2Direct_SetVSWitchToSpawnThisRound(0, true);
					L4D2Direct_SetVSWitchToSpawnThisRound(1, true);
					CPrintToChatAll("{green}<{blue}WitchVoter{green}>{default} The Witch has been {green}enabled{default}!");
					w_enabled = true;
					UpdateBossPercents();
					return;
				} else {
					DisplayBuiltinVotePass(vote, "Disabling the Witch...");
					L4D2Direct_SetVSWitchFlowPercent(0, 0.0);
					L4D2Direct_SetVSWitchFlowPercent(1, 0.0);
					L4D2Direct_SetVSWitchToSpawnThisRound(0, false);
					L4D2Direct_SetVSWitchToSpawnThisRound(1, false);
					CPrintToChatAll("{green}<{blue}WitchVoter{green}>{default} The Witch has been {green}disabled{default}!");
					w_enabled = false;
					UpdateBossPercents();					
					return;
				}
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return;
}