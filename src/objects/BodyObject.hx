// body object (human, animal, etc)

package objects;

import ai.AI;
import game.Game;
import game.Inventory;

class BodyObject extends AreaObject
{
  public var inventory: Inventory; // inventory (copied from AI)

  public var wasSeen: Bool; // was this body seen by someone already? (limit for call law events)
  public var isSearched: Bool; // is this body searched?
  public var isDecayAccel: Bool; // is this body with decay acceleration?
  public var organPoints: Int; // amount of organs on this body
  var parentType: String;

  public function new(g: Game, vaid: Int, vx: Int, vy: Int, parentType: String)
    {
      super(g, vaid, vx, vy);
      init();
      this.parentType = parentType;
      var icon = BodyObject.iconByType(parentType);
      imageRow = icon.row;
      imageCol = icon.col;
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
      parentType = 'civilian';
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      if (imageCol == -1)
        {
          var icon = iconByType(parentType);
          imageRow = icon.row;
          imageCol = icon.col;
        }
      super.initPost(onLoad);
    }

// check if this body can be searched for loot
  public inline function canSearch(): Bool
    {
      return (!isDogBody() &&
        !isChoirBody());
    }

// check if this body should alert human AIs
  public inline function canAlertHumans(): Bool
    {
      return !isDogBody();
    }

// check if this is a dog body
  inline function isDogBody(): Bool
    {
      return parentType == 'dog';
    }

// check if this is a choir body
  inline function isChoirBody(): Bool
    {
      return (parentType == 'choirOfDiscord' ||
        parentType == 'choir' ||
        parentType == 'choir of discord');
    }

// update actions
  override function updateActionList()
    {
      if (game.player.state != PLR_STATE_HOST)
        return;

      // some body types don't have stuff on them
      if (!isSearched && canSearch())
        game.ui.hud.addAction({
          id: 'searchBody',
          type: ACTION_OBJECT,
          name: 'Search body',
          energy: 10,
          obj: this
        });

      if (isSearched)
        for (item in inventory)
          {
            // atm can't take clothing/armor
            if (item.info.type == 'clothing')
              continue;
            if (game.player.host.inventory.length() >=
                game.player.host.maxItems)
              continue;

            var name = (game.player.knowsItem(item.id) ?
              item.name : item.info.unknown);
            game.ui.hud.addAction({
              id: 'get.' + item.id,
              type: ACTION_OBJECT,
              name: 'Get ' + Const.col('inventory-item', name),
              energy: 5,
              obj: this
            });
          }
    }


// ACTION: action handling
  override function onAction(action: _PlayerAction): Bool
    {
      // search body for stuff
      if (action.id == 'searchBody')
        searchAction();

      // get stuff from body
      else if (action.id.substr(0, 4) == 'get.')
        getAction(action.id.substr(4));

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
          game.scene.sounds.play('object-nutrients');
          game.log("The body decays fast leaving nutrients behind.");
        }
    }

// get body tile by AI type
  public static function iconByType(aiType: String): _Icon
    {
      if (aiType == 'dog')
        return {
          row: Const.ROW_OBJECT,
          col: Const.FRAME_DOG_BODY,
        };
      if (aiType == 'choirOfDiscord' ||
          aiType == 'choir' ||
          aiType == 'choir of discord')
        return {
          row: Const.ROW_PARASITE,
          col: Const.FRAME_CHOIR_BODY,
        };
      return {
        row: Const.ROW_OBJECT,
        col: Const.FRAME_HUMAN_BODY,
      };
    }

  static var DESPAWN_TURNS = 20; // turns until body is despawned (picked up by law etc)
}
