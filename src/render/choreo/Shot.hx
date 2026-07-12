package render.choreo;

import three.Three;
import citygen.CityConfig;
import entities.Entity;
import render.RenderConfig;

// gun-shot choreography: a blooming tracer races muzzle->impact with a muzzle flash + light, and on
// landing fires the impact beat (blood + hit/miss sound). fires per-weapon pellets (pistol 1, rifle 3
// staggered, shotgun 5 spread); only the first pellet carries the beat so blood/sound happen once.
// player shots kick the camera. also leaves persisted wall bullet-holes on masonry misses
class Shot {
  public static var DEBUG_HOLES = false; // [wallhole] trace each wall tracer impact + hole decision (toggle: `perf hole`)

// choreograph a shot. returns true if the view took over (caller then skips the 2D tracer); false
// when no shooter actor (caller keeps its own handling)
  public static function play(c:Choreo, atkE:Entity, sx:Int, sy:Int, tx:Int, ty:Int,
      hit:Bool, spawnBlood:Bool, bloodRow:Int, bloodCol:Int, soundKind:String, byPlayer:Bool):Bool
    {
      if (atkE == null)
        return false;
      var S = RenderConfig.SHOT;
      var C = CityConfig.CELL;
      // muzzle + impact at chest height (the blood-burst convention)
      var mw = CityConfig.cellToWorld(sx, sy);
      var iw = CityConfig.cellToWorld(tx, ty);
      var muzzleY = render.world.WorldCtx.floorY(sx, sy) + render.particles.Sprites.SIZE * 0.4;
      var impactY = render.world.WorldCtx.floorY(tx, ty) + render.particles.Sprites.SIZE * 0.4;
      // small random offset applied to both tracer ends (full on x/z, half on y) so pellets/shots
      // don't all share one exact muzzle->impact line
      var jit = function() return S.tracerJitter * C * (Math.random() - 0.5);
      // muzzle light only for near-camera shots (pooled, constant count); distant shots in a
      // 50-NPC firefight get just the emissive flash quad, no light
      if (Math.abs(sx - c.game.playerArea.x) <= S.lightRangeCells &&
          Math.abs(sy - c.game.playerArea.y) <= S.lightRangeCells)
        c.actors.muzzleFlash(mw.x, muzzleY, mw.z);
      // per-weapon pellet pattern + tracer style
      var kind = (soundKind == 'attack-shotgun' ? S.kinds.shotgun :
        (soundKind == 'attack-assault-rifle' ? S.kinds.rifle :
        (soundKind == 'attack-stun-rifle' ? S.kinds.stun : S.kinds.pistol)));
      // the impact beat: on a hit, the usual hit shake on the struck AI (looked up at impact
      // time) + blood away from the shooter (real bullets only — a stun bolt draws none) + the
      // hit sound; on a miss, just the miss sound (spark handled per-pellet)
      var onImpact = function() {
        if (hit)
          {
            var ai = c.game.area.getAI(tx, ty);
            if (ai != null &&
                ai.entity != null)
              c.actors.hitShake(ai.entity);
            if (kind.bullet)
              c.actors.burst(tx, ty, tx - sx, ty - sy, bloodRow, bloodCol);
            // energy bolt: a blue sparkle spray off the struck target instead of blood; origin
            // pulled toward the shooter so sparks fly in front of the actor sprite, not behind it
            else
              {
                var bx = mw.x - iw.x, bz = mw.z - iw.z;
                var bl = Math.sqrt(bx * bx + bz * bz);
                if (bl < 0.001) bl = 1;
                var pull = C * 0.3;
                c.actors.sparkBurst(iw.x + bx / bl * pull, impactY, iw.z + bz / bl * pull,
                  bx, bz, 0, kind.color);
              }
            c.game.scene.sounds.play('attack-bullet-hit', { always: true, x: tx, y: ty });
          }
        else c.game.scene.sounds.play('attack-bullet-miss', { always: true, x: tx, y: ty });
      };
      // base impact: a hit stops at the target cell (flesh, no spark); a miss flies on to the
      // first wall along its path (spark there) or fades at max range (off-camera, no spark)
      var baseX = iw.x, baseY = impactY, baseZ = iw.z;
      // stun bolt hit: stop at the body front (same pull as the sparkle spray) so the slow wide
      // shaft doesn't cross the actor's sprite plane and render behind it
      if (hit &&
          !kind.bullet)
        {
          var bx = mw.x - iw.x, bz = mw.z - iw.z;
          var bl = Math.sqrt(bx * bx + bz * bz);
          if (bl < 0.001) bl = 1;
          baseX += bx / bl * C * 0.3;
          baseZ += bz / bl * C * 0.3;
        }
      var sparkAtEnd = false;
      var wallCol = -1, wallRow = -1; // struck wall cell (for the bullet-hole decal), -1 = none
      var wallFromCol = -1, wallFromRow = -1; // last open cell before the hit = the exposed face
      if (!hit)
        {
          // skew the aim 1-2 tiles sideways (perpendicular to the shot line) so the missed
          // tracer visibly flies past the target instead of straight through the body
          var pdx = tx - sx, pdy = ty - sy;
          var pl = Math.sqrt(pdx * pdx + pdy * pdy);
          if (pl < 0.001) pl = 1;
          var off = (Math.random() < 0.5 ? -1 : 1) * (1 + Std.int(Math.random() * 2));
          var e = c.game.area.rayToWall(sx, sy,
            Math.round(tx - pdy / pl * off), Math.round(ty + pdx / pl * off), kind.range);
          var ew = CityConfig.cellToWorld(e.col, e.row);
          baseX = ew.x; baseZ = ew.z;
          baseY = render.world.WorldCtx.floorY(e.col, e.row) + render.particles.Sprites.SIZE * 0.4;
          sparkAtEnd = e.wall;
          if (holeDebug() && !e.wall)
            trace('[wallhole] miss FADED at cell(' + e.col + ',' + e.row + ') range=' + kind.range + ' — no wall in range, no spark/hole');
          // a wall tile's center sits inside the opaque wall (occludes the spark) -> pull the
          // endpoint back half a cell along the ray so the tracer/spark land on the near face
          if (e.wall)
            {
              var dxm = baseX - mw.x, dzm = baseZ - mw.z;
              var dl = Math.sqrt(dxm * dxm + dzm * dzm);
              if (dl > 0.001)
                {
                  baseX -= dxm / dl * C * 0.5;
                  baseZ -= dzm / dl * C * 0.5;
                }
              wallCol = e.col; wallRow = e.row;
              wallFromCol = e.fromCol; wallFromRow = e.fromRow;
              // wall-hit sound at impact time: corrugated steel (facade 3) rings metal, all
              // masonry (concrete/brick/stone) reads as one stone thud
              var metal = wallFacade(e.col, e.row) == 3;
              if (holeDebug())
                trace('[wallhit] cell(' + e.col + ',' + e.row + ') facade=' + wallFacade(e.col, e.row) + ' sound=' + (metal ? 'fx-wall-metal' : 'fx-wall-stone'));
              c.game.scene.sounds.play(metal ? 'fx-wall-metal' : 'fx-wall-stone',
                { always: true, delay: Std.int(S.travelMs * kind.travelMult), x: e.col, y: e.row });
            }
        }
      for (i in 0...kind.pellets)
        {
          // spread jitters each pellet's visual impact (blood still lands on the true tile)
          var jx = kind.spread * C * (Math.random() - 0.5);
          var jz = kind.spread * C * (Math.random() - 0.5);
          var jy = 0.0;
          // wall miss: extra shared scatter so successive tracers/sparks/holes at one wall
          // spread out (and stay aligned with each other) instead of piling on one point
          if (sparkAtEnd)
            {
              var ws = RenderConfig.WALLHOLE.spread * C;
              jx += ws * (Math.random() - 0.5);
              jz += ws * (Math.random() - 0.5);
              jy = RenderConfig.WALLHOLE.vspread * C * (Math.random() - 0.5); // smaller vertical spread
            }
          var muz = new Vector3(mw.x + jit(), muzzleY + jit() * 0.5, mw.z + jit());
          var ex = baseX + jx + jit(), ez = baseZ + jz + jit();
          var impact = new Vector3(ex, baseY + jy + jit() * 0.5, ez);
          c.actors.shot(muz, impact, i * kind.stagger, kind, i == 0 ? onImpact : null);
          // wall strike: spray sparks back off the wall once the tracer arrives
          if (sparkAtEnd)
            c.actors.sparkBurst(ex, baseY, ez, mw.x - ex, mw.z - ez,
              i * kind.stagger + S.travelMs * kind.travelMult,
              kind.bullet ? null : kind.color);
          // and leave a persisted hole at the PRIMARY pellet's exact impact so hole and tracer
          // line up (bare walls only; scatters shot-to-shot via the same jitter as the tracer;
          // real bullets only — a stun bolt leaves no hole)
          if (sparkAtEnd && i == 0 && kind.bullet)
            spawnBulletHole(c, wallFromCol, wallFromRow, wallCol, wallRow, muz, impact);
        }
      // recoil: kick the camera back along the shot (player's own shots only)
      if (byPlayer)
        c.rig.kick(sx - tx, sy - ty);
      return true;
    }

// facade material (0 concrete,1 brick,2 stone,3 metal) of the building owning wall cell (col,row);
// -1 if no building owns it. used to pick the wall-hit sound
  static function wallFacade(col:Int, row:Int):Int
    {
      for (b in render.world.WorldCtx.buildings)
        if (col >= b.col &&
            col < b.col + b.w &&
            row >= b.row &&
            row < b.row + b.d)
          return b.facade;
      return -1;
    }

// leave a persisted bullet-hole decal on the wall cell (wcol,wrow) struck by a shot. (muz,impact)
// are the pellet-0 tracer endpoints; the hole lands where that segment actually crosses the struck
// face plane (true entry point — correct for angled shots, not just head-on). (fromCol,fromRow) is
// the last OPEN cell before the hit — the exposed face the ray entered through. gated off glass:
// skips shops + the ground-floor storefront band; skipped if not a building
  static function spawnBulletHole(c:Choreo, fromCol:Int, fromRow:Int, wcol:Int, wrow:Int, muz:Vector3, impact:Vector3):Void
    {
      // struck face: pick the side of the wall cell whose NEIGHBOUR is actually open (exposed),
      // toward the cell the ray came from. a diagonal entry (delta (1,1)) has two candidate axes —
      // faceToward would tie-break to an axis whose neighbour is still solid (interior boundary);
      // choosing the axis with an open neighbour lands the hole on the real outer surface
      var ddx = fromCol - wcol, ddy = fromRow - wrow;
      var xOpen = ddx != 0 && c.game.area.canSeeThrough(wcol + (ddx > 0 ? 1 : -1), wrow);
      var zOpen = ddy != 0 && c.game.area.canSeeThrough(wcol, wrow + (ddy > 0 ? 1 : -1));
      var dir = (xOpen && zOpen) ? render.world.Geom.faceToward(ddx, ddy) // convex corner: dominant axis
        : xOpen ? (ddx > 0 ? 2 : 3)
        : zOpen ? (ddy > 0 ? 0 : 1)
        : render.world.Geom.faceToward(ddx, ddy);                         // fallback (shouldn't hit)
      // which building owns this wall cell
      var b = null;
      for (bb in render.world.WorldCtx.buildings)
        if (wcol >= bb.col &&
            wcol < bb.col + bb.w &&
            wrow >= bb.row &&
            wrow < bb.row + bb.d)
          {
            b = bb;
            break;
          }
      var dbg = holeDebug();
      var where = 'cell(' + wcol + ',' + wrow + ') dir=' + dir + ' [0=+z 1=-z 2=+x 3=-x]';
      // holes land on any masonry wall that isn't glass: skip single-story shops and the
      // ground-floor storefront band (the glass facade). plain street fronts + alley/back walls
      // both qualify — holes sit at chest height, below the upper-floor windows
      if (b == null)
        {
          if (dbg)
            trace('[wallhole] ' + where + ' -> SKIP: no building owns this cell (opaque tile/object, not a building)');
          return;
        }
      var bc = CityConfig.cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
      var hw = b.w * CityConfig.CELL / 2, hd = b.d * CityConfig.CELL / 2;
      var info = ' bldg(col=' + b.col + ' row=' + b.row + ' w=' + b.w + ' d=' + b.d + ' facade=' + b.facade
        + ' shop=' + b.shop + ' worn=' + render.world.Geom.isWornFace(b, dir)
        + ' storefront=' + render.world.Geom.storefrontFace(b, dir) + ') box x['
        + fnum(bc.x - hw) + '..' + fnum(bc.x + hw) + '] z[' + fnum(bc.z - hd) + '..' + fnum(bc.z + hd) + ']';
      if (b.shop >= 0)
        {
          if (dbg)
            trace('[wallhole] ' + where + info + ' -> SKIP: single-story shop');
          return;
        }
      if (render.world.Geom.storefrontFace(b, dir))
        {
          if (dbg)
            trace('[wallhole] ' + where + info + ' -> SKIP: storefront (glass) face');
          return;
        }
      // intersect the pellet-0 tracer segment (muz -> impact) with the struck cell's OUTER face
      // plane: this is where the trail visually enters the wall — correct for angled shots, unlike
      // snapping the normal axis while keeping the impact's (ray-pulled-back) tangential coord
      var dv = render.world.Geom.DIRV[dir];
      var half = CityConfig.CELL / 2;
      var cc = CityConfig.cellToWorld(wcol, wrow);
      var normalPos = (dir >= 2) ? cc.x + dv[0] * half : cc.z + dv[1] * half; // face plane on the normal axis
      var n0 = (dir >= 2) ? muz.x : muz.z;       // tracer normal-axis coord at muzzle
      var n1 = (dir >= 2) ? impact.x : impact.z; // and at impact
      var t = (Math.abs(n1 - n0) > 0.001) ? (normalPos - n0) / (n1 - n0) : 1.0;
      t = Math.max(0.0, Math.min(1.0, t));       // clamp to the segment
      var hy = muz.y + t * (impact.y - muz.y);   // entry height along the trail
      var hx = (dir >= 2) ? normalPos : muz.x + t * (impact.x - muz.x);
      var hz = (dir >= 2) ? muz.z + t * (impact.z - muz.z) : normalPos;
      // clamp the along-face (tangential) coord to the building box so a grazing/near-corner trail
      // can't put the hole past the wall edge into the air
      var m = 0.35;
      if (dir >= 2) hz = Math.max(bc.z - hd + m, Math.min(bc.z + hd - m, hz));
      else hx = Math.max(bc.x - hw + m, Math.min(bc.x + hw - m, hx));
      // store as a sub-cell dx/dy offset (invert cellToWorld) so the draw reproduces this point
      var T = Const.TILE_SIZE;
      var dx = Std.int((hx / CityConfig.CELL + CityConfig.GRID / 2 - 0.5 - wcol) * T);
      var dy = Std.int((hz / CityConfig.CELL + CityConfig.GRID / 2 - 0.5 - wrow) * T);
      var W = RenderConfig.WALLHOLE;
      c.game.area.addTileDecoration(wcol, wrow,
        {
          layerID: -1,
          tag: 'WALLHOLE',
          face: dir,
          height: hy,
          metal: b.facade == 3, // metal warehouse -> steel-dent hole set
          angle: Math.random() * Math.PI * 2,
          scale: W.scale + (Math.random() - 0.5) * 2 * W.scaleVar,
          dx: dx,
          dy: dy,
        });
      if (dbg) trace('[wallhole] ' + where + info + ' -> HOLE on face at world(' + fnum(hx) + ',' + fnum(hy) + ',' + fnum(hz)
        + ') | ray muz(' + fnum(muz.x) + ',' + fnum(muz.y) + ',' + fnum(muz.z) + ') -> impact(' + fnum(impact.x) + ',' + fnum(impact.y) + ',' + fnum(impact.z)
        + ') facePlane=' + fnum(normalPos) + ' t=' + fnum(t));
    }

// [wallhole] debug on? toggled by the `perf hole` console command
  static inline function holeDebug():Bool
    return DEBUG_HOLES;

// one-decimal number for compact traces
  static inline function fnum(v:Float):String
    return '' + Std.int(v * 10) / 10;
}
