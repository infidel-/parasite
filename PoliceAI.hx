// AI for police 

class PoliceAI extends HumanAI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      type = 'police';

      inventory.addID('pistol');
      skills.addID('pistol', 25 + Std.random(25));
    }


// overridden alert logic
  override function stateAlertLogic()
    {
      // search for player
      if (!seesPosition(game.player.x, game.player.y))
        {
          logicRoam();
          return;
        }

      // attack the threat

      // get current weapon
      var item = inventory.getFirstWeapon();
      var info = null;

      // use fists
      if (item == null)
        info = ConstItems.fists;
      else info = item.info;

      // weapon skill level
      var skillLevel = skills.getLevel(info.weaponStats.skill);

      // roll skill
      if (Std.random(100) > skillLevel)
        {
          log('tries to ' + info.verb1 + ' you, but misses.');
          return;
        }

      // success, roll damage
      var damage = Const.roll(info.weaponStats.minDamage, info.weaponStats.maxDamage);
      if (!info.weaponStats.isRanged) // all melee weapons have damage bonus
        damage += Const.roll(0, Std.int(strength / 2));

      log(info.verb2 + ' ' + 
        (game.player.state == Player.STATE_HOST ? 'your host' : 'you') + 
        ' for ' + damage + ' damage.');

      game.player.onDamage(damage);

      // host skills + parasite bonus
      // aiShootPlayer()

    }
}
