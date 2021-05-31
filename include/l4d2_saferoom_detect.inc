/*
  Check if entity is in a saferoom
  returns bool (errors/incorrect data returns false)
*/
native bool SAFEDETECT_IsEntityInStartSaferoom(int entity);
native bool SAFEDETECT_IsEntityInEndSaferoom(int entity);

/*
  Check if player (client) is in a saferoom
  returns bool (errors/incorrect data returns false)
*/
native bool SAFEDETECT_IsPlayerInStartSaferoom(int client);
native bool SAFEDETECT_IsPlayerInEndSaferoom(int client);