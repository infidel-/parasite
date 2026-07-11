package render;

import citygen.CityModel.Building;
import citygen.CityModel.City;
import citygen.CityModel.Tile;
import citygen.CityConfig;

// shared "report this area" text dump: ASCII tile map + per-building metadata
// (floors/facade/winForce/shadowCut). Used by the shape copy buttons (Main) and
// the B-mode building inspector, so both copy the SAME amount of metadata
class BDump {
  static function gridCol(x:Float):Int return Std.int(Math.round(x / CityConfig.CELL + CityConfig.GRID / 2 - 0.5));
  static function gridRow(z:Float):Int return Std.int(Math.round(z / CityConfig.CELL + CityConfig.GRID / 2 - 0.5));
  static inline function overlap(b:Building, x0:Int, y0:Int, x1:Int, y1:Int):Bool {
    return b.col <= x1 && b.col + b.w - 1 >= x0 && b.row <= y1 && b.row + b.d - 1 >= y0;
  }

  public static function bline(i:Int, b:Building):String {
    var floors = Math.round((b.h - CityConfig.GROUND_H - CityConfig.TOP_MARGIN) / CityConfig.FLOOR_H);
    inline function arr(a:Array<Int>):String return a == null ? '[]' : '[' + a.join(',') + ']';
    // shadow trace: covered = where a same-height neighbour abuts, so the parapet
    // (and its contact shadow) is removed there. dir 0/1 intervals run along x at
    // z=zMax/zMin; dir 2/3 along z at x=xMax/xMin. an edge fully listed = no wall;
    // empty = full wall+shadow; partial = wall+shadow only on the exposed gaps
    inline function ivs(a:Array<{a:Float, b:Float}>):String return a.length == 0 ? 'none' : [for (iv in a) '${Math.round(iv.a)}..${Math.round(iv.b)}'].join('+');
    var cov = render.world.Geom.coveredEdges(b);
    var shadow = ' shadowCut[+z=${ivs(cov[0])} -z=${ivs(cov[1])} +x=${ivs(cov[2])} -x=${ivs(cov[3])}]';
    return '#$i col=${b.col} row=${b.row} w=${b.w} d=${b.d} floors=$floors facade=${b.facade % 2 == 1 ? 'brick' : 'plain'} roof=${b.roof} shapeKeep=${b.shapeKeep} winForce=${arr(b.winForce)} winBlock=${arr(b.winBlock)} skipWindowFloor=${b.skipWindowFloor} shop=${b.shop} open=${b.shopOpen} door=${b.shopDoor}$shadow';
  }

  // text dump of the tile map + buildings within radius r (world units) of (x,z)
  public static function shape(type:String, city:City, seed:Int, x:Float, z:Float, r:Float):String {
    var cx = gridCol(x), cy = gridRow(z);
    var cells = Std.int(Math.ceil(r / CityConfig.CELL)) + 2;
    if (cells < 6) cells = 6;
    var x0 = Std.int(Math.max(0, cx - cells)), x1 = Std.int(Math.min(CityConfig.GRID - 1, cx + cells));
    var y0 = Std.int(Math.max(0, cy - cells)), y1 = Std.int(Math.min(CityConfig.GRID - 1, cy + cells));
    var lines = ['bldg is type $type and looks like this:', 'seed: $seed', 'center: col=$cx row=$cy x=$x z=$z r=$r', 'legend: # building, = road, . walkway, space alley'];
    for (rr in y0...y1 + 1) {
      var s = '';
      for (c in x0...x1 + 1) s += switch (city.tiles[rr][c]) {
        case Tile.Building: '#';
        case Tile.Road: '=';
        case Tile.Walkway: '.';
        case Tile.Alley: ' ';
      }
      lines.push(s);
    }
    lines.push('near buildings:');
    for (i in 0...city.buildings.length) if (overlap(city.buildings[i], x0, y0, x1, y1)) lines.push(bline(i, city.buildings[i]));
    return lines.join('\n');
  }
}
