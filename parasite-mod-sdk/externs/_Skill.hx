// skill / knowledge id — enum-abstract over String. mods register new skill
// ids as plain strings (e.g. 'mod-mymod-foo'); engine accepts them anywhere a
// _Skill is expected because of `from String`.
// the SKILL_*/KNOW_* builtin constants below give mods autocomplete + nominal
// safety when referencing core skills (e.g. boosting SKILL_FISTS in a trait).

enum abstract _Skill(String) to String from String
{
  // combat skills
  var SKILL_ATTACK = 'SKILL_ATTACK'; // animal attack, hidden
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
  // manipulation / mental skills
  var SKILL_PSYCHOLOGY = 'SKILL_PSYCHOLOGY';
  var SKILL_DECEPTION = 'SKILL_DECEPTION';
  var SKILL_COERCION = 'SKILL_COERCION';
  var SKILL_COAXING = 'SKILL_COAXING';
  // knowledges
  var KNOW_SMOKING = 'KNOW_SMOKING'; // removed
  var KNOW_SHOPPING = 'KNOW_SHOPPING'; // removed
  var KNOW_SOCIETY = 'KNOW_SOCIETY';
}
