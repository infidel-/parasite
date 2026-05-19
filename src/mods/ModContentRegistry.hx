// renderer-side registry for mod-added content
// engine const-table init() iterates these alongside built-ins
package mods;

import const.PediaConst._PediaGroupInfo;

class ModContentRegistry
{
  // mod-registered item classes; appended after built-ins in ItemsConst.init
  public static var items: Array<Class<ItemInfo>> = [];

  // mod-registered pedia groups (each holds its own articles array);
  // appended after built-ins in PediaConst.init
  public static var pediaContents: Array<_PediaGroupInfo> = [];
}
