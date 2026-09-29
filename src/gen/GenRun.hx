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
  // --size WxH, or -1 to roll the two axes as the game does
  static var forceW = -1;
  static var forceH = -1;

  static function main()
    {
      argv = js.Syntax.code("process.argv");
      var count = intArg('--count', 200);
      var seed0 = intArg('--seed', 1);
      var type = strArg('--type', 'facility');
      var verbose = has('--print');
      // the size the live trace prints, so `--seed n --size 65x50` replays one compound from a game
      var size = strArg('--size', null);
      if (size != null)
        {
          var parts = size.split('x');
          forceW = Std.parseInt(parts[0]);
          forceH = Std.parseInt(parts[1]);
        }

      // the decoration table's own invariants, checked once before any seed runs: unique frames and
      // a non-empty list for every place the facility asks for. it throws rather than reports
      Deco.selfCheck();

      log('[gen] ' + type + ': seeds ' + seed0 + '..' + (seed0 + count - 1));
      var failures = [];
      stats = new Map();
      for (i in 0...count)
        {
          var seed = seed0 + i;
          var check = new GenCheck(seed);
          if (type == 'facility')
            checkFacilityArea(seed, check, verbose);
          else if (type == 'corp')
            checkCorpArea(seed, check, verbose);
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

// assert the plots a compound was actually built on.
//
// THE TREE THE GENERATOR USED, not a second plan off a parallel stream. This used to re-run
// FacilityBlocks.plan against its own rng because build() ignored the tree entirely and laid the
// compound by arithmetic — so the two halves of a seed described different compounds and the block
// stats described one nobody ever walked in. Phase 4 made build() walk the tree, and a check that
// runs a reimplementation of the thing it is checking is worth nothing
  static function checkFacilityBlocks(ctx: GenCtx, roadNorth: Bool, check: GenCheck, verbose: Bool)
    {
      // the root's own children are the plots: the reserved road band plus whatever the quota dealt.
      // deeper nodes (the entryway) are not plots and are not part of the split's contract
      var blocks = [for (b in ctx.root.children) if (b.kind != FacilityBlocks.ROAD) b];
      var demands = FacilityBlocks.demands(roadNorth, ctx.height);
      check.splitSane(blocks, FacilityBlocks.splitProfile());
      check.inBounds(blocks, ctx.width, ctx.height);
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

      // and every node of the finished tree at any depth, which is where the room level shows up:
      // `nodes/bench` and `nodes/slot` are the furniture gate the decoration spawn count could never
      // be, because a spawn count cannot tell a bench that was never laid from one that was laid bare
      GenTree.walk(ctx.root, function(n) add('nodes/' + n.kind, 1));

      if (verbose)
        {
          log('[gen] seed ' + ctx.seed + ' roadNorth=' + roadNorth + ' blocks=' + blocks.length);
          for (b in blocks)
            log('   ' + b.kind + ' ' + b.x1 + ',' + b.y1 + '..' + b.x2 + ',' + b.y2 +
              ' (' + GenTree.width(b) + 'x' + GenTree.height(b) + ')');
        }
    }

// generate a whole compound and assert the structure the game reads back out of it.
//
// THIS RUNS THE REAL GENERATOR — gen.facility.FacilityGen.build, the same function the live path
// calls — against a gen.GenCtx with no Game behind it. Anything that reaches a `game.Game` from
// inside generation is a bug this crashes on, which is exactly the guard wanted
  static function checkFacilityArea(seed: Int, check: GenCheck, verbose: Bool)
    {
      // the same two rolls the block check makes, off a stream seeded the same way, so the two
      // halves of one seed describe one compound
      var sizeRng = Rng.mulberry32(seed);
      var w = (forceW > 0 ? forceW : dim(AREA_W, sizeRng));
      var h = (forceH > 0 ? forceH : dim(AREA_H, sizeRng));
      var ctx = new GenCtx(w, h, seed);
      var state = gen.facility.FacilityGen.build(ctx);

      // THE REFACTOR GATE, and the reason the rolls were seeded before anything was moved. Capture
      // it before a change (`make gen seeds=200 args="--digest" > before.txt`), capture it after,
      // and diff: a pure move of generation code prints the same 200 lines. Run the same command
      // twice instead and it proves the generator is deterministic at all — an unseeded roll left
      // behind, or a Map walked in hash order, moves a digest between two runs of one binary
      if (has('--digest'))
        log('seed ' + seed + ' ' + w + 'x' + h + ' ' + digest(ctx, state));

      checkFacilityBlocks(ctx, state.mainRoadNorth, check, verbose);
      check.tilesKnown(ctx);
      check.roomsSane(ctx, state.allRooms);
      check.doorsSane(ctx, state.allRooms, state.allDoors);
      check.washroomSane(state.allRooms, state.allDoors);
      check.hangarSane(ctx, state.allRooms);
      check.tablesSane(ctx);
      check.decoBlocks(ctx, state.allRooms);
      check.spawnsSane(ctx);
      check.clueSpots(ctx, state.allRooms);
      // the two things the game re-derives from the SHAPE of the grid and from nothing else
      check.gate(ctx);
      check.parkingSane(ctx);
      check.parkPath(ctx);

      // ASSERTED, not counted. This was a stat while 8% of compounds carried a room nothing could
      // walk into; game.FacilityAreaGenerator.connectRooms now cuts a door into anything the flood
      // cannot reach, so zero is the standard and a regression has to fail the gate rather than
      // move a number nobody reads
      var cut = check.reachable(ctx, state.allRooms);
      check.ok(cut.length == 0, cut.length + ' room(s) cannot be walked into, first is ' +
        (cut.length > 0 ? cut[0].x1 + ',' + cut[0].y1 + '..' + cut[0].x2 + ',' + cut[0].y2 : ''));
      // AFTER the flood and not with the other room checks: it reads GenCheck.lastSeen, which is
      // what `reachable` just filled in
      check.storageSane(ctx, state.allRooms, state.allDoors);
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

// generate a whole corp tower floor and assert the structure the game reads back out of it.
//
// THE SAME REAL GENERATOR the live path calls, against a gen.GenCtx with no Game behind it. Most of
// the invariants are the facility's verbatim, because they are about the GRID and not about the
// compound: a tile the tileset does not have, two objects in one cell, a room nothing can walk into
// and a door joining rooms that do not exist are all the same bug whichever area wrote them
  static function checkCorpArea(seed: Int, check: GenCheck, verbose: Bool)
    {
      var sizeRng = Rng.mulberry32(seed);
      var w = (forceW > 0 ? forceW : dim(AREA_W, sizeRng));
      var h = (forceH > 0 ? forceH : dim(AREA_H, sizeRng));
      var ctx = new GenCtx(w, h, seed);
      var state = gen.corp.CorpGen.build(ctx);

      if (has('--digest'))
        log('seed ' + seed + ' ' + w + 'x' + h + ' ' + corpDigest(ctx, state));

      check.tilesKnown(ctx);
      check.roomsSane(ctx, state.rooms);
      check.doorsSane(ctx, state.rooms, state.doors);
      check.corpRoutesSane(state.rooms, state.doors);
      check.spawnsSane(ctx);

      // the quota, asked of the tree the generator actually walked
      var rooms = [];
      GenTree.walk(ctx.root, function(n)
        {
          if (gen.blocks.OfficeBlock.isRoom(n.kind))
            rooms.push(n);
        });
      check.quotaMet(rooms, gen.blocks.CorpBlocks.demands());
      check.blocksFit(rooms, gen.blocks.CorpBlocks.demands());
      check.inBounds(rooms, ctx.width, ctx.height);
      check.noOverlap(rooms);
      // exactly one lift, and it is the area's only way out
      var lifts = GenTree.all(ctx.root, gen.blocks.CorpBlocks.ELEVATOR);
      check.ok(lifts.length == 1, 'corp floor has ' + lifts.length + ' lifts, want 1');
      check.ok(ctx.countSpawns('elevator') == 9,
        'lift has ' + ctx.countSpawns('elevator') + ' cells, want 9');
      check.ok(ctx.countSpawns('stairs') == 1,
        'corp floor has ' + ctx.countSpawns('stairs') + ' stairs, want 1');
      // and every room carries the role its dealt kind says it does
      for (n in rooms)
        {
          var room = null;
          for (r in state.rooms)
            if (r.id == n.roomID)
              room = r;
          check.ok(room != null && room.role == gen.blocks.CorpBlocks.roleOf(n.kind),
            'room ' + n.roomID + ' dealt ' + n.kind + ' carries role ' +
              (room == null ? 'NO ROOM' : room.role));
        }

      // the floor is entered by LIFT and by nothing else, so that is where the flood starts
      var lift = [for (s in ctx.spawns) if (s.type == 'elevator') { x: s.x, y: s.y }];
      var cut = check.reachable(ctx, state.rooms, lift);
      check.ok(cut.length == 0, cut.length + ' corp room(s) cannot be walked into, first is ' +
        (cut.length > 0 ? cut[0].x1 + ',' + cut[0].y1 + '..' + cut[0].x2 + ',' + cut[0].y2 : ''));
      add('unreachableRooms', cut.length);
      // and the per-CELL question, which is a different one — see GenCheck.floorReachable
      check.floorReachable(ctx, state.rooms);
      check.receptionSane(ctx, state.rooms);
      check.archiveSane(ctx, state.rooms);
      check.securitySane(ctx, state.rooms);

      // how much of the walkable grid the lift flood actually covered, and WHERE it stopped. a
      // tower floor is entered at one cell, so a carve that leaves half the plate behind a wall is
      // a real bug and not a rare one — the map is how you see which half
      var walkAll = tiles.Default.TILE_WALKABLE;
      var nWalk = 0, nSeen = 0;
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
      add('orphanCells', nWalk - nSeen);
      if (verbose && nSeen < nWalk)
        for (yy in 0...h)
          {
            var line = '';
            for (xx in 0...w)
              line += (walkAll[ctx.cells[xx][yy]] != 1 ? '#'
                : (check.lastSeen[xx][yy] ? 'R' : '.'));
            log('[gen] ' + line);
          }

      // HOW FULL EACH KIND OF ROOM IS, which nothing counted until the fourth defect pass and is
      // why "many rooms are pretty empty now" was invisible: `nodes/*` counts the ZONE NODES a
      // template pushed, and a node is a record of where furniture WENT and not of how much of
      // the floor it took. Unwalkable cells inside a room's rect ARE its furniture — every cell
      // of the rect is floor by construction — so this is the honest number, in percent of the
      // rect so a big sparse room cannot hide behind a small full one
      for (r in state.rooms)
        {
          var area = r.w * r.h;
          if (area <= 0)
            continue;
          var used = 0;
          for (yy in r.y1...r.y2 + 1)
            for (xx in r.x1...r.x2 + 1)
              if (walkAll[ctx.cells[xx][yy]] != 1)
                used++;
          add('furn/' + r.role, Std.int(100.0 * used / area));
          add('furnN/' + r.role, 1);
        }

      // HOW CLOSE THE FRONT DESK IS, and how many rooms could have been it. `fronts` is what the
      // reception's `must` reads, so a floor with none of them is a floor the carve gave no desk
      var fronts = 0;
      for (_ in gen.blocks.CorpBlocks.fronts)
        fronts++;
      add('reception/fronts', fronts);
      add('reception/nofront', fronts == 0 ? 1 : 0);
      for (r in state.rooms)
        if (r.role == gen.corp.CorpTemp.ROLE_RECEPTION)
          {
            add('reception/lift', Std.int(Math.abs((r.x1 + r.x2) / 2 - gen.blocks.CorpBlocks.liftX)) +
              Std.int(Math.abs((r.y1 + r.y2) / 2 - gen.blocks.CorpBlocks.liftY)));
            add('reception/counter', gen.blocks.CorpBlocks.fronts.get(r.id).length);
            add('reception/area', r.w * r.h);
            var desks = 0;
            for (x in r.x1...r.x2 + 1)
              for (y in r.y1...r.y2 + 1)
                if (state.area.getCells()[x][y] == Const.CORP_TABLE_3X1[1])
                  desks++;
            add('reception/desks', desks);
          }

      GenTree.walk(ctx.root, function(n) add('nodes/' + n.kind, 1));
      add('rooms', state.rooms.length);
      add('doors', state.doors.length);
      add('spawns/TOTAL', ctx.spawns.length);
      for (s in ctx.spawns)
        add('spawns/' + s.type, 1);

      if (verbose)
        {
          log('[gen] seed ' + seed + ' ' + w + 'x' + h + ' rooms=' + state.rooms.length +
            ' doors=' + state.doors.length + ' spawns=' + ctx.spawns.length);
          for (n in rooms)
            log('   ' + n.kind + ' ' + n.x1 + ',' + n.y1 + '..' + n.x2 + ',' + n.y2 +
              ' (' + GenTree.width(n) + 'x' + GenTree.height(n) + ')');
        }
    }

// one corp floor in one line, the same FNV-1a over the same things as the compound's digest. a
// separate function because the two states are different types and neither carries the other's
// fields; the hashing is identical on purpose so the two are read the same way
  static function corpDigest(ctx: GenCtx, state: gen.corp._CorpState): String
    {
      var h = -2128831035;
      inline function eat(v: Int)
        {
          h = h ^ v;
          h = (h + (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24)) | 0;
        }
      for (y in 0...ctx.height)
        for (x in 0...ctx.width)
          eat(ctx.cells[x][y]);
      for (s in ctx.spawns)
        {
          for (i in 0...s.type.length)
            eat(s.type.charCodeAt(i));
          eat(s.x);
          eat(s.y);
          eat(s.row == null ? -1 : s.row);
          eat(s.col == null ? -1 : s.col);
          eat(s.col2 == null ? -1 : s.col2);
        }
      for (r in state.rooms)
        {
          eat(r.id);
          eat(r.x1);
          eat(r.y1);
          eat(r.x2);
          eat(r.y2);
          eat(r.role == null ? -1 : r.role.length);
        }
      for (d in state.doors)
        {
          eat(d.x);
          eat(d.y);
          eat(d.roomID1);
          eat(d.roomID2);
        }
      return StringTools.hex(h >>> 0, 8);
    }

// one compound in one line: every cell, then every spawn, room and door in the order they were
// recorded. FNV-1a, which is not a cryptographic anything and does not need to be — it only has to
// change when the compound does, and it is fed the ORDER as well as the values so a pass that
// produces the same furniture in a different sequence still shows up
  static function digest(ctx: GenCtx, state: gen.facility._FacilityState): String
    {
      // FNV offset basis 0x811C9DC5, written signed: it does not fit a positive Int32 and Haxe
      // would type the literal Float
      var h = -2128831035;
      inline function eat(v: Int)
        {
          h = h ^ v;
          h = (h + (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24)) | 0;
        }
      for (y in 0...ctx.height)
        for (x in 0...ctx.width)
          eat(ctx.cells[x][y]);
      for (s in ctx.spawns)
        {
          for (i in 0...s.type.length)
            eat(s.type.charCodeAt(i));
          eat(s.x);
          eat(s.y);
          eat(s.row == null ? -1 : s.row);
          eat(s.col == null ? -1 : s.col);
          eat(s.col2 == null ? -1 : s.col2);
        }
      for (r in state.allRooms)
        {
          eat(r.id);
          eat(r.x1);
          eat(r.y1);
          eat(r.x2);
          eat(r.y2);
          eat(r.role == null ? -1 : r.role.length);
        }
      for (d in state.allDoors)
        {
          eat(d.x);
          eat(d.y);
          eat(d.roomID1);
          eat(d.roomID2);
        }
      return StringTools.hex(h >>> 0, 8);
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
