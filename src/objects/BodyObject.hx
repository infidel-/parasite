// body object (human, animal, etc)

package objects;

import game.Game;
import game.Inventory;

class BodyObject extends AreaObject
{
  public var inventory: Inventory; // inventory (copied from AI)

  public var wasSeen: Bool; // was this body seen by someone already? (limit for call law events)
  public var isSearched: Bool; // is this body searched?
  public var isHumanBody: Bool; // is this a human body?
  public var isDecayAccel: Bool; // is this body with decay acceleration?
  public var organPoints: Int; // amount of organs on this body
  var parentType: String;

  public function new(g: Game, vaid: Int, vx: Int, vy: Int, parentType: String)
    {
      super(g, vaid, vx, vy);
      this.parentType = parentType;
      init();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      inventory = new Inventory(game);
      type = 'body';
      name = 'body';
      wasSeen = false;
      isSearched = false;
      organPoints = 0;
      isDecayAccel = false;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      isHumanBody = (parentType != 'dog');
      imageRow = Const.ROW_OBJECT;
      imageCol = (isHumanBody ? Const.FRAME_HUMAN_BODY : Const.FRAME_DOG_BODY);
      super.initPost(onLoad);
    }

// update actions
  override function updateActionList()
    {
      if (game.player.state != PLR_STATE_HOST)
        return;

      // animals don't have stuff on them
      if (!isSearched && isHumanBody)
        game.ui.hud.addAction({
          id: 'searchBody',
          type: ACTION_OBJECT,
          name: 'Search Body',
          energy: 10,
          obj: this
        });

      if (isSearched)
        for (item in inventory)
          {
            // atm can't take clothing/armor
            if (item.info.type == 'clothing')
              continue;

            var name = (game.player.knowsItem(item.id) ?
              item.name : item.info.unknown);
            game.ui.hud.addAction({
              id: 'get.' + item.id,
              type: ACTION_OBJECT,
              name: 'Get ' + name,
              energy: 5,
              obj: this
            });
          }
    }


// ACTION: action handling
  override function onAction(id: String): Bool
    {
      // search body for stuff
      if (id == 'searchBody')
        searchAction();

      // get stuff from body
      else if (id.substr(0, 4) == 'get.')
        getAction(id.substr(4));

      return true;
    }


// ACTION: get stuff
  function getAction(id: String)
    {
      for (item in inventory)
        if (item.id == id)
          {
            var tmpname = (game.player.knowsItem(item.info.id) ?
              item.name : item.info.unknown);
            game.player.log('You pick the ' + tmpname + ' up.');
            game.player.host.inventory.add(item);
            inventory.remove(id);
            break;
          }
    }


// ACTION: search body
  function searchAction()
    {
      if (Std.random(100) < game.player.hostControl)
        game.log("Your host resists your command.");

      game.log("You've thoroughly searched the body.");
      isSearched = true;
    }


// TURN: despawn bodies and generate area events
// NOTE: despawn != decay
  public override function turn()
    {
      // not enough time has passed
      if (game.turns - creationTime < DESPAWN_TURNS)
        return;

      // notify world about body discovery by authorities
      // habitat bodies are not discovered
      if (!game.area.isHabitat)
        game.managerRegion.onBodyDiscovered(game.area, organPoints);

      game.area.removeObject(this);
    }

  public override function onDecay()
    {
      if (isDecayAccel)
        {
          var o = new Nutrient(game, game.area.id, x, y);
          game.area.addObject(o);
          game.log("The body decays fast leaving nutrients behind.");
        }
    }


  static var DESPAWN_TURNS = 20; // turns until body is despawned (picked up by law etc)
}
