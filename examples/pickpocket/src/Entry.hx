// pickpocket mod — adds a pickpocket player action + skill, seeds street NPCs
// with the skill, and introduces the Burglar King: a non-hostile unique NPC who
// cannot be attached to, vanishes in a gas poof if alerted, teaches the maxed
// pickpocket skill via chat consult, and carries a smokable gold-plated cigar.
//
// the pickpocket action is injected by wrapping PlayerArea.updateActionList
// (no engine hook exists for area actions yet); it self-dispatches through the
// _PlayerAction.f callback so PlayerArea.action() needs no patch.
package;

import mods.ModRuntime;

@:expose("pickpocket_Entry")
class Entry
{
  // runtime handle — reached from injected action closures and BK behavior
  public static var parasite: ModRuntime;

  // shared content ids
  public static inline var SKILL = 'mod-pickpocket-pickpocket';
  public static inline var CIGAR = 'mod-pickpocket-cigar';

  public static function main() {}

// boot hook — register content, wire the action injection + events
  public static function init(parasite: ModRuntime): Void
    {
      Entry.parasite = parasite;

      // skill must register before anything that references it (BK skill seed,
      // the action roll, the consult teach)
      parasite.api.registerSkill({
        id: SKILL,
        group: 'Combat',
        name: 'pickpocket',
        defaultLevel: 0,
      });
      parasite.api.registerItem(GoldPlatedCigar);

      // register the Burglar King class into the engine class registry under
      // its serialized name. the engine reconstructs saved AIs via
      // Type.resolveClass(__name__) + createEmptyInstance (Loader.initObject),
      // and mod classes are otherwise invisible to that lookup — without this a
      // save taken while he is present would throw "Could not resolve class".
      Reflect.setField(parasite.hxClasses,
        Type.getClassName(BurglarKingAI), BurglarKingAI);

      // inject the Pickpocket area action: wrap updateActionList so our action
      // is appended after the engine builds its list on each HUD refresh.
      // hxClasses is the raw JS class registry (Dynamic) — prototype patching
      // has no typed surface, so the class ref stays Dynamic
      var PlayerArea: Dynamic =
        Reflect.field(parasite.hxClasses, 'game.PlayerArea');
      var origUpdate = PlayerArea.prototype.updateActionList;
      PlayerArea.prototype.updateActionList = function()
        {
          origUpdate.call(js.Lib.nativeThis);
          Pickpocket.injectAction(parasite.game);
        };

      // seed thugs / bums / prostitutes with a chance of the pickpocket skill
      parasite.events.onAISpawn(function(e)
        {
          var t = e.ai.type;
          if (t != 'thug' &&
              t != 'bum' &&
              t != 'prostitute')
            return;
          if (Std.random(100) >= 30)
            return;
          // 20 +- 10
          e.ai.skills.addID(SKILL, 10 + Std.random(21));
        });

      // rare Burglar King appearance, rolled each turn in low-density city areas
      parasite.events.onTurnPre(function(e)
        {
          maybeSpawnBurglarKing(parasite.game);
        });
    }

// rolls a rare Burglar King spawn into the current low-density city area,
// capped at one at a time
  static function maybeSpawnBurglarKing(game: game.Game): Void
    {
      var area = game.area;
      if (area == null)
        return;
      if (Std.string(area.typeID) != 'AREA_CITY_LOW')
        return;
      if (area.getAIWithType('burglarKing').length > 0)
        return;
      if (Std.random(100) >= 5)
        return;
      // findUnseenEmptyLocation() is typed Dynamic in the extern (engine returns
      // a bare {x,y} location object) — read its coords directly
      var loc: Dynamic = area.findUnseenEmptyLocation();
      if (loc.x < 0)
        return;
      var ai = new BurglarKingAI(game, loc.x, loc.y);
      game.player.chat.initClues(ai);
      area.addAI(ai);
    }
}
