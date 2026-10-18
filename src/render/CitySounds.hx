package render;

import citygen.CityModel;
import game.Game;
import render.AreaSounds;
import render.RenderConfig;
import render.SoundSources;

// the sounds of a city street area (sound/city/*.mp3, see docs/sound-gen.md): each tier — slums,
// medium, downtown — has its own three beds and its own one-shots, over the loops the street's
// buildings and objects carry (open shops, warehouses, sewer hatches, the slums' failing lamps and
// barrel fires), faded by path distance in render.AreaSounds
class CitySounds
{
  // the beds per tier: the main road, a side street, an alley
  static var BEDS:Map<_AreaType, Array<String>> = [
    _AreaType.AREA_CITY_LOW => ['city/slums-main', 'city/slums-street', 'city/slums-alley'],
    _AreaType.AREA_CITY_MEDIUM => ['city/medium-main', 'city/medium-street', 'city/medium-alley'],
    _AreaType.AREA_CITY_HIGH => ['city/downtown-main', 'city/downtown-street', 'city/downtown-alley'],
  ];
  static inline var MAIN = 0;
  static inline var STREET = 1;
  static inline var ALLEY = 2;

  var game:Game;
  var city:City;
  var loops:AreaSounds;
  var beds:Array<String>;
  // each bed's eased level, 0..1, in beds order
  var bed:Array<Float>;
  // which cells hear the main road: the 4-wide road itself and the pavement along it
  var main:Array<Array<Bool>>;
  // the tier's one-shots with no source — a horn, a helicopter, a door somewhere — each with its
  // mean gap and seconds to its next roll
  var far:Array<{ key:String, gap:Float, wait:Float }>;

