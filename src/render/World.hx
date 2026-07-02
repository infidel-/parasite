package render;

import three.Three;
import citygen.CityModel.City;
import render.world.WorldCtx;
import render.world.Ground;
import render.world.Buildings;
import render.world.Roofs;
import render.world.Entrances;
import render.world.Windows;
import render.world.Check;

// builds the whole static city geometry into a scene from a City model. Thin facade
// over render.world.*: seeds the shared WorldCtx, then runs the passes in order and
// verifies. Geometry lives in the sub-builders (Ground/Buildings/Roofs/Entrances/
// Windows), spatial queries in render.world.Geom, the post-gen audit in Check.
class World {
  public static function build(scene:Scene, city:City):Void {
    WorldCtx.buildings = city.buildings;
    WorldCtx.tiles = city.tiles;
    WorldCtx.winSeen = new haxe.ds.ObjectMap();
    WorldCtx.doorSeen = new haxe.ds.ObjectMap();
    WorldCtx.bandSeen = new haxe.ds.ObjectMap();
    WorldCtx.noBackDoor = [];

    Ground.build(scene);          // ground tiles, road markings, kerb edging
    Buildings.build(scene);       // per-building box loop (delegates parapet/gable to Roofs)
    Windows.add(scene);
    Buildings.addGround(scene);   // ground-floor storefront bands
    Entrances.add(scene);
    Roofs.addRoofShadows(scene);
    Roofs.addRoofDetails(scene);

    Check.run();
  }
}
