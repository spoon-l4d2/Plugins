/***
 *      __  __  __   _  _                      _____     
 *     | _|/  \|_ | | || | ___ __ __ __  ___  |_   _|___ 
 *     | || () || | | __ |/ _ \\ V  V / |___|   | | / _ \
 *     | | \__/ | | |_||_|\___/ \_/\_/          |_| \___/
 *     |__|    |__|                                      
 *
 =====================================================================================================================
 
 Melee Spawn Rules allows you to create various rules that will determine/alter melee spawns on all maps. It also allows 
 you to unlock any melees to be used on all maps, or even make use of the new melee weapon skins.

 There are 6 different types of rules you can add:

 	Unlock 			("unlock")
 		The unlock rule will allow the specified melee to spawn on any map. Doesn't contain second arguement.

 	filter 			("filter")
 		You can use the filter rule to block melees from spawning entirely. Doesn't contain second arguement.

 	Limit 			("limit" "x")
 		The limit rule will limit a melee to a specified amount of spawns. Once it reaches the limit, no more will spawn.

  	Limit Group 	("limitgroup" "x")
 		The limit group rule limits multiple melees as a group. Once the limit is reached, none of the melees will be able to spawn.

 	Force 			("force" "x")
 		The force rule will force a melee to spawn a specified amount of times. You should always find this melee on every map!

 	Force Random 	("forcerandom" "x")
 		The force random rule will force a random melee from the melees specified to spawn. It will do however many times specified in the first parameter.


  About Adding Rules:

  	To add a rule you can use the following server command:

  		' melee_spawn_rules_add '

  	For 'Filter' and 'Unlock' rules, the arguements should always be set up as follows:
		
		melee_spawn_rules_add 	"rule type" 	"melee1" "melee2" "melee3" "..."

	For ALL other rules, the arguements should always be set up as follows:
		
		melee_spawn_rules_add 	"rule type" 	"limit/amount"	"melee1" "melee2" "melee3" "..."

	If a melee has multiple rules applied to it, what rule is followed is completely chronological. 
	Meaning you can techincally 'override' your own rules (with the exception of Unlock rules.)


  Important Notes:

  	A melee MUST be unlocked in order to be spawned. This is a game limitation, if you do not unlock the melee before spawning it it will spawn in as 
  	hunter arms instead, and bug out. While funny, it isn't really too practical. I've gone ahead and put precautions in place to prevent melees from spawning
  	if they are not unlocked. But as a general rule, make sure you unlock any melees you want to spawn I guess.


  Convars:

 	[BoolInt] 	'melee_spawn_rules_auto_unlock'			[Default = 1] [Options: 0 = Disabled, 1 = Enabled]
 		If set to true (1), any melee that has a rule applied to it will be automatically unlocked on all maps. This is to avoid hunter arms from spawning mostly, but also for QOL.

 	[Int] 		'melee_spawn_rules_saferoom_mode' 		[Default = 0] [Options: 0 = Normal, 1 = Delete, 2 = Ignore]
 		This determines how melees inside of either both the end, or starting saferoom will be processed.

 	[BoolInt] 	'melee_spawn_rules_invalid_delete' 		[Default = 1] [Options: 0 = Disabled, 1 = Enabled]
 		If set to true, if there are no available spawns, any remaining melee spawns will be removed. If set to false, remaining spawns will be allowed to spawn.

 	[BoolInt] 	'melee_spawn_rules_replaceables_first' 	[Default = 0] [Options: 0 = Disabled, 1 = Enabled]
 		If set to true, when enforcing 'force' or 'forcerandom' rules, melee spawns that don't follow rules and are marked to be replaced will be used up first. If set to false, it will be random. 

 	[BoolInt] 	'melee_spawn_rules_override_all' 		[Default = 0] [Options: 0 = Disabled, 1 = Enabled]
 		If set to true, ALL melee spawns will be handled by the plugin. This can allow for a wider range of melees throughout the map. 
 		However, it can also get rid of 'static' melee spawns. An example of which would be Swamp Fever map 2, and the fireaxe stuck inside of the tree directly outside of saferoom.

 	[Int] 	'melee_spawn_rules_find_mode' 				[Default = 0] [Options: 0 = Random, 1 = Least Popular]
 		This will determine in what order valid melee spawns are saught after in. Random will be... random. And least popular will find the least popular-valid melee spawn on the map. This however 
 		can also result in somewhat 'static' spawns depending on your rules.

 	[Float] 'melee_crowbar_skin_chance'					[Default = 0]
 		%Chance of how likely the crowbar is to use it's alternative golden skin.

 	[Float] 'melee_cricket_bat_skin_chance'				[Default = 0]
 		%Chance of how likely the cricket bat is to use it's alternative green skin.


  PS:
 	The hundreds of lines of comments really help my chimp brain code, please don't make fun of me. 
 	Also the compiled version has no comments if that makes you feel slightly better?
*/


#pragma newdecls required 
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <dhooks>
#include <l4d2_saferoom_detect>

#define Max_Entities 	2048
#define Maximum_Rules	256
#define Melee_Count 	13
#define Flag_Count		Melee_Count + 3

// ======= Globals : Rule Types ========================================================================================
// 	RuleTypes_Count 			| Stores the amount of rule types.
//	MeleeSpawnRuleType			| Int enum. Used to determine what kind of rule a rule is.
//	RuleTypeStringArray 		| Indexes corrispond with type. Needed to convert arguement into rule type.
// =====================================================================================================================
#define RuleTypes_Count 6
enum MeleeSpawnRuleType 
{
	RuleType_Unlock = 0,
	RuleType_Filter,
	RuleType_LimitGroup,
	RuleType_Limit,
	RuleType_ForceRandom,
	RuleType_Force,
	RuleType_None
};
char RuleTypeStringArray[RuleTypes_Count][]= 
{
	"unlock",
	"filter",
	"limitgroup",
	"limit",
	"forcerandom",
	"force",
};

// ======= Globals : Melees ============================================================================================
// 	MeleeFlagIntArray 		| Used to store our flags, which well let us know what melees a rule effects.
//	MeleeNameArray 			| Indexes allign with the previous array.
// =====================================================================================================================
int MeleeFlagIntArray[Flag_Count] = { 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 5482, 2709, 8191 };
char MeleeNameArray[Flag_Count][32] = 
{
/* [0] */	"fireaxe",				// 1,		"fireaxe"
/* [1] */	"frying_pan",			// 2,		"frying_pan"
/* [2] */	"machete",				// 4,		"machete"
/* [3] */	"baseball_bat",			// 8,		"bat"
/* [4] */	"crowbar",				// 16,		"crowbar"
/* [5] */	"cricket_bat",			// 32,		"cricket_bat"
/* [6] */	"tonfa",				// 64,		"tonfa"
/* [7] */	"katana",				// 128,		"katana"
/* [8] */	"electric_guitar",		// 256,		"electric_guitar"
/* [9] */	"knife",				// 512,		"knife"
/* [10] */	"golfclub",				// 1024,	"golfclub"
/* [11] */	"pitchfork",			// 2048,	"pitchfork"
/* [12] */	"shovel",				// 4096, 	"shovel"
/* [13] */	"all_blunt",			// 5480, 	"all_blunt", 	"all blunt"
/* [14] */	"all_sharp",			// 2709, 	"all_sharp", 	"all sharp"
/* [15] */	"all_melees"			// 8191, 	"all_melees", 	"all"
};

