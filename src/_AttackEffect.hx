// melee attack arc visuals — which effect a weapon swings on a hit

enum abstract _AttackEffect(String) to String from String
{
  var SLASH_LIGHT = 'SLASH_LIGHT';
  var SLASH_HEAVY = 'SLASH_HEAVY';
  var BLUNT = 'BLUNT';
  var PUNCH = 'PUNCH';
  var BITE = 'BITE';
  var STUN = 'STUN';
}
