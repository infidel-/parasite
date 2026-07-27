package render;

import three.Three;
import citygen.CityModel.City;
import render.world.WorldCtx;
import render.world.Ground;
import render.world.Lawns;
import render.world.Buildings;
import render.world.roofs.RoofShadows;
import render.world.roofs.RoofDetails;
import render.world.Entrances;
import render.world.Windows;
import render.world.WallDecals;
import render.world.Check;

// builds the whole static city geometry into a scene from a City model. Thin facade
// over render.world.*: seeds the shared WorldCtx, then runs the passes in order and
// verifies. Geometry lives in the sub-builders (Ground/Buildings/render.world.roofs.*/
// Entrances/Windows), spatial queries in render.world.Geom, the post-gen audit in Check.
class World {
  static var checked = false;

  public static function build(scene:Scene, city:City, seed:Int = -1, ?style:render.world.AreaStyle, audit = true):Void {
    // one-time geometry self-check (face-dir/rotation invariants)
    if (!checked)
      {
        checked = true;
        if (!render.world.Geom.demo())
          js.Browser.console.warn('[walldecal] geom self-check FAILED');
      }
    WorldCtx.buildings = city.buildings;
    WorldCtx.tiles = city.tiles;
    WorldCtx.seed = seed;
    WorldCtx.style = style != null ? style : render.world.CityStyle.get();
    WorldCtx.winSeen = new haxe.ds.ObjectMap();
    WorldCtx.doorSeen = new haxe.ds.ObjectMap();
    WorldCtx.bandSeen = new haxe.ds.ObjectMap();
    WorldCtx.noBackDoor = [];
    WorldCtx.doorSpans = [];

    Ground.build(scene);          // ground tiles, road markings, kerb edging
    Lawns.build(scene);           // dead-lawn grass patches around the slums houses (no-op elsewhere)
    Buildings.build(scene);       // per-building box loop (delegates parapet/gable to render.world.roofs)
    Windows.add(scene);
    Windows.addGlassAccents(scene); // sparse scattered tint/lit panes over the baked glass-tower grid
    Buildings.addGround(scene);   // ground-floor storefront bands
    Entrances.add(scene);
    WallDecals.add(scene);        // static graffiti/posters/cracks on bare walls
    RoofShadows.addRoofShadows(scene);
    RoofDetails.addRoofDetails(scene);

    if (audit) Check.run(); // skip on throwaway warmup cities — nobody walks them, so the audit is pure spam
  }
}