// ======= Type : MeleeSpawnRule =======================================================================================
// 	(int)Flags 						| Melee flags. Used to know what melees are effected by the rule.
//	(RuleType)Type					| Stores the type of rule.
//	(int)Limit						| Stores the limit of the rule.
//	(int)Count						| Stores the current amount of melee spawns for the rule.
//	(int)AvailableSpawns()			| Returns how many spawns are available for the rule.
//	(bool)CanSpawn()				| Returns true if the rule has any available spawns.
//	(bool)ContainsMelee(Melee)		| Returns a bool if the rule contains the specified melee weapon.
// =====================================================================================================================
enum struct MeleeSpawnRule 
{
	int Flags;
	MeleeSpawnRuleType Type;
	int	Limit;
	int	Count;
	int AvailableSpawns() 
	{
		if ( this.Limit - this.Count < 0 ) return 0;
		return ( this.Limit - this.Count );
	}
	bool CanSpawn() 
	{
		if ( this.Type == RuleType_Filter ) return false;
		if ( this.Type == RuleType_Unlock ) return true;
		return (this.AvailableSpawns() > 0);
	}
	bool ContainsMelee(int Melee)
	{
		return view_as<bool>( this.Flags & MeleeFlagIntArray[Melee] );
	}
}

// ======= Type : GameInformation ======================================================================================
// 	(int)RuleCount		  		  | Stores the amount of succesfully added rules.
//	(int)MeleeSpawnsCount	  	  | Stores the amount of registered melee spawns on the current map.
// =====================================================================================================================
enum struct GameInfo
{
	int	RuleCount;
	int MeleeSpawnsCount;
}

// ======= Type : GameInformation ======================================================================================
// 	(int)RuleCount		   | Stores the amount of succesfully added rules.
//	(int)ChangeCount	   | Stores the amount of saved spawn changes.
// =====================================================================================================================
enum struct MeleeInfo
{
	int ForcedSpawnsRequired;
	int SpawnCount;
}

// ======= Type : MeleeSpawn ============================================================================================
// 	(int)EntityRef			  | Stores the entity reference of the found melee.
// 	(int)Melee			  	  | Stores the Melee Index of the entity.
// 	(int)Skin			  	  | Stores the Weapon Skin of the entity.
// 	(bool)HasPhysics		  | Stores if the entity uses physics or not.
// 	(vector)Origin			  | Stores the spawn location of the entity.
// 	(vector)Angles			  | Stores the spawn angles of the entity.
// 	(enum)ProcessAction 	  | Stores what action we should do to this melee spawn.
// =====================================================================================================================
ConVar CvarCrowbarSkinChance, CvarCricketSkinChance;
enum struct MeleeSpawn
{
	int Index;
	int EntityRef;
	int Melee;
	int Skin;
	bool HasPhysics;
	float SpawnOrigins[3];
	float SpawnAngles[3];
	MeleeProcessAction ProcessAction;
}

enum MeleeProcessAction
{
	ProcessAction_None = 0,
	ProcessAction_Keep,
	ProcessAction_Replace,
	ProcessAction_Spawn
};
enum SaferoomProcessActions
{
	SaferoomMelee_Normal = 0,
	SaferoomMelee_Delete,
	SaferoomMelee_Ignore
};
enum FindMeleeSearchMode
{
	SearchMode_Random = 0,
	SearchMode_Popularity
};



/***
 *      __  _  __    ___  _               _         _   _       
 *     | _|/ ||_ |  / __|| |_  __ _  _ _ | |_  ___ | | | | _ __ 
 *     | | | | | |  \__ \|  _|/ _` || '_||  _||___|| |_| || '_ \
 *     | | |_| | |  |___/ \__|\__,_||_|   \__|      \___/ | .__/
 *     |__|   |__|                                        |_|   
 */
 // =====================================================================================================================
 	public Plugin myinfo =
	{
		name 		= 		"[L4D2] Melee Spawn Rules",
		description = 		"Create rules to have more control over which melees will spawn. Create melee limits, make use of new skins, forced spawns, unlocks, or removals!",
		author 		= 		"Plugin: spoon. | Signatures Found By: Silvers",
		version 	= 		"4.2.0",
		url 		= 		"https://github.com/spoon-l4d2"
	};
	
	MeleeSpawnRule			ActiveMeleeSpawnRules[Maximum_Rules];
	MeleeSpawn 				AllMeleeSpawns[Max_Entities];
	GameInfo				GameInformation;
	MeleeInfo				MeleeInformation[Melee_Count];
	ConVar 					CvarDeleteOnNoSpawns, CvarSaferoomMode, CvarAutoUnlock, CvarUseReplaceablesFirst, CvarFindMode, CvarOverrideAll;
	Handle					SetStringHandle, GetStringHandle, DuplicateEntryBlockTrie;
	
	public void OnPluginStart()
	{
		// [Step 1] Hook our game Events.
			HookEvent("round_start", OnRoundStartEvent, EventHookMode_PostNoCopy);
		
		// [Step 2] Create console variables :B
			CvarAutoUnlock				=		CreateConVar("melee_spawn_rules_auto_unlock",			"1", 		"[Bool] If true (recommended), any melees with rules applied to them will be automatically unlocked on all maps.");
			CvarSaferoomMode			=		CreateConVar("melee_spawn_rules_saferoom_mode",			"0", 		"[Int] Determines how melees in both saferooms will be processed. 0 = Normal, 1 = Delete, 2 = Ignore");
			
			CvarDeleteOnNoSpawns 		= 		CreateConVar("melee_spawn_rules_invalid_delete", 		"1", 		"[Bool] Delete entities if there are no available spawns left. If this is set to false, the melee will spawn with whatever the game decides, against rules or not.");
			CvarUseReplaceablesFirst	=		CreateConVar("melee_spawn_rules_replaceables_first",	"0", 		"[Bool] Use up replaceable melee spawns (melees that aren't allowed to spawn) first while enforcing forced spawns.");
			CvarOverrideAll				=		CreateConVar("melee_spawn_rules_override_all",			"0", 		"[Bool] If true, the plugin will handle all melee spawns. This can create more random spawns (if mode is set to 1), but will get rid of 'static' map spawns.");
			CvarFindMode				=		CreateConVar("melee_spawn_rules_find_mode",				"0", 		"[Int] Determines in what order melees will be selected in. 0 = Random | 1 = Least Popular (Can create somewhat static spawns depending on your rules)");
			
			CvarCrowbarSkinChance		=		CreateConVar("melee_crowbar_skin_chance",				"0.0", 		"[Float] There will be a this% chance that the crowbar will use its alternative The Last Stand skin.");
			CvarCricketSkinChance		=		CreateConVar("melee_cricket_bat_skin_chance",			"0.0", 		"[Float] There will be a this% chance that the cricket bat will use its alternative The Last Stand skin.");
			
		// [Step 3] Create our server commands.
			RegServerCmd("melee_spawn_rules_add", AddMeleeSpawnRuleCommand, "Please read comment above for usage information.");
		
		// [Step 4] Create our anti-duplicate server command entry trie.
			DuplicateEntryBlockTrie = CreateTrie();
				
		// [Step 5] Now it is time to load up our signatures from arrr config file, so we can enable all melee types :)
			Handle Gamedata = LoadGameConfigFile("l4d2_melee_spawn_rules");
			if ( Gamedata == null ) SetFailState("[Melee Spawn Rules] Failed to load required gamedata from 'l4d2_melee_spawn_rules.txt'.. Pls fix.");
			
		// [Step 6] COOL! Now lets try to get our KeyValues::GetString :o
			StartPrepSDKCall(SDKCall_Raw);
			if ( PrepSDKCall_SetFromConf(Gamedata, SDKConf_Signature, "KeyValues::GetString") == false ) SetFailState("[Melee Spawn Rules] Failed to load required 'KeyValues::GetString' from 'l4d2_melee_spawn_rules.txt'.. Pls fix.");
			PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
			PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
			PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
			GetStringHandle = EndPrepSDKCall();
			if ( GetStringHandle == null ) SetFailState("[Melee Spawn Rules] Failed to load required 'KeyValues::GetString' from 'l4d2_melee_spawn_rules.txt'.. Pls fix.");
			
		// [Step 7] COOL! Now lets try to get our KeyValues::SetString :o
			StartPrepSDKCall(SDKCall_Raw);
			if ( PrepSDKCall_SetFromConf(Gamedata, SDKConf_Signature, "KeyValues::SetString") == false ) SetFailState("[Melee Spawn Rules] Failed to load required 'KeyValues::SetString' from 'l4d2_melee_spawn_rules.txt'.. Pls fix.");
			PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
			PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
			SetStringHandle = EndPrepSDKCall();
			if ( SetStringHandle == null ) SetFailState("[Melee Spawn Rules] Failed to load required 'KeyValues::SetString' from 'l4d2_melee_spawn_rules.txt'.. Pls fix.");
			
		// [Step 8] Now les' detour our OnGetMissionInfo :)
			Handle OnGetMissionInfoHook = DHookCreateFromConf(Gamedata, "CTerrorGameRules::GetMissionInfo");
			if ( !OnGetMissionInfoHook ) SetFailState("[Melee Spawn Rules] Failed to load required 'CTerrorGameRules::GetMissionInfo' from 'l4d2_melee_spawn_rules.txt'.. Pls fix.");
			if ( !DHookEnableDetour(OnGetMissionInfoHook, true, OnGetMissionInfo) ) SetFailState("[Melee Spawn Rules] Failed to detour required 'CTerrorGameRules::GetMissionInfo'.. no beuno. me exit.");
			delete OnGetMissionInfoHook;
	}

