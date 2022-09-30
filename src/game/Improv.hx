package game;

import const.EvolutionConst;

@:structInit class Improv extends _SaveObject
{
  static var _ignoredFields = [ 'info' ];
  public var id: _Improv; // improvement string ID
  public var level: Int; // improvement level
  public var ep: Int; // evolution points
  public var info: ImprovInfo; // improvement info link
  public var isLocked: Bool; // locked for ovum?

  public function new(id, level, ep, info, isLocked)
    {
      this.id = id;
      this.level = level;
      this.ep = ep;
      this.info = info;
      this.isLocked = isLocked;
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
      info = EvolutionConst.getInfo(id);
    }
}
