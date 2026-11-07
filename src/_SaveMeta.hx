// tiny per-slot preview header, written to a save<NN>.meta.json sidecar so the
// save/load slot list can render without parsing the whole save blob
typedef _SaveMeta = {
  var scenario: String;   // scenario display name
  var scenarioID: String; // stable scenario id ('alien' / 'sandbox')
  var area: String;       // current area name at save time, English (a translated label in older metas)
  @:optional var sector: Null<Int>; // district sector number, when area is a district name
  var turns: Int;         // turns elapsed since game start
  var time: Float;        // wall-clock save time (epoch ms, sortable)
}