/***
 *      __  ___  __     ___                                    _     
 *     | _||_  )|_ |   / __| ___  _ __   _ __   __ _  _ _   __| | ___
 *     | |  / /  | |  | (__ / _ \| '  \ | '  \ / _` || ' \ / _` |(_-<
 *     | | /___| | |   \___|\___/|_|_|_||_|_|_|\__,_||_||_|\__,_|/__/
 *     |__|     |__|                                                 
 */
// ======= ServerCommand : AddMeleeSpawnRuleCommand ====================================================================
// 		Creates and saves a new melee spawn rule based on the user's inputted arguements, and rule type.
// =====================================================================================================================
	public Action AddMeleeSpawnRuleCommand(int args)
	{
		// [Step 1] Lets make sure the arguements are set up right. And that we're not already at our rule limit.
			if ( args < 2 || GameInformation.RuleCount >= Maximum_Rules ) return Plugin_Continue;
		
		// [Step 2] Grab every command arguement as a string.
			char CommandArgString[256];
			GetCmdArgString(CommandArgString, sizeof(CommandArgString));
		
		// [Step 3] Lets check/save if a command with these exact arguements has already been used.
			bool TrieReturnResult;
			if ( GetTrieValue(DuplicateEntryBlockTrie, CommandArgString, TrieReturnResult ) ) return Plugin_Continue;
			else SetTrieValue(DuplicateEntryBlockTrie, CommandArgString, true);
		
		// [Step 4] Oh alright sick.. Now lets check what type of rule we're suppose to be adding.
			char RuleTypeString[32];
			GetCmdArg(1, RuleTypeString, sizeof(RuleTypeString));
			MeleeSpawnRuleType RuleType = GetFilterTypeFromString(RuleTypeString);
		
		// [Step 5] Do we have a valid rule type to work with here?
			if (RuleType == RuleType_None) return Plugin_Continue;
		
		// [Step 6] Lets create a new rule base.
			MeleeSpawnRule 	  NewMeleeRule;
			NewMeleeRule.Type = RuleType;
			
		// [Step 7] If our rule is a filter/unlock, it skips an arguement, so lets check if we need to change the arguement index. (While we're at it, lets also get the rule limit.)
			int ArgStartIndex = 1;
			if ( RuleType != RuleType_Filter && RuleType != RuleType_Unlock ) 
			{
				// [Step 8] Get the limit arguement as an integer.
					char RuleLimitString[32];
					GetCmdArg(2, RuleLimitString, sizeof(RuleLimitString));			
					NewMeleeRule.Limit = StringToInt(RuleLimitString);
				
				// [Step 9] If our limit is set up wrong, lets cancel adding the rule all together.
					if ( NewMeleeRule.Limit <= -1 ) return Plugin_Continue;
				
				// [Step 10] Increase the argument start index (because filters skip an arguement).
					ArgStartIndex = 2;
			}
	
		// [Step 11] Now we have to loop through all the remaining arguements, which should be melee weapon names.
			for ( int ArgIndex = ArgStartIndex; ArgIndex <= args; ArgIndex++ )
			{
				// [Step 12] First thing we need to do here, is get our arguement as a string.
					char ArguementString[32];
					GetCmdArg(ArgIndex, ArguementString, sizeof(ArguementString));
					
				// [Step 13] Now, lets see if we can get a melee from it. Lets not give it the boot if it's not valid just yet though.
					int Melee = GetMeleeWeaponIndexFromString(ArguementString);
					if ( !IsMeleeIndexValid(Melee) ) continue;
					
				// [Step 14] Cool it's valid, lets add our new melee(s) to the rules flags!
					NewMeleeRule.Flags |= MeleeFlagIntArray[Melee];
					
				// [Step 15] If the rule type is a limit, we want to add each melee seperately. So, lets add the rule right here.
					if ( RuleType == RuleType_Limit )
					{
						// [Step 16] Only add the rule if it has valid flags and we still have room.
							if ( GameInformation.RuleCount >= Maximum_Rules || NewMeleeRule.Flags <= -1 ) continue;
							ActiveMeleeSpawnRules[GameInformation.RuleCount++] = NewMeleeRule;
							NewMeleeRule.Flags = 0;
					}
			}
		
		// [Step 17] Did we suck seed at getting any flags?
			if ( NewMeleeRule.Flags <= -1 ) return Plugin_Continue;
		
		// [Step 18] We would have already done this if it were a limit rule. But if it's not, than lets add the rule!
			if ( RuleType != RuleType_Limit ) ActiveMeleeSpawnRules[GameInformation.RuleCount++] = NewMeleeRule;	
			return Plugin_Continue;
	}

/***
 *      __  ____ __     ___                     ___                 _       
 *     | _||__ /|_ |   / __| __ _  _ __   ___  | __|__ __ ___  _ _ | |_  ___
 *     | |  |_ \ | |  | (_ |/ _` || '  \ / -_) | _| \ V // -_)| ' \|  _|(_-<
 *     | | |___/ | |   \___|\__,_||_|_|_|\___| |___| \_/ \___||_||_|\__|/__/
 *     |__|     |__|                                                        
 */