  public function new(game:Game, city:City, flickCells:Array<{ col:Int, row:Int }>, flick:LightCone.ConeSet)
    {
      var style = render.world.WorldCtx.style;
      this.game = game;
      this.city = city;
      var tier = game.area.typeID;
      beds = BEDS[tier];
      if (beds == null)
        beds = BEDS[_AreaType.AREA_CITY_MEDIUM];
      main = mainCells();
      // the cells by ground kind
      var road = [];
      var alley = [];
      for (row in 0...city.tiles.length)
        for (col in 0...city.tiles[row].length)
          {
            var t:Tile = city.tiles[row][col];
            if (t == Tile.Road)
              road.push({ col: col, row: row });
            else if (t == Tile.Alley)
              alley.push({ col: col, row: row });
          }
      // the open shops by kind (0 diner, 1 corner store, 2 garage, 3 laundromat) and the metal
      // warehouses, each heard from the open cells around its footprint
      var shops = [for (_ in 0...4) []];
      var open = [];
      var warehouses = [];
      for (b in city.buildings)
        if (b.shop >= 0 &&
            b.shopOpen)
          {
            var around = aroundOf(b);
            shops[b.shop] = shops[b.shop].concat(around);
            open = open.concat(around);
          }
        // about one warehouse in three has its machinery running: a medium city has ~40 of them,
        // and every one humming covered most of the streets
        else if (b.shop < 0 &&
            style.isSpecial(b.facade) &&
            (b.col * 31 + b.row * 17) % 3 == 0)
          warehouses = warehouses.concat(aroundOf(b));
      var barrels = [];
      var hatches = [];
      for (o in game.area.getObjects())
        if (o.type == 'burning_barrel')
          barrels.push({ col: o.x, row: o.y });
        else if (o.type == 'sewer_hatch')
          hatches.push({ col: o.x, row: o.y });
      var events:Array<AreaEvent> = [];
      if (tier == _AreaType.AREA_CITY_LOW)
        {
          events = [
            { key: 'city/bottle', range: 6, gap: 40, cells: alley },
            { key: 'city/can', range: 6, gap: 35, cells: alley },
            { key: 'city/rats', range: 4, gap: 30, cells: alley },
            { key: 'city/crackle', range: 4, gap: 8, cells: barrels },
          ];
          far = [ { key: 'city/screendoor', gap: 70, wait: 0 } ];
        }
      else if (tier == _AreaType.AREA_CITY_HIGH)
        {
          events = [
            { key: 'facility/car', range: 8, gap: 15, cells: road },
          ];
          far = [
            { key: 'city/horn', gap: 25, wait: 0 },
            { key: 'city/helicopter', gap: 240, wait: 0 },
          ];
        }
      else
        {
          events = [
            { key: 'facility/car', range: 8, gap: 30, cells: road },
            { key: 'city/shopbell', range: 4, gap: 40, cells: open },
            { key: 'city/garage', range: 5, gap: 25, cells: shops[2] },
          ];
          far = [ { key: 'city/horn', gap: 60, wait: 0 } ];
        }
      for (f in far)
        f.wait = f.gap * Math.random();
      loops = new AreaSounds(game, [
        // the slums' diners and corner stores are all broken: no kitchen, no fridges, no sign
        { key: 'city/diner', range: 3, cells: (tier == _AreaType.AREA_CITY_LOW ? [] : shops[0]) },
        { key: 'city/store', range: 3, cells: (tier == _AreaType.AREA_CITY_LOW ? [] : shops[1]) },
        { key: 'city/laundromat', range: 3, cells: shops[3] },
        { key: 'city/warehouse', range: 4, cells: warehouses },
        { key: 'city/sewer', range: 2, cells: hatches },
        {
          key: 'city/lampbuzz',
          range: 2,
          cells: flickCells,
          // the buzz stops while the bulb is out: the cone set's on/off is the flicker's own state
          gate: function(i) return flick.on[i],
        },
        { key: 'ambient-fire', range: 4, cells: barrels },
      ], events);
      bed = [for (_ in beds) 0.0];
      SoundSources.beds = beds.copy();
      SoundSources.events = [for (f in far) f.key];
    }

// the main road's cells: a road cell inside some 4x4 square of road, which only the 4-wide main
// road has (a 2-wide street, and two crossing at a junction, never make one), plus the pavement
// next to one, where the player walks along it
  function mainCells():Array<Array<Bool>>
    {
      var t = city.tiles;
      var h = t.length;
      var w = t[0].length;
      var road = [for (_ in 0...h) [for (_ in 0...w) false]];
      for (r in 0...h - 3)
        for (c in 0...w - 3)
          {
            var all = true;
            for (dr in 0...4)
              for (dc in 0...4)
                if (t[r + dr][c + dc] != Tile.Road)
                  all = false;
            if (all)
              for (dr in 0...4)
                for (dc in 0...4)
                  road[r + dr][c + dc] = true;
          }
      var out = [for (_ in 0...h) [for (_ in 0...w) false]];
      for (r in 0...h)
        for (c in 0...w)
          if (road[r][c])
            out[r][c] = true;
          else if (t[r][c] == Tile.Walkway)
            for (dr in -1...2)
              for (dc in -1...2)
                if (r + dr >= 0 &&
                    c + dc >= 0 &&
                    r + dr < h &&
                    c + dc < w &&
                    road[r + dr][c + dc])
                  out[r][c] = true;
      return out;
    }

// the open cells 4-adjacent to a building's footprint: where a shop or a warehouse is heard from
  function aroundOf(b:Building):Array<{ col:Int, row:Int }>
    {
      var out = [];
      var t = city.tiles;
      for (r in b.row - 1...b.row + b.d + 1)
        for (c in b.col - 1...b.col + b.w + 1)
          {
            var inside = (r >= b.row && r < b.row + b.d && c >= b.col && c < b.col + b.w);
            var corner = ((r == b.row - 1 || r == b.row + b.d) && (c == b.col - 1 || c == b.col + b.w));
            if (inside ||
                corner ||
                r < 0 ||
                c < 0 ||
                r >= t.length ||
                c >= t[0].length ||
                t[r][c] == Tile.Building)
              continue;
            out.push({ col: c, row: r });
          }
      return out;
    }

// which bed plays at the player's cell: the main road and its pavement, any other road or
// pavement, or an alley (back yards and courtyards included)
  function bedAt(pc:Int, pr:Int):Int
    {
      if (pr < 0 ||
          pc < 0 ||
          pr >= city.tiles.length ||
          pc >= city.tiles[0].length)
        return STREET;
      if (main[pr][pc])
        return MAIN;
      return (city.tiles[pr][pc] == Tile.Alley ? ALLEY : STREET);
    }

// per frame: the loops and events, the tier's beds crossfaded over four BASE_MS, and its sourceless
// one-shots at full — they are the whole street's, heard wherever the player stands
  public function tick(pc:Int, pr:Int, dtMs:Float):Void
    {
      loops.tick(pc, pr, dtMs);
      var on = bedAt(pc, pr);
      var kb = Math.min(1, dtMs / (RenderConfig.BASE_MS * 4));
      for (i in 0...beds.length)
        {
          bed[i] += ((i == on ? 1.0 : 0.0) - bed[i]) * kb;
          game.scene.sounds.updateLoop(beds[i], bed[i], game.config.ambientVolume);
        }
      for (f in far)
        {
          f.wait -= dtMs / 1000;
          if (f.wait > 0)
            continue;
          f.wait = f.gap * (0.5 + Math.random());
          AreaSounds.once(game, f.key, 1);
        }
    }
}
