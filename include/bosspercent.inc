#if defined  _bosspercent_included_
    #endinput
#endif
#define _bosspercent_included_

/**
 * Triggers a refresh of percent values which are displayed by the boss percent plugin.
 *
 * @note    To concord your custom boss percents with the ready-up footer, use a timer of ~5.5s in round_start
 * @return          True if no error occured during the refresh
 */
native bool:UpdateBossPercents();

/**
 * Checks if current map is DKR
 *
 * @return          True if map is DKR
 */
native bool:IsDarkCarniRemix();

/**
 * Changes ready up text and chat command to say boss is disabled
 *
 * @param setAs  	0 for an enabled tank, 1 for a disabled tank
 * @noreturn
 */
native void SetTankDisabled(int setAs);

/**
 * Changes ready up text and chat command to say boss is disabled
 *
 * @param setAs  	0 for an enabled witch, 1 for a disabled Witch
 * @noreturn
 */
native void SetWitchDisabled(int setAs);

/**
 * Checks if a specified map has a static tank spawn
 *
 * @param mapname   The map name to check for static spawn
 * @return          True if map contains static spawn
 */
native bool:IsStaticWitchMap();

/**
 * Checks if a specified map has a static tank spawn
 *
 * @param mapname   The map name to check for static spawn
 * @return          True if map contains static spawn
 */
native bool:IsStaticTankMap();

/**
 * Refreshes boss percents on ready up menu
 *
 * @return          True if successful
 */
native bool:RefreshBossPercentReadyUp();

/**
 * @return          Returns stored tank percentage
 */
native int GetStoredTankPercent();


/**
 * @return          Returns ready up footer index of boss percents
 */
native int GetReadyUpFooterIndex();


forward void OnUpdateBosses();


public SharedPlugin:__pl_bosspercent =
{
    name = "l4d_boss_percent",
    file = "l4d_boss_percent.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

public __pl_bosspercent_SetNTVOptional()
{
    MarkNativeAsOptional("UpdateBossPercents");
}