// ======= Event : OnMapStart ==========================================================================================
// 		Here we'll reset all our saved stuff and precache files.
//		Fires: On map start.... You srs..?
// =====================================================================================================================
	public void OnMapStart() 
	{
		// [Derp 1] Gotta clear out any old info!
			ResetGameInfo(); 			 // Quack
	}

// ======= Event : OnConfigsExecuted ===================================================================================
// 		This is when we need to process our melee spawns. Have to do this here not on MapStart()
//		Fires: After OnMapStart() - (when we can spawn entities!)
// =====================================================================================================================
	public void OnConfigsExecuted()
	{
		// [Step 1] Lets loop through all of our entities to find our melee spawns..
			for ( int entity = MaxClients; entity < Max_Entities; entity++ )
			{
				// [Step 2] Always remember to validate them entities.
					if ( !IsValidEntity(entity) ) continue;
				
				// [Step 3] Lets grab the entities classname.. Yknow, so we can make sure its a melee.
					char classname[128];
					GetEntityClassname(entity, classname, sizeof(classname));
				
				// [Step 4] Check if it's a melee, and fire MeleeEntitySpawned() if it is!
					if ( StrEqual(classname, "weapon_melee_spawn", false) || StrEqual(classname, "weapon_item_spawn", false) || StrEqual(classname, "weapon_melee", false) ) 
					{
						if ( !IsMeleeIndexValid(GetMeleeWeaponFromEntity(entity)) ) continue;
						if ( IsInSaferoom(entity) )
						{
							if ( CvarSaferoomMode.IntValue == view_as<int>(SaferoomMelee_Delete) ) AcceptEntityInput(entity, "Kill");
							else if ( CvarSaferoomMode.IntValue == view_as<int>(SaferoomMelee_Ignore) ) continue;
							else MeleeEntitySpawned(entity);
						}
						else 
						{
							MeleeEntitySpawned(entity);
						}
					}
			}

			// [Step 5] If we succesfully update the spawns than lets remove our old melee spawns and replace them with our newly updated ones!
			if ( UpdateAllMeleeSpawns() ) 
			{				
				// [Step 6] Remove our old ones... :(
					for ( int MeleeSpawnIndex = 0; MeleeSpawnIndex < GameInformation.MeleeSpawnsCount; MeleeSpawnIndex++ )
					{
						if ( IsValidEntity(AllMeleeSpawns[MeleeSpawnIndex].EntityRef) ) AcceptEntityInput(AllMeleeSpawns[MeleeSpawnIndex].EntityRef, "Kill");
					}

				// [Step 7] Spawn in our new ones! :)
					for ( int MeleeSpawnIndex = 0; MeleeSpawnIndex < GameInformation.MeleeSpawnsCount; MeleeSpawnIndex++ )
					{
						if ( AllMeleeSpawns[MeleeSpawnIndex].ProcessAction == ProcessAction_Spawn )
						{
							if ( !IsMeleeIndexValid(AllMeleeSpawns[MeleeSpawnIndex].Melee) || !IsMeleeAllowedOnMap(AllMeleeSpawns[MeleeSpawnIndex].Melee) ) continue;
							SpawnMelee(AllMeleeSpawns[MeleeSpawnIndex]);
						}
					}
			}

	}

// ======= Event : OnRoundStartEvent ===================================================================================
// 		This is where we need to load our changes for round 2 :)
//		Fires: On round start for both rounds (We only care about the second tho.)
// =====================================================================================================================
	public Action OnRoundStartEvent(Event event, const char[] name, bool dontBroadcast)
	{		
		// [Step 1] Are we even suppose to be here?
			if ( !InSecondRound() ) return Plugin_Continue;
		
		// [Step 2] Lets loop through all of our entities to find our melee spawns..
			for ( int entity = MaxClients; entity < Max_Entities; entity++ )
			{
				// [Step 3] Always remember to ealidate your vntities.
					if ( !IsValidEntity(entity) || !IsMeleeIndexValid(GetMeleeWeaponFromEntity(entity)) ) continue;
				
				// [Step 4] Lets grab the entities classname.. Yknow, so we can make sure its a melee.
					char classname[128];
					GetEntityClassname(entity, classname, sizeof(classname));
				
				// [Step 5] If our entity is a melee GIVE EM THE BOOT!
					if ( StrEqual(classname, "weapon_melee_spawn", false) || StrEqual(classname, "weapon_item_spawn", false) || StrEqual(classname, "weapon_melee", false) ) AcceptEntityInput(entity, "Kill");
			}

		// [Step 6] Spawn all our saved melees in.
			for ( int MeleeSpawnIndex = 0; MeleeSpawnIndex < GameInformation.MeleeSpawnsCount; MeleeSpawnIndex++ )
			{
				if ( AllMeleeSpawns[MeleeSpawnIndex].ProcessAction == ProcessAction_Spawn )
				{
					if ( !IsMeleeIndexValid(AllMeleeSpawns[MeleeSpawnIndex].Melee) || !IsMeleeAllowedOnMap(AllMeleeSpawns[MeleeSpawnIndex].Melee) ) continue;
					SpawnMelee(AllMeleeSpawns[MeleeSpawnIndex]);
				}
			}
			return Plugin_Continue;
	}
	
// ======= Event : MeleeEntitySpawned ==================================================================================
//		Here we will decide what we need to do with the melee. Replace him? Or spare?
// 		Fires: Upon the spawning of a 'weapon_melee_spawn', 'weapon_melee', or 'weapon_item_spawn' for both rounds.
// =====================================================================================================================
	public Action MeleeEntitySpawned(int entity)
	{
		// [Step 1] Is our entity valid?
			if ( !IsValidEntity(entity) ) return Plugin_Continue;
		
		// [Step 2] Alright sure it's valid.. But is it an actual melee?..
			int Melee = GetMeleeWeaponFromEntity(entity);
			if ( !IsMeleeIndexValid(Melee) ) return Plugin_Continue;
	
		// [Step 3] Alrighty he's clear. Lets check if we're in the first round. So we can process our melee spawn.
			if ( !InSecondRound() )
			{
				// [Step 4] Ohkay. Now if our melee is allowed to spawn, lets mark it as valid, if not lets mark it as replaceable!
					if ( IsMeleeAllowedToSpawn(Melee) && !CvarOverrideAll.BoolValue) 
					{
						MeleeSpawn NewSpawn;
						if ( ConvertEntityToMeleeSpawn(entity, NewSpawn) )
						{
							NewSpawn.ProcessAction = ProcessAction_Keep;	
							NewSpawn.Skin = GetRandomSkin(Melee);
							IncreaseMeleeCountForAllRules(Melee);
							RegisterMeleeSpawn(NewSpawn);
						}
					}
					else 
					{
						MeleeSpawn NewSpawn;
						if ( ConvertEntityToMeleeSpawn(entity, NewSpawn) )
						{
							NewSpawn.ProcessAction = ProcessAction_Replace;	
							RegisterMeleeSpawn(NewSpawn);
						}
					}
			}
			return Plugin_Continue;
	}
	
