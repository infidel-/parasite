// item type
package game;

import const.ItemsConst;

@:structInit class _Item extends _SaveObject
{
  static var _ignoredFields = [ 'info', 'event',
  ];
  var game: Game;
  public var id: String; // item id
  public var name: String; // actual item name (from a group of names)
  public var info: _ItemInfo; // item info link
  public var event: scenario.Event; // scenario event link (for clues)
  var eventID: String;

  public function new(game, id, name, info, event)
    {
      this.game = game;
      this.id = id;
      this.name = name;
      this.info = info;
      this.event = event;
      this.eventID = (event != null ? event.id : null);
      init();
      initPost(false);
    }

// init object before loading/post creation
  public function init()
    {
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {
      if (onLoad)
        {
          info = ItemsConst.getInfo(id);
          if (eventID != null)
            event = game.timeline.getEvent(eventID);
        }
    }
}
