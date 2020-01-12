#if defined alreadyIncluded
 #endinput
#endif
#define alreadyIncluded

#include <left4downtown>
#include <sourcemod>
#include <sdktools>

bool IsMapFinale()
{
	new bool:isFinale = L4D_IsMissionFinalMap();
	new String:g_sCurrentMap[64];
	GetCurrentMap(sCurrentMap, sizeof(sCurrentMap));

	if (StrEqual(sCurrentMap, "c3m3_shantytown"))
		return false;

	return isFinale;
}