// ======= Event : OnGetMissionInfo ====================================================================================
// 		This is where we'll enable all melee weapons.
//		Fires: When the mission info is got. lol.
// =====================================================================================================================
	public MRESReturn OnGetMissionInfo(Handle ReturnHandle, Handle ParamsHandle)
	{			
		// [Step 1] Precautionary return value check -- Just on the off chance that a mission file isn't loaded properly.
			int ReturnValue = DHookGetReturn(ReturnHandle);
			if ( ReturnValue == 0 ) return MRES_Ignored;
		
		// [Step 2] Ight. Lets get all available melee spawns on the current map.
			char MapMeleeWeaponsString[PLATFORM_MAX_PATH], NewMeleeWeaponsString[PLATFORM_MAX_PATH];
			SDKCall(GetStringHandle, ReturnValue, MapMeleeWeaponsString, sizeof(MapMeleeWeaponsString), "meleeweapons", "");
			
		// [Step 3] Now we gotta loop through all melees and see if they should be unlocked.
			for ( int Melee = 0; Melee < Melee_Count; Melee++ )
			{			
				// [Step 4] Is our melee already allowed on this map?
					if ( StrContains(MapMeleeWeaponsString, MeleeNameArray[Melee], false) >= 0 ) 
					{
						char AppendString[32];
						Format(AppendString, sizeof(AppendString), ";%s", MeleeNameArray[Melee]);
						StrCat(NewMeleeWeaponsString, sizeof(NewMeleeWeaponsString), AppendString);
						continue;
					}
					
				// [Step 5] Get any active rules that effect the current melee.
					for ( int RuleIndex = 0; RuleIndex < GameInformation.RuleCount; RuleIndex++ )
					{	
						// [Step 6] We only care about unlocks. Unless that is, the user has specified that they want us to auto-unlock 2000 supreme the melee for them.
							if ( ActiveMeleeSpawnRules[RuleIndex].Type == RuleType_Unlock || CvarAutoUnlock.BoolValue  ) 
							{
								if ( ActiveMeleeSpawnRules[RuleIndex].ContainsMelee(Melee) )
								{
									char AppendString[32];
									Format(AppendString, sizeof(AppendString), ";%s", MeleeNameArray[Melee]);
									StrCat(NewMeleeWeaponsString, sizeof(NewMeleeWeaponsString), AppendString);
									break;
								}
							}
					}
			}
						
		// [Step 7] Now lets add all of our melees to the meleeweapons stwing uwu..	
			SDKCall(SetStringHandle, ReturnValue, "meleeweapons", NewMeleeWeaponsString);
			return MRES_Ignored;
	}
	
/***
 *      __  _ _  __    ___                 _    _                
 *     | _|| | ||_ |  | __|_  _  _ _   __ | |_ (_) ___  _ _   ___
 *     | | |_  _|| |  | _|| || || ' \ / _||  _|| |/ _ \| ' \ (_-<
 *     | |   |_| | |  |_|  \_,_||_||_|\__| \__||_|\___/|_||_|/__/
 *     |__|     |__|                                             
 */
// ======= Function : UpdateAllMeleeSpawns =============================================================================
//		Updates all locally stored melee spawns to follow the rules. This will change melees, and skins.
//		@return		(Bool) 	True if successful, False if second round is in progress.
// =====================================================================================================================
	public bool UpdateAllMeleeSpawns()
	{
					
		// [Step 1] Make sure we're in the first round.
			if ( InSecondRound() ) return false;

		// [Step 2] Now, lets loop through all the rules, and set the ForcedSpawnsRequired for each melee.
			for ( int RuleIndex = 0; RuleIndex < GameInformation.RuleCount; RuleIndex++ )
			{
					if ( ActiveMeleeSpawnRules[RuleIndex].Type == RuleType_Force )
					{
						// [Step 3] Cool, so for a force rule. We want to set EACH melee in the rule's ForcedSpawnsRequired to the rules limit.
							for ( int Melee = 0; Melee < Melee_Count; Melee++ )
							{
								if ( ActiveMeleeSpawnRules[RuleIndex].ContainsMelee(Melee) && IsMeleeAllowedToSpawn(Melee) ) MeleeInformation[Melee].ForcedSpawnsRequired = ActiveMeleeSpawnRules[RuleIndex].Limit;
							}
					}
					else if ( ActiveMeleeSpawnRules[RuleIndex].Type == RuleType_ForceRandom )
					{
						// [Step 4] Lets get all the available melees in this rule, so that we can pick randomly from them.
							int MeleesInRule[Melee_Count];
							for ( int Melee = 0; Melee < Melee_Count; Melee++ )
							{
								if ( ActiveMeleeSpawnRules[RuleIndex].ContainsMelee(Melee) && IsMeleeAllowedToSpawn(Melee) ) MeleesInRule[Melee] = Melee;
								else MeleesInRule[Melee] = -1;
							}
							
						// [Step 5] Rerandomize and pick a valid melee for as many times as we need.
							for ( int Index = 0; Index < ActiveMeleeSpawnRules[RuleIndex].AvailableSpawns(); Index++ )
							{	
								SortIntegers(MeleesInRule, Melee_Count, Sort_Random);
								for ( int Melee = 0; Melee < Melee_Count; Melee++ )
								{
									if ( IsMeleeIndexValid(MeleesInRule[Melee]) && IsMeleeAllowedToSpawn(MeleesInRule[Melee]) )
									{
										MeleeInformation[MeleesInRule[Melee]].ForcedSpawnsRequired += 1;
										IncreaseMeleeCountForAllRules(MeleesInRule[Melee]);
										break;
									}
								}	
							}	
					}	
			}

		// [Step] Randomize our spawn process order, so we avoid static spawns.
			int MeleeSpawnIndexes[Max_Entities];
			for ( int MeleeSpawnIndex = 0; MeleeSpawnIndex < GameInformation.MeleeSpawnsCount; MeleeSpawnIndex++ ) MeleeSpawnIndexes[MeleeSpawnIndex] = MeleeSpawnIndex;
			SortIntegers(MeleeSpawnIndexes, GameInformation.MeleeSpawnsCount, Sort_Random);

		// [Step 6] Now lets enforce our force rules.
			bool UseReplaceablesFirst = CvarUseReplaceablesFirst.BoolValue;
			for ( int ArrayIndex = 0; ArrayIndex < GameInformation.MeleeSpawnsCount; ArrayIndex++ )
			{
				// [Step 7] If we're at the end of our loop and we were using replaceables first, lets restart and allow all melees through!
					int MeleeSpawnIndex = MeleeSpawnIndexes[ArrayIndex];

					if ( UseReplaceablesFirst && (ArrayIndex >= GameInformation.MeleeSpawnsCount-1) )
					{
						UseReplaceablesFirst = false;
						MeleeSpawnIndex = 0;
						SortIntegers(MeleeSpawnIndexes, GameInformation.MeleeSpawnsCount, Sort_Random);
					}
					else if ( UseReplaceablesFirst && AllMeleeSpawns[MeleeSpawnIndex].ProcessAction != ProcessAction_Replace ) continue;

				// [Step 8] Only continue if our spawn isn't ready to spawn already.
					if ( AllMeleeSpawns[MeleeSpawnIndex].ProcessAction == ProcessAction_Spawn ) continue;		
				
				// [Step 9] Loop through all our melees, see if they have a forced spawn, if they do, lets replace the current entity with it!
					for ( int Melee = 0; Melee < Melee_Count; Melee++ )
					{
						if ( MeleeInformation[Melee].ForcedSpawnsRequired >= 1 && IsMeleeAllowedOnMap(Melee) )
						{
							MeleeInformation[Melee].ForcedSpawnsRequired -= 1;
							AllMeleeSpawns[MeleeSpawnIndex].ProcessAction = ProcessAction_Spawn;
							AllMeleeSpawns[MeleeSpawnIndex].Melee = Melee;
							AllMeleeSpawns[MeleeSpawnIndex].Skin = GetRandomSkin(Melee);
							IncreaseMeleeCountForAllRules(Melee);
							break;
						}
					}
			}

		// [Step 10] Cool, now all our forced melee spawns should be finished. Now lets clear up all the remaining spawns..
			SortIntegers(MeleeSpawnIndexes, GameInformation.MeleeSpawnsCount, Sort_Random);
			for ( int ArrayIndex = 0; ArrayIndex < GameInformation.MeleeSpawnsCount; ArrayIndex++ )
			{
				int MeleeSpawnIndex = MeleeSpawnIndexes[ArrayIndex];
				if ( AllMeleeSpawns[MeleeSpawnIndex].ProcessAction == ProcessAction_Replace )
				{
					int NewMelee = FindValidMeleeSpawn();
					
					if ( IsMeleeIndexValid(NewMelee) && IsMeleeAllowedToSpawn(NewMelee) )
					{
						// [Step 11] If we got valid spawns left, lets set our melee to a valid spawn! And try to get a kewl skin while we're at it?
							AllMeleeSpawns[MeleeSpawnIndex].Melee = NewMelee;
							AllMeleeSpawns[MeleeSpawnIndex].ProcessAction = ProcessAction_Spawn;
							AllMeleeSpawns[MeleeSpawnIndex].Skin = GetRandomSkin(NewMelee);
							IncreaseMeleeCountForAllRules(NewMelee);
					}
					else if ( !CvarDeleteOnNoSpawns.BoolValue )
					{
						// [Step 12] Welp, no valid spawns left, but the user doesn't want us to delete the rule. Lets at least try to throw a new skin on it.
							AllMeleeSpawns[MeleeSpawnIndex].ProcessAction = ProcessAction_Spawn;
							AllMeleeSpawns[MeleeSpawnIndex].Skin = GetRandomSkin(AllMeleeSpawns[MeleeSpawnIndex].Melee);
							IncreaseMeleeCountForAllRules(AllMeleeSpawns[MeleeSpawnIndex].Melee);
					}
				}
				else if ( AllMeleeSpawns[MeleeSpawnIndex].ProcessAction == ProcessAction_Keep )
				{
					// [Step 13] Welp, looks like this spawn is already valid! Nice. Lets mark it as ready to spawn so the game knows too.
						if ( IsMeleeAllowedOnMap(AllMeleeSpawns[MeleeSpawnIndex].Melee) ) 
						{
							AllMeleeSpawns[MeleeSpawnIndex].ProcessAction = ProcessAction_Spawn;
							IncreaseMeleeCountForAllRules(AllMeleeSpawns[MeleeSpawnIndex].Melee);
						}
				}
			}
			return true;
	}

