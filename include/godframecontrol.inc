#if defined godframesincluded
  #endinput
#endif

#define godframesincluded

/**
 * Gives a specified client god frames for x amount of time
 *
 * @param client   	The client to give godframes to.
 * @param time   	Amount of times the godframes will last.
 * @param time   	The ZClass of the attacker.
 * @return          True if successful, false otherwise.
 */
native void GiveClientGodFrames(int client, Float:time, int zclass);

public SharedPlugin:godframescontrol=
{
        name = "l4d2_godframes_control_merge",
        file = "l4d2_godframes_control_merge.smx",
        required = 1,
};

public godframescontrol_SetNTVOptional()
{
    MarkNativeAsOptional("GiveClientGodFrames");
}