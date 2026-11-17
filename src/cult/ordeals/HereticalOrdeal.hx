// a heresy a non-combat rival cult raises against the player's cult
package cult.ordeals;

import l10n.Loc;
import game.Game;
import cult.ProfaneOrdeal;
import cult.RivalCult;
import cult.missions.CombatTargetsWithGuards;

// flavour text of one heresy
typedef HereticalInfo = {
  var name: String;
  var note: String;
  var success: String;
  var fail: String;
}

class HereticalOrdeal extends ProfaneOrdeal
{
  // pressure on the player's base when the heresy runs out
  public static inline var PRESSURE = 5;
  // power types a heresy is flavoured by (the non-combat ones)
  static var flavours = [ 'media', 'lawfare', 'corporate', 'political' ];
  static var infos: Map<String, Array<HereticalInfo>> = [
    'media' => [
      {
        name: N('Whispering Campaign'),
        note: N('Anonymous feeds trade photographs of your initiates leaving the same doors. A rival cult hands out the captions.'),
        success: N('The feeds go quiet. Some accounts never post again.'),
        fail: N('The story spreads. Strangers watch the doors your people use.'),
      },
      {
        name: N('Hollow Broadcast'),
        note: N('A late-night broadcast preaches a gospel that is not yours, in a voice that sounds like your own.'),
        success: N('The transmitter falls silent and the hollow gospel fades from the airwaves.'),
        fail: N('The hollow gospel takes root. Your followers hesitate at your name.'),
      },
    ],
    'lawfare' => [
      {
        name: N('Writ of Heresy'),
        note: N('A rival cult files petitions against your front companies, one filing for each of your names.'),
        success: N('The petitions are withdrawn and the clerk who filed them forgets the case.'),
        fail: N('The court freezes your accounts and your people spend their days in corridors.'),
      },
      {
        name: N('Sworn Affidavit'),
        note: N('Sworn statements place your initiates at scenes they never visited. The rival lawyers keep the originals.'),
        success: N('The affidavits are discredited. The rival lawyers are reassigned to cases elsewhere.'),
        fail: N('The statements stand. Doors that opened for you close.'),
      },
    ],
    'corporate' => [
      {
        name: N('Hostile Acquisition'),
        note: N('A rival cult buys the debts of your suppliers and calls them in on the same morning.'),
        success: N('The debts are bought back and your suppliers owe you more than before.'),
        fail: N('The suppliers fold. Shipments for the base are lost in the shuffle.'),
      },
      {
        name: N('Quiet Sabotage'),
        note: N('Orders go missing, invoices come back wrong, and a rival cult has a hand in every clerical error.'),
        success: N('The saboteurs are found among the clerks, and the errors stop.'),
        fail: N('The errors pile up and the money you are owed goes missing.'),
      },
    ],
    'political' => [
      {
        name: N('Hearing in Closed Session'),
        note: N('A council committee meets behind closed doors to discuss your cult. A rival cult wrote the agenda.'),
        success: N('The committee adjourns without a vote. Its chairman takes a long holiday.'),
        fail: N('The committee finds against you. Police officers begin asking about the base.'),
      },
      {
        name: N('Whip Count'),
        note: N('A rival cult counts the votes it owns and the votes it can buy. All of them are meant for you.'),
        success: N('The votes drift away. The rival cult is out of favours.'),
        fail: N('The vote goes through and every official in the city knows your name.'),
      },
    ],
  ];

  public var rivalCultID: Int;
  // power type of the flavour, the one that pays the heresy off
  public var flavour: String;
  public var infoID: Int;

// create a heresy of a rival: a strike mission against it, pay its power or money to ride it out
  public function new(g: Game, rivalCultID: Int)
    {
      super(g);
      init();
      this.rivalCultID = rivalCultID;
      initPost(false);

      // flavour: the rival's strongest side, a tie falls to a random one
      var rival = game.getRivalCultByID(rivalCultID);
      var sides = flavours.copy();
      sides.sort(function(a, b) return Std.random(3) - 1);
      flavour = sides[0];
      for (side in sides)
        if (rival.power.get(side) > rival.power.get(flavour))
          flavour = side;
      infoID = Std.random(infos.get(flavour).length);
      var info = getInfo();
      name = info.name;
      note = info.note;

      // two free members, a timer, and a price by the cult's strongest members
      addRandomMembers({
        level: 1,
        amount: 2
      });
      timer = 8 + Std.random(5);
      if (cult.countMembers(3) > 0)
        {
          power.set(flavour, 15);
          power.money = 60000;
        }
      else if (cult.countMembers(2) > 0)
        {
          power.set(flavour, 10);
          power.money = 40000;
        }
      else
        {
          power.set(flavour, 5);
          power.money = 20000;
        }
      missions.push(new CombatTargetsWithGuards(game, CombatTargetsWithGuards.rivalInfo(), rivalCultID));
    }

// init ordeal fields
  public override function init()
    {
      super.init();
      rivalCultID = -1;
      flavour = 'media';
      infoID = 0;
    }

// raises a heresy of the rival against the player's cult when it can take one: the rival has members to
// strike and the cult has two free members and none of this rival's heresies running
  public static function raise(game: Game, rival: RivalCult): Bool
    {
      var cult = game.cults[0];
      if (rival.members.length < 2 ||
          cult.getFreeMembers(1).length < 2)
        return false;
      for (ordeal in cult.ordeals.list)
        if (Std.isOfType(ordeal, HereticalOrdeal) &&
            cast(ordeal, HereticalOrdeal).rivalCultID == rival.id)
          return false;
      var o = new HereticalOrdeal(game, rival.id);
      cult.ordeals.list.push(o);
      cult.recalc();
      game.message({
        text: T('{cult} has raised a heresy against us: {ordeal}.', {
          cult: Loc.tr(rival.name),
          ordeal: o.coloredName(),
        }),
        col: 'white'
      });
      return true;
    }

// flavour text of this heresy
  function getInfo(): HereticalInfo
    {
      return infos.get(flavour)[infoID];
    }

// get custom name for display
  public override function customName(): String
    {
      var rival = game.getRivalCultByID(rivalCultID);
      if (rival != null)
        return Loc.tr(name) + ' (' + rival.customName() + ')';
      return Loc.tr(name);
    }

// the heresy is answered by its strike mission, its power or its money: any one of them
  public override function check()
    {
      if (missions[0].isCompleted ||
          power.get(flavour) == 0 ||
          power.money == 0)
        success();
    }

// the heresy runs out: pressure on the base and a bad effect on the cult
  override function onFail()
    {
      game.message({
        title: T('Ordeal Failed'),
        titleCol: 'red',
        text: Loc.tr(getInfo().fail),
        col: 'cult'
      });
      if (cult.base != null)
        cult.base.addPressure(PRESSURE, rivalCultID);
      cult.addRandomBadEffect(Const.d100() < 5 ? 10 : 5);
    }

// the heresy is answered
  override function onSuccess()
    {
      game.message({
        title: T('Ordeal Succeeded'),
        titleCol: 'white',
        text: Loc.tr(getInfo().success),
        col: 'cult'
      });
    }
}
