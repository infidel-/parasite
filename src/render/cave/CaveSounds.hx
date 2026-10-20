package render.cave;

import citygen.CityConfig;
import game.Game;
import render.AreaSounds;
import render.RenderConfig;
import render.SoundSources;
import render.sewer.SewerModel;

// the sounds of the mountain cave (sound/cave/*.mp3, see docs/sound-gen.md): the passages' bed and
// the chambers', the night wind at the mouths, water trickling at the rimstone pools and flowstone,
// the crystals' hum, and the odd drip, rock settle or bat flight, through render.AreaSounds — the
// render.sewer.SewerSounds shape. the habitat's own bed keeps playing under it through setAmbient
class CaveSounds
{
  // the beds: a passage, and the chambers the generator saved as rooms
  static var BEDS = ['cave/passage', 'cave/chamber'];

  var game:Game;
  var m:Sewer;
  var loops:AreaSounds;
  // each bed's eased level, 0..1, in BEDS order
  var bed:Array<Float>;
  // the one-shots with no source, each with its mean gap and seconds to its next roll
  var far:Array<{ key:String, gap:Float, wait:Float }>;

  public function new(game:Game, m:Sewer)
    {
      this.game = game;
      this.m = m;
      // the cave mouths, where the wind comes in
      var exits = [];
      for (o in game.area.getObjects())
        if (o.type == 'habitat_exit')
          exits.push({ col: o.x, row: o.y });
      // the dressing's cells by piece, off the same deal render.cave.CaveProps builds
      var cells = new Map<String, Array<{ col:Int, row:Int }>>();
      var places = CaveProps.places(m);
      for (i in 0...places.length)
        cells[CaveStyle.PROP_MODELS[i].path] = [for (p in places[i]) CityConfig.worldToCell(p.x, p.z)];
      var mdl = RenderConfig.MODELS;
      var water = cells[mdl.caveRimstone].concat(cells[mdl.caveFlowstone]);
      loops = new AreaSounds(game, [
        { key: 'cave/mouth', range: 5, cells: exits },
        { key: 'cave/seep', range: 2, cells: water },
        { key: 'cave/hum', range: 3, cells: cells[mdl.caveCrystals] },
      ], [
        // a drip off the stalagmites (which it built) and the wet pieces
        {
          key: 'cave/drip',
          range: 4,
          gap: 12,
          cells: cells[mdl.caveStalagmites].concat(water),
        },
        // a settle off the fallen rock and the mouths' scree slopes
        {
          key: 'cave/scree',
          range: 8,
          gap: 60,
          cells: cells[CaveStyle.RUBBLE].concat(exits),
        },
      ]);
      far = [
        { key: 'cave/bats', gap: 90, wait: 0 },
      ];
      for (f in far)
        f.wait = f.gap * Math.random();
      bed = [for (_ in BEDS) 0.0];
      SoundSources.beds = BEDS.copy();
      SoundSources.events = [for (f in far) f.key];
    }

// per frame: the loops and events, the passage or chamber bed crossfaded over four BASE_MS, and the
// sourceless one-shots at full, heard wherever the player stands
  public function tick(pc:Int, pr:Int, dtMs:Float):Void
    {
      loops.tick(pc, pr, dtMs);
      var on = (SewerModel.isFloor(m, pc, pr) &&
        m.room[pr][pc] ? 1 : 0);
      var kb = Math.min(1, dtMs / (RenderConfig.BASE_MS * 4));
      for (i in 0...BEDS.length)
        {
          bed[i] += ((i == on ? 1.0 : 0.0) - bed[i]) * kb;
          game.scene.sounds.updateLoop(BEDS[i], bed[i], game.config.ambientVolume);
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
