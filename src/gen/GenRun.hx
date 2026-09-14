// headless area generation, for checking a generator without launching the game
//
// the entry point of ../bin/genrun.js, driven by tools/genrun.mjs. It runs the real generator over a
// range of seeds and asserts gen.GenCheck's invariants on every result, so a change to layout can be
// validated in a second at the terminal instead of by building, reloading, loading a save and
// walking across a compound to look.
//
// WHY THIS CAN RUN AT ALL, and the rule that keeps it running: the generator does not touch
// game.Game. Booting one headless reaches ui.UI -> MainMenu -> MainMenuGL -> `new Image()` and WebGL
// within three frames of the constructor, which is not stubbable in any way worth maintaining. The
// generator instead writes into a gen._GenCtx and records object SPAWNS rather than constructing
// AreaObjects, and gen.GenSpawner turns those into real objects on the live path only. Keep it that
// way: the moment something in gen/ reaches for a Game, this stops working.
//
// the browser globals the bundle's class-static initializers touch on load (THREE, window, document)
// are stubbed by the runner, not here — see tools/genrun.mjs.

package gen;

import gen.blocks.FacilityBlocks;

class GenRun
{
  // const.WorldConst's AREA_FACILITY, copied rather than read: reaching WorldConst pulls in the
  // world tables and the AI mixes with them, and two Ints are not worth that
  static inline var AREA_W = 75;
  static inline var AREA_H = 60;

// the size a facility is ACTUALLY generated at.
//
// game.AreaGame.initPost does `info.width - 10 + 10 * Std.random(2)` for every area type except
// habitat and city, and it rolls the two axes SEPARATELY — so a facility is 65 or 75 wide by 50 or
// 60 tall, four combinations, and the WorldConst dimensions are the largest of them rather than the
// size. Checking only 75x60 tests a quarter of the game, and 65x50 is a third less ground to fit
// the same quota into
  static inline function dim(base: Int, rng: Void -> Float): Int
    return base - 10 + 10 * Rng.int(rng, 2);

  static var argv: Array<String>;

