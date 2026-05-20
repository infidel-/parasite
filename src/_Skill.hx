// skill / knowledge ids
// enum abstract over String: builtin SKILL_*/KNOW_* constants stay usable in
// engine code (compile-time checked, autocompleted), while the runtime value
// is a plain String so mods can register new skill ids at runtime and so
// persisted save fields hold bare strings (see Loader.initEnum migration).
enum abstract _Skill(String) to String from String
{
  var SKILL_ATTACK = 'SKILL_ATTACK';
  var SKILL_FISTS = 'SKILL_FISTS';
  var SKILL_BATON = 'SKILL_BATON';
  var SKILL_CLUB = 'SKILL_CLUB';
  var SKILL_KNIFE = 'SKILL_KNIFE';
  var SKILL_MACHETE = 'SKILL_MACHETE';
  var SKILL_KATANA = 'SKILL_KATANA';
  var SKILL_PISTOL = 'SKILL_PISTOL';
  var SKILL_RIFLE = 'SKILL_RIFLE';
  var SKILL_SHOTGUN = 'SKILL_SHOTGUN';
  var SKILL_COMPUTER = 'SKILL_COMPUTER';

  var KNOW_SMOKING = 'KNOW_SMOKING'; // removed
  var KNOW_SHOPPING = 'KNOW_SHOPPING'; // removed
  var KNOW_SOCIETY = 'KNOW_SOCIETY';

  var SKILL_PSYCHOLOGY = 'SKILL_PSYCHOLOGY';
  var SKILL_DECEPTION = 'SKILL_DECEPTION';
  var SKILL_COERCION = 'SKILL_COERCION';
  var SKILL_COAXING = 'SKILL_COAXING';
}
