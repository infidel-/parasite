// minimal local extern for the parasite runtime object passed to init()
// mirrors src/mods/ModRuntime.hx — full SDK with shared externs lands later (mod-design.md §14 step 11)
package;

typedef ModRuntime = {
  var modID: String;
  var modVersion: String;
  var modApiVersion: Int;
  var game: Dynamic;
  var host: Dynamic;
  var hxClasses: Dynamic;
  var version: String;
  var api: ModContentApi;
}

typedef ModContentApi = {
  function registerItem(cls: Dynamic): Void;
}