  static function main()
    {
      argv = js.Syntax.code("process.argv");
      var count = intArg('--count', 200);
      var seed0 = intArg('--seed', 1);
      var type = strArg('--type', 'facility');
      var verbose = has('--print');

      log('[gen] ' + type + ': seeds ' + seed0 + '..' + (seed0 + count - 1));
      var failures = [];
      stats = new Map();
      for (i in 0...count)
        {
          var seed = seed0 + i;
          var check = new GenCheck(seed);
          if (type == 'facility')
            {
              checkFacilityBlocks(seed, check, verbose);
              checkFacilityArea(seed, check, verbose);
            }
          else
            {
              log('[gen] unknown --type: ' + type);
              exit(2);
              return;
            }
          for (f in check.failures)
            failures.push(f);
        }
      if (has('--stats'))
        dumpStats(count);

      if (failures.length == 0)
        {
          log('[gen] OK: ' + count + ' seeds, no failures');
          return;
        }
      // capped, because one broken invariant fails every seed and a wall of identical lines buries
      // whatever else also broke
      log('[gen] FAILED: ' + failures.length + ' across ' + count + ' seeds');
      for (i in 0...(failures.length < 20 ? failures.length : 20))
        log('  ' + failures[i]);
      if (failures.length > 20)
        log('  ... and ' + (failures.length - 20) + ' more');
      exit(1);
    }

// split and deal one compound's plots, and assert the result is something the fillers could build.
// this is the whole of the area-level tree — the fillers themselves land in a later phase, and the
// point of checking it separately is that a bad SPLIT and a bad FILL look identical in the game
  static function checkFacilityBlocks(seed: Int, check: GenCheck, verbose: Bool)
    {
      var rng = Rng.mulberry32(seed);
      var w = dim(AREA_W, rng);
      var h = dim(AREA_H, rng);
      var roadNorth = Rng.chance(rng, 50);

      var blocks = FacilityBlocks.plan(w, h, roadNorth, rng);
      var demands = FacilityBlocks.demands(roadNorth);
      check.splitSane(blocks, FacilityBlocks.splitProfile());
      check.inBounds(blocks, w, h);
      check.noOverlap(blocks);
      check.quotaMet(blocks, demands);
      check.blocksFit(blocks, demands);

      add('planTries', FacilityBlocks.lastPlanTries);
      if (FacilityBlocks.lastPlanTries > 1)
        add('planRetried', 1);
      for (b in blocks)
        {
          add('blocks/' + b.kind, 1);
          add('cells/' + b.kind, GenTree.width(b) * GenTree.height(b));
        }
      add('blocks/TOTAL', blocks.length);

      if (verbose)
        {
          log('[gen] seed ' + seed + ' roadNorth=' + roadNorth + ' blocks=' + blocks.length);
          for (b in blocks)
            log('   ' + b.kind + ' ' + b.x1 + ',' + b.y1 + '..' + b.x2 + ',' + b.y2 +
              ' (' + GenTree.width(b) + 'x' + GenTree.height(b) + ')');
        }
    }

// generate a whole compound and assert the structure the game reads back out of it.
//
// THIS RUNS THE REAL GENERATOR — game.FacilityAreaGenerator.build, the same function the live path
// calls — against a gen.GenCtx with no Game behind it. Constructing it with two nulls is safe
// because its constructor only builds the temp->final tile map; anything that reaches `game` from
// inside generation is a bug this crashes on, which is exactly the guard wanted
  static function checkFacilityArea(seed: Int, check: GenCheck, verbose: Bool)
    {
      // the same two rolls the block check makes, off a stream seeded the same way, so the two
      // halves of one seed describe one compound
      var sizeRng = Rng.mulberry32(seed);
      var w = dim(AREA_W, sizeRng);
      var h = dim(AREA_H, sizeRng);
      var ctx = new GenCtx(w, h, seed);
      var state = new game.FacilityAreaGenerator(null, null).build(ctx);

      check.tilesKnown(ctx);
      check.roomsSane(ctx, state.allRooms);
      check.doorsSane(ctx, state.allRooms, state.allDoors);
      check.spawnsSane(ctx);
      check.clueSpots(ctx, state.allRooms);

      // ASSERTED, not counted. This was a stat while 8% of compounds carried a room nothing could
      // walk into; game.FacilityAreaGenerator.connectRooms now cuts a door into anything the flood
      // cannot reach, so zero is the standard and a regression has to fail the gate rather than
      // move a number nobody reads
      var cut = check.reachable(ctx, state.allRooms);
      check.ok(cut.length == 0, cut.length + ' room(s) cannot be walked into, first is ' +
        (cut.length > 0 ? cut[0].x1 + ',' + cut[0].y1 + '..' + cut[0].x2 + ',' + cut[0].y2 : ''));
      add('unreachableRooms', cut.length);
      if (cut.length > 0)
        {
          add('areasWithUnreachableRoom', 1);
          if (verbose)
            for (r in cut)
              {
                var walk = tiles.Default.TILE_WALKABLE;
                var ds = [for (d in state.allDoors)
                  if (d.roomID1 == r.id || d.roomID2 == r.id)
                    d.x + ',' + d.y + ' tile=' + ctx.cells[d.x][d.y] +
                      (walk[ctx.cells[d.x][d.y]] == 1 ? ' WALK' : ' BLOCKED') +
                      ' -> ' + d.roomID1 + '/' + d.roomID2 + (d.skip ? ' SKIP' : '')];
                var freeCells = 0;
                for (yy in r.y1...r.y2 + 1)
                  for (xx in r.x1...r.x2 + 1)
                    if (walk[ctx.cells[xx][yy]] == 1)
                      freeCells++;
                // the 5x5 around each of this room's doors, as walkability, to show what is
                // standing in the way
                for (d in state.allDoors)
                  {
                    if (d.roomID1 != r.id && d.roomID2 != r.id)
                      continue;
                    var rows = [];
                    for (yy in d.y - 2...d.y + 3)
                      {
                        var line = '';
                        for (xx in d.x - 2...d.x + 3)
                          {
                            if (xx < 0 || yy < 0 || xx >= ctx.width || yy >= ctx.height)
                              line += '?';
                            else if (walk[ctx.cells[xx][yy]] != 1)
                              line += '#';
                            else if (xx == d.x && yy == d.y)
                              line += (check.lastSeen[xx][yy] ? 'D' : 'd');
                            else line += (check.lastSeen[xx][yy] ? 'R' : '.');
                          }
                        rows.push(line);
                      }
                    log('[gen]   door ' + d.x + ',' + d.y + ' ' + rows.join(' / '));
                  }
                log('[gen] seed ' + seed + ' SEALED room ' + r.id + ' ' + r.x1 + ',' + r.y1 +
                  '..' + r.x2 + ',' + r.y2 + ' role=' + r.role + ' walkableCells=' + freeCells +
                  '/' + (r.w * r.h) + ' doors=[' + ds.join(' | ') + ']');
              }
        }

      // how much of the walkable grid the flood actually covered. if this is not close to 1 the
      // check itself is wrong, not the generator
      var walkAll = tiles.Default.TILE_WALKABLE;
      var nWalk = 0;
      var nSeen = 0;
      for (yy in 0...h)
        for (xx in 0...w)
          {
            if (walkAll[ctx.cells[xx][yy]] != 1)
              continue;
            nWalk++;
            if (check.lastSeen[xx][yy])
              nSeen++;
          }
      add('walkableCells', nWalk);
      add('reachedCells', nSeen);

      add('rooms', state.allRooms.length);
      add('doors', state.allDoors.length);
      add('spawns/TOTAL', ctx.spawns.length);
      for (s in ctx.spawns)
        add('spawns/' + s.type, 1);
      var roomCells = 0;
      for (r in state.allRooms)
        roomCells += r.w * r.h;
      add('cells/rooms', roomCells);

      if (verbose)
        log('[gen] seed ' + seed + ' rooms=' + state.allRooms.length +
          ' doors=' + state.allDoors.length + ' spawns=' + ctx.spawns.length);
    }

// --- aggregate stats. what a phase gate diffs against the phase before it: a layout change that
// was supposed to be cosmetic and moved the room-count distribution shows up here and nowhere else

