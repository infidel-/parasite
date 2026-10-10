package render.sewer;

import citygen.CityConfig;
import game.Game;
import render.AreaSounds;
import render.RenderConfig;
import render.SoundSources;
import render.particles.LampPost;
import render.sewer.SewerModel;

// the sounds of the sewers (sound/sewer/*.mp3, see docs/sound-gen.md): the tunnel's bed and the
// chambers', the street seeping down the exit shafts, trickles, pipes and failing wall lamps, and
// the odd drip, rat, pipe knock or truck overhead, through render.AreaSounds. AREA_SEWERS only:
// the habitat shares the renderer and keeps its own bed
class SewerSounds
{
  // the beds: a 3-wide tunnel, and the 5x5 chambers the generator saved as rooms
  static var BEDS = ['sewer/tunnel', 'sewer/chamber'];

  var game:Game;
  var m:Sewer;
  var loops:AreaSounds;
  // each bed's eased level, 0..1, in BEDS order
  var bed:Array<Float>;
  // the one-shots with no source, each with its mean gap and seconds to its next roll
  var far:Array<{ key:String, gap:Float, wait:Float }>;

  public function new(game:Game, m:Sewer, lampPosts:Array<LampPost>, wallGlow:render.LightCone.ConeSet)
    {
      this.game = game;
      this.m = m;
      // the exit ladders, where the street comes down
      var exits = [];
      for (o in game.area.getObjects())
        if (o.type == 'sewer_exit')
          exits.push({ col: o.x, row: o.y });
      // the water: a trickle heard from halfway down its run (its head is on the wall line), a drip
      // from any pool
      var water = SewerWater.layout(m);
      var trickles = [for (s in water.streams) cell(s[s.length >> 1].x, s[s.length >> 1].z)];
      var pools = [for (p in water.pools) cell(p.x, p.z)];
      // the pipe and cable runs dumped against the walls
      var pipes = [];
      var places = SewerProps.places(m);
      for (i in 0...places.length)
        {
          var path = SewerStyle.PROP_MODELS[i].path;
          if (path == RenderConfig.MODELS.sewerPipe ||
              path == RenderConfig.MODELS.sewerCable)
            for (p in places[i])
              pipes.push(cell(p.x, p.z));
        }
      // the sputtering wall lamps: their posts follow the node lamps in lampPosts, in the glow set's
      // order, so wall lamp i is post m.lamps.length + i and its on/off is wallGlow.on[i]
      var buzz = [];
      var buzzIdx = [];
      for (i in 0...wallGlow.phases.length)
        if (wallGlow.phases[i] > 0)
          {
            var p = lampPosts[m.lamps.length + i];
            buzz.push({ col: p.col, row: p.row });
            buzzIdx.push(i);
          }
      loops = new AreaSounds(game, [
        { key: 'sewer/manhole', range: 5, cells: exits },
        { key: 'sewer/trickle', range: 2, cells: trickles },
        { key: 'sewer/pipe', range: 3, cells: pipes },
        {
          key: 'city/lampbuzz',
          range: 2,
          cells: buzz,
          // the buzz stops while the tube is out
          gate: function(i) return wallGlow.on[buzzIdx[i]],
        },
      ], [
        { key: 'sewer/drip', range: 4, gap: 12, cells: pools },
        {
          key: 'sewer/rats',
          range: 5,
          gap: 30,
          cells: [for (d in SewerDebris.build(m)) { col: d.col, row: d.row }],
        },
        { key: 'sewer/knock', range: 6, gap: 45, cells: pipes },
        { key: 'sewer/cover', range: 8, gap: 40, cells: exits },
      ]);
      far = [
        { key: 'sewer/rumble', gap: 90, wait: 0 },
        { key: 'sewer/surge', gap: 60, wait: 0 },
      ];
      for (f in far)
        f.wait = f.gap * Math.random();
      bed = [for (_ in BEDS) 0.0];
      SoundSources.beds = BEDS.copy();
      SoundSources.events = [for (f in far) f.key];
    }

// a world point's cell
  static inline function cell(x:Float, z:Float):{ col:Int, row:Int }
    {
      return CityConfig.worldToCell(x, z);
    }

// per frame: the loops and events, the tunnel or chamber bed crossfaded over four BASE_MS, and the
// sourceless one-shots at full — the whole network's, heard wherever the player stands
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