// ======= Function : ResetGameInfo =============================================================================
// 		Resets active rule counts, saved melee spawns, and saved individual melee info.
//		Called at the beginning of each map. VITAL STUFF BABY!
// =====================================================================================================================
	public void ResetGameInfo()
	{
		// [Step 1] First we should reset all of our active rules count value.
			for ( int RuleIndex = 0; RuleIndex < GameInformation.RuleCount; RuleIndex++ ) ActiveMeleeSpawnRules[RuleIndex].Count = 0;
			
		// [Step 3] Nice, now lets reset our stored melee entities.
			for ( int CurrentSpawn = 0; CurrentSpawn < GameInformation.MeleeSpawnsCount; CurrentSpawn++ )
			{
				AllMeleeSpawns[CurrentSpawn].EntityRef = -1;
				AllMeleeSpawns[CurrentSpawn].Melee 	   = -1;
				AllMeleeSpawns[CurrentSpawn].SpawnOrigins = NULL_VECTOR;
				AllMeleeSpawns[CurrentSpawn].SpawnAngles  = NULL_VECTOR;
				AllMeleeSpawns[CurrentSpawn].Skin = 0;
				AllMeleeSpawns[CurrentSpawn].HasPhysics = false;
				AllMeleeSpawns[CurrentSpawn].ProcessAction = ProcessAction_None;

			}
			GameInformation.MeleeSpawnsCount = 0;		
			
		// [Step 4] And finally, we reset all melee's invidual info.
			for ( int Melee = 0; Melee < Melee_Count; Melee++ )
			{
				MeleeInformation[Melee].ForcedSpawnsRequired = 0;
				MeleeInformation[Melee].SpawnCount = 0;
			}
	}
	
// ======= Function : ProcessMeleeEntity ===============================================================================
// 		Saves a melee spawn change to be used for the second round.
//		@return		(Bool) 	True if successful, False if second round is in progress.
//		@noreturn 	false	Entity is invalid.
// =====================================================================================================================
	stock bool ConvertEntityToMeleeSpawn(int entity, MeleeSpawn Spawn)
	{
		// [Step 1] Make sure our entity is melee are valid.
			if ( !IsValidEntity(entity) ) return false;
			
		// [Step 2] Lets get and set all the information from our entity.
			int MeleeFromEntity 	= GetMeleeWeaponFromEntity(entity);
			Spawn.EntityRef 		= entity;
			Spawn.Melee	 			= MeleeFromEntity;
			Spawn.Skin		 		= GetRandomSkin(MeleeFromEntity);
			Spawn.HasPhysics 		= DoesMeleeSpawnHavePhysics(entity);
			if ( HasEntProp(entity, Prop_Send, "m_vecOrigin") ) GetEntPropVector(entity, Prop_Send, "m_vecOrigin", 	Spawn.SpawnOrigins);
			if ( HasEntProp(entity, Prop_Send, "m_angRotation") ) GetEntPropVector(entity, Prop_Send, "m_angRotation", Spawn.SpawnAngles);
			return true;
	}
	
// ======= Function : RegisterMeleeSpawn ===============================================================================
// 		Registers a new melee spawn to the spawn array, or overwrites an old one.
//		@return		(Bool) 	True if successful, False if no valid index was found.
// =====================================================================================================================
	stock bool RegisterMeleeSpawn(MeleeSpawn Spawn)
	{	
		// [Step 1] Lets try to see if there are any already saved spawns that have the same ID, so we can overwrite it.
			int NewIndex = -1, FoundIndex = -1;
			for ( int Index = 0; Index < GameInformation.MeleeSpawnsCount; Index++ )
			{
				if ( Spawn.EntityRef > 0 && Spawn.EntityRef == AllMeleeSpawns[Index].EntityRef ) 
				{
					FoundIndex = Index;
					break;
				}
			}
		
		// [Step 2] If we found an index, that means there's already a save for this spawn, and lets use that instead. If not, lets add a new spawn!
			if ( FoundIndex >= 0 ) 
			{
				NewIndex = FoundIndex;
			}
			else 
			{
				NewIndex = GameInformation.MeleeSpawnsCount;
				GameInformation.MeleeSpawnsCount += 1;
			}

		// [Step 3] Save our new spawn! (Maybe...)
			if ( NewIndex >= 0 ) AllMeleeSpawns[NewIndex] = Spawn;
			else return false;
			return true;
	}
	
