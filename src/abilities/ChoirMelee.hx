// choir of discord melee ability
package abilities;

class ChoirMelee extends BasicMelee
{
  public function new()
    {
      super();
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      id = ABILITY_CHOIR_MELEE;
      name = N('choir melee');
      skill = 70;
      sound = {
        file: 'attack-fists',
        radius: 5,
        alertness: 5,
      };
      minDamage = 1;
      maxDamage = 6;
    }

// the hit sentence template (see BasicMelee.hitText)
  override function hitText(isYou: Bool): String
    {
      return (isYou ?
        T('{ai:The} vibrates, rending flesh of you for {damage} damage.') :
        T('{ai:The} vibrates, rending flesh of {target:the} for {damage} damage.'));
    }
}
