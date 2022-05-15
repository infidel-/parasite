package game;

import const.EvolutionConst;

@:structInit class Organ extends _SaveObject
{
  static var _ignoredFields = [ 'improvInfo', 'info' ];
  public var id: _Improv; // organ id
  public var level: Int; // organ level (copied from improvement on creation)
  public var isActive: Bool; // organ active?
  public var gp: Int; // growth points
  public var improvInfo: ImprovInfo; // evolution improvement link
  public var info: OrganInfo; // organ info link
  public var params: Dynamic; // current level params link
  public var timeout: Int; // charge timeout

  public function new(id, level, isActive, gp, improvInfo, info, params, timeout)
    {
      this.id = id;
      this.level = level;
      this.isActive = isActive;
      this.gp = gp;
      this.improvInfo = improvInfo;
      this.info = info;
      this.params = params;
      this.timeout = timeout;
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
          improvInfo = EvolutionConst.getInfo(id);
          info = improvInfo.organ;
        }
    }
}
