package game;

import const.EvolutionConst;

@:structInit class Improv extends _SaveObject
{
  static var _ignoredFields = [ 'info' ];
  public var id: _Improv; // improvement string ID
  public var level: Int; // improvement level
  public var ep: Int; // evolution points
  public var info: ImprovInfo; // improvement info link

  public function new(id, level, ep, info)
    {
      this.id = id;
      this.level = level;
      this.ep = ep;
      this.info = info;
    }
}
