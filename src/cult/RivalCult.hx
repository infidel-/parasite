// rival cult structure
package cult;

import l10n.Loc;
import const.CultConst;
import const.Jobs;
import cult.ordeals.HereticalOrdeal;
import game.Game;

class RivalCult extends Cult
{
  public var rivalInfoID: String;
  public var rivalTemplate: String;
  public var rivalTactic: _RivalCultTactic;
  public var rivalRevealedLevel: Int;
  public var rivalBaseAreaID: Int;
  // cult turns until this rival's next strategic turn
  public var strategicTimer: Int;
  // wiped rival: cult turns until a rival of its tactic takes its place (0: none pending)
  public var replaceTimer: Int;

// create rival cult
  public function new(g: Game)
    {
      super(g);
    }

// init rival cult fields
  public override function init()
    {
      super.init();
      rivalInfoID = '';
      rivalTemplate = '';
      rivalTactic = RIVAL_NON_COMBAT;
      rivalRevealedLevel = 0;
      rivalBaseAreaID = -1;
      strategicTimer = CultConst.RIVAL_TURN_PERIOD;
      replaceTimer = 0;
    }

// called after rival cult load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
      if (rivalInfoID == null)
        rivalInfoID = '';
      if (rivalTemplate == null)
        rivalTemplate = '';
    }

// creates a rival of the tactic from its tuning table (a random roster, its first strategic turn staggered)
// and adds it to the game's cults
  public static function generate(game: Game, tactic: _RivalCultTactic): RivalCult
    {
      var taken = [];
      for (other in game.getRivalCults())
        taken.push(other.rivalInfoID);
      var info = CultConst.info(CultConst.randomRivalID(tactic, taken));
      var tuning = CultConst.tunings.get(tactic);
      var rival = new RivalCult(game);
      rival.name = info.name;
      rival.isPlayer = false;
      rival.state = CULT_STATE_ACTIVE;
      rival.level = 2;
      rival.rivalInfoID = info.id;
      rival.rivalTemplate = info.memberTemplate;
      rival.rivalTactic = tactic;
      rival.strategicTimer = 1 + Std.random(CultConst.RIVAL_TURN_PERIOD);
      for (i in 0...tuning.startMembers)
        {
          var level = 1;
          if (Std.random(100) < tuning.level3Pct)
            level = 3;
          else if (Std.random(100) < tuning.level2Pct)
            level = 2;
          rival.addRosterMember(tuning, level);
        }
      rival.recalc();
      game.cults.push(rival);
      return rival;
    }

// adds one roster member drawn from the tuning mix, with a level 1 job raised toward the level while the
// level limits allow
  function addRosterMember(tuning: RivalTuning, level: Int)
    {
      var kind = tuning.mix[Std.random(tuning.mix.length)];
      var ai = game.createAI(kind.type, 0, 0);
      ai.setCult(this);

      // level 1 job: from the power group, or the type's own street roll until it lands on level 1
      var jobInfo: _JobInfo = null;
      if (kind.group != null)
        {
          jobInfo = game.jobs.getJobByGroupAndLevel(kind.group, 1);
          var data = game.jobs.rollJobInfo([jobInfo]);
          ai.job = data.name;
          ai.income = data.income;
        }
      else
        {
          var data = game.jobs.getRandom(ai.type);
          while (data.jobInfo.level != 1)
            data = game.jobs.getRandom(ai.type);
          ai.job = data.name;
          ai.income = data.income;
          jobInfo = data.jobInfo;
        }

      // raise the job one level at a time
      while (jobInfo.level < level)
        {
          var next = game.jobs.getNextJobLevel(jobInfo.group, ai.job);
          if (next == null ||
              !canAddMemberAtLevel(next.level))
            break;
          var data = game.jobs.rollJobInfo([next]);
          ai.job = data.name;
          ai.income = data.income;
          jobInfo = next;
        }
      members.push(ai.cloneData());
    }

// adds one level 1 member to the roster, up to the cult's size cap
  public function recruitMember()
    {
      if (members.length >= maxSize())
        return;
      addRosterMember(CultConst.tunings.get(rivalTactic), 1);
      recalc();
    }

// wipes the rival out: members gone, state dead, a replacement scheduled (the player's raid ended its base)
  public function wipe()
    {
      destroy();
    }

// a destroyed rival stays listed as destroyed, and a rival of its tactic replaces it in a while
  override function onWiped()
    {
      game.log(T('{cult} is destroyed.', { cult: this }));
      replaceTimer = CultConst.RIVAL_REPLACE_TURNS + Std.random(CultConst.RIVAL_REPLACE_SPREAD);
    }

// runs one rival turn: a strategic turn every RIVAL_TURN_PERIOD cult turns
  public override function turn()
    {
      strategicTimer--;
      if (strategicTimer > 0)
        return;
      strategicTimer = CultConst.RIVAL_TURN_PERIOD;
      var tuning = CultConst.tunings.get(rivalTactic);

      // slow growth: a chance to recruit one level 1 member
      if (Std.random(100) < tuning.recruitPct)
        recruitMember();

      // none of this while the player cult is down or has no base
      var player = game.cults[0];
      if (player.state != CULT_STATE_ACTIVE ||
          player.base == null)
        return;

      // a non-combat rival raises a heresy, its pressure comes if that runs out. when none can be raised it
      // spreads the pressure at once
      if (rivalTactic == RIVAL_NON_COMBAT &&
          HereticalOrdeal.raise(game, this))
        return;
      player.base.addPressure(tuning.pressure, id);
      if (rivalTactic == RIVAL_COMBAT)
        game.logsg(T('{cult} drives heathens toward the base.', { cult: Loc.tr(name) }));
      else
        game.logsg(T('{cult} spreads indirect pressure.', { cult: Loc.tr(name) }));
    }

// returns cult display name (rival names are N() keys from CultConst)
  public override function customName(): String
    {
      return Loc.tr(name);
    }
}
