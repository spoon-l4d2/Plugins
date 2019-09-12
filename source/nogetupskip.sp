#include <sourcemod>
#include <colors>

#define ARRAY_INDEX_NICK 0
#define ARRAY_INDEX_COACH 1
#define ARRAY_INDEX_ELLIS 2
#define ARRAY_INDEX_ROCHELLE 3
#define ARRAY_INDEX_FRANCIS 4
#define ARRAY_INDEX_LOUIS 5
#define ARRAY_INDEX_BILL 6
#define ARRAY_INDEX_ZOEY 7

#define ANIMATION_COUNT 7

new PlayerAnimations[8][ANIMATION_COUNT] = 
{
//		Wall Slam 	Ground Slam		Charger		Pounced		Tank Punch	Tank Rock	Tank Fly
	{	671, 		672, 			667,		620,		630,		627,		629	}, // Nick
	{	660, 		661, 			656,		621,		630,		627,		629	}, // Coach
	{	675, 		676, 			671,		625,		635,		632,		634	}, // Ellis
	{	678, 		679, 			674,		629,		638,		635,		637	}, // Rochelle
	{	766, 		767, 			762, 		531,		541,		538,		540	}, // Francis
	{	763, 		764, 			759,		528,		538,		535,		537	}, // Louis
	{	763, 		764, 			759,		528,		538,		535,		537	}, // Bill
	{	823, 		824, 			819,		537,		547,		544,		546	}  // Zoey
};

new Handle:cvar_fixEnabled = INVALID_HANDLE;

public Plugin:myinfo = 
{
	name = "[L4D2] No Get Up Skip",
	author = "Spoon",
	description = "Blocks players from switching teams during a get-up animation (which allows them to skip the animation.",
	version = "1",
	url = "https://github.com/spoon-l4d2"
};

public OnPluginStart()
{	
	AddCommandListener(Command_Listener, "jointeam");
	AddCommandListener(Command_Listener, "sm_s");
	AddCommandListener(Command_Listener, "sm_spec");
	AddCommandListener(Command_Listener, "sm_spectate");
	
	RegServerCmd("nogetupskip_add_command_listen", ServerCommand_AddListener); // Got another command used to handle player teams? You can add it with this command!
	
	cvar_fixEnabled = CreateConVar("nogetupskip_enabled", "1", "Enable the No Get Up Skip fix?");
}

public Action:ServerCommand_AddListener(args)
{
	decl String:commandName[128];
	GetCmdArg(1, commandName, sizeof(commandName));
	AddCommandListener(Command_Listener, commandName);
}

public Action:Command_Listener(client, const String:command[], argc)
{
	if (!GetConVarBool(cvar_fixEnabled)) return Plugin_Continue;

	if (CheckAnimations(client))
	{
		CPrintToChat(client, "{blue}[{default}Exploit{blue}]{default} You cannot change teams during a get up animation.");
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public bool:CheckAnimations(client)
{
	if (client < 1) return false;

	new arrayIndex = -1;
	decl String:survivorModel[PLATFORM_MAX_PATH];
	GetClientModel(client, survivorModel, sizeof(survivorModel));
	
	if(StrEqual(survivorModel, "models/survivors/survivor_coach.mdl", false))
	{
		arrayIndex = ARRAY_INDEX_COACH;
	}
	else if(StrEqual(survivorModel, "models/survivors/survivor_gambler.mdl", false))
	{
		arrayIndex = ARRAY_INDEX_NICK;
	}
	else if(StrEqual(survivorModel, "models/survivors/survivor_producer.mdl", false))
	{
		arrayIndex = ARRAY_INDEX_ROCHELLE;
	}
	else if(StrEqual(survivorModel, "models/survivors/survivor_mechanic.mdl", false))
	{
		arrayIndex = ARRAY_INDEX_ELLIS;
	}
	else if(StrEqual(survivorModel, "models/survivors/survivor_manager.mdl", false))
	{
		arrayIndex = ARRAY_INDEX_LOUIS;
	}
	else if(StrEqual(survivorModel, "models/survivors/survivor_teenangst.mdl", false))
	{
		arrayIndex = ARRAY_INDEX_ZOEY;
	}
	else if(StrEqual(survivorModel, "models/survivors/survivor_namvet.mdl", false))
	{
		arrayIndex = ARRAY_INDEX_BILL;
	}
	else if(StrEqual(survivorModel, "models/survivors/survivor_biker.mdl", false))
	{
		arrayIndex = ARRAY_INDEX_FRANCIS;
	}
	
	if (arrayIndex == -1) return false;
	
	for (new index = 0; index < ANIMATION_COUNT; index++)
	{
		new seq = GetEntProp(client, Prop_Send, "m_nSequence");
		if (PlayerAnimations[arrayIndex][index] == seq)
		{
			return true;
		}
	}
	
	return false;
}

stock bool:IsSurvivor(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}