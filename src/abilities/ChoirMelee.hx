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
      name = 'choir melee';
      attackMessage = 'XX vibrates, rending flesh of YY';
      skill = 70;
      sound = {
        file: 'attack-fists',
        radius: 5,
        alertness: 5,
      };
      minDamage = 1;
      maxDamage = 6;
    }
}
