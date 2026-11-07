// ordeal base class for cult challenges
package cult;

import l10n.Loc;
import game.Game;
import cult.Cult;
import _CultPower;
import _OrdealType;
import _PlayerAction;
import Icon;
import ai.AIData;

class Ordeal extends _SaveObject
{
  static var _ignoredFields = [ 'cult' ];
  public var game: Game;
  public var name: String;
  public var members: Array<Int>; // cult members involved
  public var effects: Array<Effect>;
  public var power: _CultPower;
  public var type: _OrdealType;
  public var requiredMembers: Int;
  public var requiredMemberLevels: Int;
  public var actions: Int;
  public var note: String;
  public var missions: Array<Mission>;
  public var cult(get, never): Cult;
  private function get_cult(): Cult
    {
      return game.cults[0];
    }

  public function new(g: Game)
    {
      game = g;
 // will be called by sub-classes (careful with ctor code!)
//      init();
//      initPost(false);
    }

// init object before loading/post creation
  public function init()
    {
      members = [];
      effects = [];
      requiredMembers = 0;
      requiredMemberLevels = 0;
      actions = 0;
      note = '';
      missions = [];
      type = ORDEAL_COMMUNAL;
      power = {
        combat: 0,
        media: 0,
        lawfare: 0,
        corporate: 0,
        political: 0,
        occult: 0,
        money: 0
      };
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {}

// add member to ordeal
  public function addMembers(memberIDs: Array<Int>)
    {
      for (memberID in memberIDs)
        {
          if (members.indexOf(memberID) == -1)
            members.push(memberID);
        }
    }

// add random free members to ordeal
  public function addRandomMembers(params: {level: Int, amount: Int, ?excluding: Int, ?onlyGivenLevel: Bool})
    {
      var selected = cult.getRandomAvailableMembers({
        level: params.level,
        amount: params.amount,
        excluding: params.excluding,
        onlyGivenLevel: true
      });
      if (selected.length < params.amount &&
          (params.onlyGivenLevel == null ||
            !params.onlyGivenLevel))
        {
          var higher = cult.getRandomAvailableMembers({
            level: params.level + 1,
            amount: params.amount - selected.length,
            excluding: params.excluding,
            onlyGivenLevel: false
          });
          for (id in higher)
            selected.push(id);
        }
      addMembers(selected);
    }

// get list of cultist IDs locked by this ordeal
  public function getLockedCultists(): Array<Int>
    {
      return members;
    }

// get custom name for display
  public function customName(): String
    {
      return Loc.tr(name);
    }

// the note as shown: translated. an ordeal whose note has values in it builds it here, at display,
// so a save holds no composed text and shows in any language
  public function getNote(): String
    {
      return Loc.tr(note);
    }

// returns the initiate-menu price hint for this ordeal
  public static function priceHint(): String
    {
      return '';
    }

// get colored custom name for display
  public function coloredName(): String
    {
      switch (type)
        {
          case ORDEAL_PROFANE:
            return Const.col('profane-ordeal', customName());
          case ORDEAL_COMMUNAL:
            return Const.col('communal-ordeal', customName());
        }
      return customName();
    }

// a member locked in this ordeal died (Ordeals.onDeath): the ordeal fails
  public function onDeath(aidata: AIData)
    {
      fail();
    }

// fail this ordeal
  public function fail()
    {
      onFail();
      cult.ordeals.fail(this);
    }

// hook for when ordeal fails (override in subclasses)
  function onFail() {}

// check if ordeal is complete
  public function check()
    {
      // check if all missions are completed
      var ok = true;
      for (m in missions)
        if (!m.isCompleted)
          {
            ok = false;
            break;
          }
      if (!ok)
        return;

      // check if all powers are at zero
      if (power.combat == 0 &&
          power.media == 0 &&
          power.lawfare == 0 &&
          power.corporate == 0 &&
          power.political == 0 &&
          power.money == 0)
        success();
    }

// cult-turn hook for active ordeals
  public function turn()
    {}

// complete an ordeal successfully
  public function success()
    {
      onSuccess();
      cult.ordeals.success(this);
    }

// get actions available for this ordeal
  public function getActions(): Array<_PlayerAction>
    {
      // check if we can still perform actions
      var actions = [];
      if (this.actions >= members.length)
        return actions;
      
      for (field in _CultPower.names)
        {
          var powerAmount: Int = power.get(field);
          var cultAmount: Int = cult.resources.get(field);
          
          if (powerAmount > 0 &&
              cultAmount >= powerAmount)
            {
              actions.push({
                id: 'spend.' + field,
                type: ACTION_CULT,
                // tr: {power} is a cult power key, one of: combat, media, lawfare, corporate, political. ALWAYS write {power, select, combat{…} media{…} lawfare{…} corporate{…} political{…} other{…}} with your words: the keys are English and must never show as they are
                name: T('Wield {amount} {power} power', {
                  amount: Const.col('cult-power', powerAmount),
                  power: field,
                }),
                energy: 0,
                f: function() {
                  cult.resources.dec(field, powerAmount);
                  power.set(field, 0);
                  this.actions++;
                  // tr: {power} is a cult power key, one of: combat, media, lawfare, corporate, political. ALWAYS write {power, select, combat{…} media{…} lawfare{…} corporate{…} political{…} other{…}} with your words: the keys are English and must never show as they are
                  cult.log(T('{cult} exerted {amount} {power} power on {ordeal} ordeal.', {
                    cult: cult,
                    amount: Const.col('cult-power', powerAmount),
                    power: field,
                    ordeal: coloredName(),
                  }));
                  check();
                  game.ui.updateWindow();
                }
              });
            }
        }
      
      // spend money action (handled separately)
      if (power.money > 0 &&
          cult.resources.money >= power.money)
        {
          var displayName = Const.col('cult-power', power.money) + Icon.money;
          actions.push({
            id: 'spend.money',
            type: ACTION_CULT,
            name: T('Disburse {money}', { money: displayName }),
            energy: 0,
            f: function() {
              cult.resources.money -= power.money;
              this.power.money = 0;
              this.actions++;
              cult.log(T('{cult} disbursed {money} on {ordeal} ordeal.', {
                cult: cult,
                money: displayName,
                ordeal: coloredName(),
              }));
              check();
              game.ui.updateWindow();
            }
          });
        }
      
      // cancel ordeal
      if (type != ORDEAL_PROFANE)
        actions.push({
          id: 'annul',
          type: ACTION_CULT,
          name: T('Annul') + ' ' + Const.smallgray(T('(results in failure)')),
          energy: 0,
          f: function() {
            fail();
            game.ui.cult.setMenuState(STATE_ROOT);
            game.ui.updateWindow();
          }
        });
      
      return actions;
    }

// hook for when ordeal succeeds (override in subclasses)
  function onSuccess() {}
}
