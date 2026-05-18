// renderer-side registry for mod-added content
// engine const-table init() iterates these alongside built-ins
// see mod-design.md §8.7
package mods;

class ModContentRegistry
{
  // mod-registered item classes; appended after built-ins in ItemsConst.init
  public static var items: Array<Class<ItemInfo>> = [];
}
