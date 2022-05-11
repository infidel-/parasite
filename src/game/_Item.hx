// item type

package game;

@:structInit class _Item extends _SaveObject
{
  static var _ignoredFields = [ 'info', 'event',
  ];
  public var id: String; // item id
  public var name: String; // actual item name (from a group of names)
  public var info: _ItemInfo; // item info link
  public var event: scenario.Event; // scenario event link (for clues)

  public function new(id, name, info, event)
    {
      this.id = id;
      this.name = name;
      this.info = info;
      this.event = event;
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
    }
}