// ======= Function : IncreaseMeleeCountForAllRules ====================================================================
// 		Increased the count for a given melee for all active rules that have it flagged.
//		@return		(Bool) 	True if successful.
//		@noreturn 	false	Melee was invalid or no filters were found.
// =====================================================================================================================
	stock bool IncreaseMeleeCountForAllRules(int Melee, int IncreaseBy = 1)
	{
		// [Step 1] Should I even bother at this point? -- Make sure the melee is valid.
			if ( !IsMeleeIndexValid(Melee) ) return false;
			
		// [Step 2] Alright, lets change the melee's individual count first.
			MeleeInformation[Melee].SpawnCount += IncreaseBy;
			if ( MeleeInformation[Melee].SpawnCount < 0 ) MeleeInformation[Melee].SpawnCount = 0;
			
		// [Step 3] Alrighty, lets loop through all of the rules, and change the count for them ezpz.
			for ( int RuleIndex = 0; RuleIndex < GameInformation.RuleCount; RuleIndex++ )
			{	
				// [Step 4] Change the rule's count if it contains our melee.
					if ( ActiveMeleeSpawnRules[RuleIndex].ContainsMelee(Melee) ) ActiveMeleeSpawnRules[RuleIndex].Count += IncreaseBy;
					if ( ActiveMeleeSpawnRules[RuleIndex].ContainsMelee(Melee) && ActiveMeleeSpawnRules[RuleIndex].Count < 0 ) ActiveMeleeSpawnRules[RuleIndex].Count = 0;
			}
			return true;
	}
	
// ======= Function : FindValidMeleeSpawn ==============================================================================
// 		Finds the best available melee spawn.
//		@return		(Int) 	Melee Weapon Index of best available spawn.
//		@noreturn 	-1		No available spawns.
// =====================================================================================================================
	public int FindValidMeleeSpawn()
	{
		// [Step ] Loop through all melees, and store them in an array going from the least count, to the greatest.
			int MeleeSpawnsByCount[Melee_Count][2]; // 0 = Melee Wepon | 1 = Count.
			for ( int Melee = 0; Melee < Melee_Count; Melee++ )
			{
				MeleeSpawnsByCount[Melee][0] = Melee;
				MeleeSpawnsByCount[Melee][1] = MeleeInformation[Melee].SpawnCount;
			}
			SortCustom2D(MeleeSpawnsByCount, Melee_Count, SortFunctionSortByAscending);
				
		// [Step ] Ight. Now lets loop through the array beginning with the least popular melee and if its valid lets save it to the available spawns array.
			int AvailableMeleeSpawns[Melee_Count];
			for ( int Melee = 0; Melee < Melee_Count; Melee++ ) 
			{
				if ( IsMeleeIndexValid(MeleeSpawnsByCount[Melee][0]) )
				{
					if ( IsMeleeAllowedToSpawn(MeleeSpawnsByCount[Melee][0]) ) AvailableMeleeSpawns[Melee] = MeleeSpawnsByCount[Melee][0];
					else AvailableMeleeSpawns[Melee] = -1;
				}
			}
			if ( CvarFindMode.IntValue == 1 ) SortIntegers(AvailableMeleeSpawns, Melee_Count, Sort_Random);

		// [Step ] Loop through the available melees and find a valid one.
			for ( int Melee = 0; Melee < Melee_Count; Melee++ ) 
			{
				if ( IsMeleeIndexValid(AvailableMeleeSpawns[Melee]) )
				{
					if ( IsMeleeAllowedToSpawn(AvailableMeleeSpawns[Melee]) ) return AvailableMeleeSpawns[Melee];
				}
			}
			return -1;
	}
	
// ======= Function : SpawnMelee =======================================================================================
// 		Spawns a new melee of a given type at a given location.
//		@return		(Bool) 	True if successful.
//		@noreturn 	false	Entity / Melee index invalid.
// =====================================================================================================================
	stock bool SpawnMelee(MeleeSpawn Spawn)
	{
		// [Step 1] To avoid hunter arms from spawning. Lets check to make sure the melee is valid and allowed on the map :)
			if( !IsMeleeIndexValid(Spawn.Melee) || !IsMeleeAllowedOnMap(Spawn.Melee) ) return false;

		// [Step 2] Lets create our new melee entity.
			int NewMeleeEntity = CreateEntityByName("weapon_melee_spawn");
			DispatchKeyValue(NewMeleeEntity, "model", "models/weapons/melee/w_fireaxe.mdl");

		// [Step 4] If our melee is suppose to have a skin, lets try to dress it up!	
			DispatchKeyValue(NewMeleeEntity, "melee_weapon", MeleeNameArray[Spawn.Melee]);
			
			if ( Spawn.HasPhysics ) DispatchKeyValue(NewMeleeEntity, "spawnflags", "1");
			else DispatchKeyValue(NewMeleeEntity, "solid", "6");

			
		// [Step 3] Lets attempt to spawn it. If we succeed, lets teleport it to it's rightful location.
			TeleportEntity(NewMeleeEntity, Spawn.SpawnOrigins, Spawn.SpawnAngles, NULL_VECTOR);
			if ( !DispatchSpawn(NewMeleeEntity) ) return false;		

		// [Step 4] If our melee is suppose to have a skin, lets try to dress it up!	
			if ( Spawn.Skin == 1 ) 
			{	
				if ( HasEntProp(NewMeleeEntity, Prop_Data, "m_nWeaponSkin") ) SetEntProp(NewMeleeEntity, Prop_Data, "m_nWeaponSkin", 1);
				if ( HasEntProp(NewMeleeEntity, Prop_Send, "m_nSkin") ) 	  SetEntProp(NewMeleeEntity, Prop_Send, "m_nSkin", 1);
			}

		// [Step 5] Did we succeed in getting a new spawn?
			if ( IsValidEntity(NewMeleeEntity) ) Spawn.EntityRef = NewMeleeEntity;
			else Spawn.EntityRef = -1;

			return true;
	}

/***
 *      __  _ _  __    ___  _             _       
 *     | _|| | ||_ |  / __|| |_  ___  __ | |__ ___
 *     | | |_  _|| |  \__ \|  _|/ _ \/ _|| / /(_-<
 *     | |   |_| | |  |___/ \__|\___/\__||_\_\/__/
 *     |__|     |__|                              
 */
// ======= Stock : IsMeleeAllowedOnMap =================================================================================
// 		Checks the maps current available melee spawns to see if the inputted melee is allowed to be spawned.
//		@return		(Bool) 	True if melee type is allowed to spawn. False otherwise.
//		@noreturn 	false	Melee was invalid.
// =====================================================================================================================
	public bool IsMeleeAllowedOnMap(int Melee)
	{
		// [Step 1] As per usual, make sure we have a valid Melee input.
			if ( !IsMeleeIndexValid(Melee) ) return false;
		
		// [Step 2] Lets get the current string table which contains our allowed melees!
			int MeleeWeaponsStringTable = FindStringTable("MeleeWeapons");
		
		// [Step 3] Now IsEntityInSaferoom(entity) loop through all of the strings and compare them to our melee name.
			for( int StringTableIndex = 0; StringTableIndex < GetStringTableNumStrings(MeleeWeaponsStringTable); StringTableIndex++ )
			{
				// [Step 4] Get the (next) string from the table. This will automatically update with our MapInfo thingy.
					char MeleeFromTable[32];
					ReadStringTable(MeleeWeaponsStringTable, StringTableIndex, MeleeFromTable, sizeof(MeleeFromTable));
	
				// [Step 5] Is this string the same as our melees name?
					if ( StrEqual(MeleeNameArray[Melee], MeleeFromTable, false) ) return true;
			}
			return false;
	}

