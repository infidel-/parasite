// per-mod content-registration facade extern
// mirrors engine src/mods/ModContentApi.hx public surface
package mods;

typedef ModContentApi = {
  // register a custom item class; survives ItemsConst.init re-runs
  function registerItem(cls: Class<ItemInfo>): Void;
}