  static var stats: Map<String, Int>;

  static function add(key: String, n: Int)
    stats.set(key, (stats.exists(key) ? stats.get(key) : 0) + n);

  static function dumpStats(count: Int)
    {
      var keys = [for (k in stats.keys()) k];
      keys.sort(Reflect.compare);
      log('[gen] stats over ' + count + ' seeds (mean per area):');
      for (k in keys)
        {
          var mean = stats.get(k) / count;
          log('  ' + pad(k, 22) + ' ' + Math.round(mean * 100) / 100);
        }
    }

  static function pad(s: String, n: Int): String
    {
      while (s.length < n)
        s += ' ';
      return s;
    }

// --- argv helpers. node, not Sys: this is a js target and Sys is not available on it ---

  static function has(name: String): Bool
    {
      for (a in argv)
        if (a == name)
          return true;
      return false;
    }

  static function strArg(name: String, def: String): String
    {
      for (i in 0...argv.length)
        if (argv[i] == name &&
            i + 1 < argv.length)
          return argv[i + 1];
      return def;
    }

  static function intArg(name: String, def: Int): Int
    {
      var s = strArg(name, null);
      if (s == null)
        return def;
      var v = Std.parseInt(s);
      return (v == null ? def : v);
    }

  static inline function log(s: String)
    js.Syntax.code("console.log({0})", s);

  static inline function exit(code: Int)
    js.Syntax.code("process.exitCode = {0}", code);
}