// ======= Stock : IsMeleeAllowedToSpawn ===============================================================================
// 		Checks all active rules that have the inputted melee flagged and checks if the melee is allowed to spawn.
//		@return		(Bool) 	True if melee type is allowed to spawn. False otherwise.
//		@noreturn 	false	Melee was invalid.
// =====================================================================================================================
	public bool IsMeleeAllowedToSpawn(int Melee)
	{	
		// [Step 1] First step it to check that are melee is both valid, and is allowed to spawn on this map. (To avoid hunter arms spawning xD)
			if ( !IsMeleeIndexValid(Melee) || !IsMeleeAllowedOnMap(Melee) ) return false;
		
		// [Step 2] Lets grab all of the rules that contain this melee weapon. If any...
			bool AllowMeleeToSpawn = true;
			for ( int RuleIndex = 0; RuleIndex < GameInformation.RuleCount; RuleIndex++ )
			{			
				if ( ActiveMeleeSpawnRules[RuleIndex].ContainsMelee(Melee) ) AllowMeleeToSpawn = ActiveMeleeSpawnRules[RuleIndex].CanSpawn();		
			}
			
		// [Step 3] Did the least rule containing our melee say it's safe to spawn in?
			return AllowMeleeToSpawn;
	}

// ======= Stock : GetMeleeWeaponFromEntity ============================================================================
// 		Grabs the model from an entity and tries to find a valid melee index from it.
//		@return		(Int) 	Melee Weapon Index of Entity.
//		@noreturn 	-1		Entity was not valid / Not a melee.
// =====================================================================================================================
	public int GetMeleeWeaponFromEntity(int entity)
	{
		// [Step 1] Lets make sure our entity is valid before doing anything.
			if ( !IsValidEntity(entity) ) return -1;
		
		// [Step 2] Now that we know our entity is valid, lets grab the model as a string.
			char MeleeModel[PLATFORM_MAX_PATH];
			GetEntPropString(entity, Prop_Data, "m_ModelName", MeleeModel, sizeof(MeleeModel));
			
		// [Step 3] Now Lets loop through all our melee names only (no groups) and see if any match our model string.
			if ( StrContains(MeleeModel, "/w_bat.mdl", false) > -1 || StrContains(MeleeModel, "/v_bat.mdl", false) > -1 ) return 3;
			for ( int Index = 0; Index < Melee_Count; Index++ )
			{	
				if ( StrContains(MeleeModel, MeleeNameArray[Index], false) > -1 ) return Index;
			}	
			return -1; // no matches :( just like my tinder profile..
	}

// ======= Stock : GetRandomSkin =======================================================================================
// 		Returns a random weapon skin if the melee is a crowbar or cricket bat.
//		@return		(Int) 	1 for weapon skin (Weapon skin index) 0 for none (also technically an index).
// =====================================================================================================================
	public int GetRandomSkin(int Melee)
	{
		if ( Melee == 4 && GetRandomFloat(1.0, 100.0) <= CvarCrowbarSkinChance.FloatValue ) return 1;
		else if ( Melee == 5 && GetRandomFloat(1.0, 100.0) <= CvarCricketSkinChance.FloatValue ) return 1;
		else return 0;
	}

// ======= Stock : GetMeleeWeaponIndexFromString =======================================================================
// 		Returns a melee weapons index from a model or name string. Does this by looping through the string arrays.
//		@return		(Int) 	Melee Weapon Index for matching Melee.
//		@noreturn 	-1		No Melees matched the inputted string.
// =====================================================================================================================
	public int GetMeleeWeaponIndexFromString(char[] MeleeString)
	{
		// [Step 1] QOL stuff
			if ( StrEqual(MeleeString, "all", 		false) 	) return 15;
			if ( StrEqual(MeleeString, "all sharp", false) 	) return 14;
			if ( StrEqual(MeleeString, "all blunt", false) 	) return 13;
			
		// [Step 2] Lets see if our string matches any of our melee names, or our groups (i.e all_blunt)
			for ( int Index = 0; Index < Melee_Count + 3; Index++ )
			{	
				if ( StrContains(MeleeString, MeleeNameArray[Index], false) > -1 ) return Index;
			}
			return -1;
	}

// ======= Stock : GetFilterTypeFromString =============================================================================
// 		Returns a rule type from a string. String must match an entry in RuleTypeStringArray (Line 21)
//		@return		(MeleeSpawnRuleType) 	Rule type from string.
//		@noreturn 	RuleType_None			No rules matched the inputted string.
// =====================================================================================================================
	stock MeleeSpawnRuleType GetFilterTypeFromString(char[] TypeStr)
	{
		// [Step 1] Loop through all of the active rules.
			for ( int Index = 0; Index < RuleTypes_Count; Index++ )
			{	
				// [Step 2] First lets check if this TypeStr matches any of our rule strings.
					if ( StrEqual(RuleTypeStringArray[Index], TypeStr, false) ) return view_as<MeleeSpawnRuleType>(Index);
			}
			return RuleType_None;
	}
	
// ======= Stock : SortFunctionSortByAscending =========================================================================
// 		Sorts a 2D array by ascending order from the value in it's second demon-shin. Also hello to Psim.
// =====================================================================================================================
	public int SortFunctionSortByAscending(int[] NewInt, int[] CompareInt, const int[][] IntArray, Handle DataHandle)
	{
		// [Step 1] If our compare int is less than our old int, move it ahead!
			if ( NewInt[1] < CompareInt[1] ) return -1;
			return ( NewInt[1] > CompareInt[1] );
	} 

// ======= Stock : IsMeleeIndexValid ===================================================================================
// 		Checks to make sure a integer is a valid melee weapon index.
//		@return		(bool) 	True if valid, false otherwise.
// =====================================================================================================================
	public bool IsMeleeIndexValid(int MeleeIndex)
	{
		// [Step 1] Is the index less than 0 or more than our total number of flags (16)
			if ( MeleeIndex <= -1 || MeleeIndex > Flag_Count ) return false;
			return true;
	}
	
// ======= Stock : InSecondRound =======================================================================================
// 		Checks if game is currently in the second round of a map.
//		@return		(bool) 	True if valid, false otherwise.
// =====================================================================================================================
	public bool InSecondRound()
	{
		return view_as<bool>( GameRules_GetProp("m_bInSecondHalfOfRound") );
	}
	
// ======= Stock : IsInSaferoom =======================================================================================
// 		Just combines saferoom detects functions into one.
//		@return		(bool) 	True if the specified entity is in either the start or end saferoom.
// =====================================================================================================================
	public bool IsInSaferoom(int entity)
	{
		// [Step 1] This is literally just a QOL thing. I guess.
			if ( !IsValidEntity(entity) ) return false;
			if ( SAFEDETECT_IsEntityInEndSaferoom(entity) || SAFEDETECT_IsEntityInStartSaferoom(entity) ) return true;
			else return false;
	}

// ======= Stock :  DoesMeleeSpawnHavePhysics ==========================================================================
// 		Checks the entities spawn flags to see if it contains vphysics. This is so we dont have floating melee weapons.
//		@return		(bool) 	I'm too lazy to write this out.
// =====================================================================================================================
	public bool DoesMeleeSpawnHavePhysics(int entity)
	{
		// [Step 1] Spwanflag 1 = Use vphysics, so we can check if our entity contains this flag, and if it does. That means it uses physics!
			if ( !IsValidEntity(entity) || !HasEntProp(entity, Prop_Data, "m_spawnflags") ) return false;
			return view_as<bool>( GetEntProp(entity, Prop_Data, "m_spawnflags") & 1 );
	}