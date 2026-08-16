package render.sewer;

import js.Browser;
import three.Three;
import game.Game;
import citygen.CityConfig;
import render.sewer.SewerModel.Sewer;

// one exposed blocker face, in CELL units. it carries no owner cell on purpose: the blocker a ray
// stopped on is recovered from the hit POINT instead (a hair further along the ray lands inside it),
// which is more honest where two cells share an edge and saves the range-bound square a special case
typedef MaskSeg = {
  x1:Float,
  y1:Float,
  x2:Float,
  y2:Float,
}

// the tunnel VISION MASK: a top-down texture saying whether the player can see a point, sampled by
// world XZ inside every material the tunnel draws with, sinking whatever it hits toward the fog
// colour where the answer is no.
//
// this is the 3D form of the 2D view's black LOS overlay (AreaView.drawSmoothLOSOverlay), which never
// runs underground — AreaView.draw early-outs on a 3D area — so until this the level itself was drawn
// whole, corner to corner, and only its CONTENTS popped in and out. the shape is a real VISIBILITY
// POLYGON, the same ray-to-every-corner sweep the 2D overlay does, ported from screen pixels to cell
// units; a per-cell mask was tried first and replaced, because a cell grid cannot express a shadow
// edge that runs diagonally off a wall corner.
//
// it deliberately costs NO draw call, NO pass and NO geometry: the mask is one texture fetch folded
// into materials that already draw. that is what lets the whole level stay welded into the handful of
// merged meshes render.sewer.SewerGeom builds it as — a per-cell hide would have needed the weld
// broken, and chunking the tunnels was already measured and rejected (docs/3d-render.md).
//
// WHAT BLOCKS IS game.area.canSeeThrough, so a closed door blocks and the renderer's own floor grid
// is not consulted at all. the ACTORS still run on game.playerArea.sees (render.Actors), which is a
// cell-to-cell Bresenham from the player's LOGICAL cell, and they diverge from this in two accepted
// ways. one is shape: a Bresenham between cell centres and a cartesian polygon disagree within about
// a cell of a corner. the other is TIME, and it arrived with the smoothed origin below — the logical
// cell snaps at the instant an action resolves while this sweeps over the ~150ms slide, so an actor
// round a corner now leads the light that should reveal it by up to one move. both read as a soft
// lead rather than a pop, because an actor eases over FADE_SPEED instead of switching
class SewerMask
{
  // ray fan: three angles at every corner — the corner itself and a hair either side. the pair is
  // what lets a ray slip PAST a corner and find what is behind it; with the centre ray alone every
  // ray stops on the corner and the shadow behind it never opens. an ANGLE, so it ports from the 2D
  // original unchanged (AreaView.LOS_RAY_EPSILON) where distances did not
  static inline var RAY_EPS = 0.0001;
  static inline var DEDUPE_EPS = 0.0000001;
  // near-parallel / behind-the-origin reject. the 2D original's 0.0001 is in SCREEN PIXELS over
  // coordinates around 1000; this works in CELLS over coordinates around 14, so it is the same
  // relative tolerance rather than the same number
  static inline var HIT_EPS = 0.000001;
  // how far past a hit to step when recovering the blocker cell. well inside a 1-cell wall, well
  // clear of numerical noise on the face it just landed on
  static inline var STEP_EPS = 0.05;

  static var canvas:js.html.CanvasElement = null;
  static var ctx:js.html.CanvasRenderingContext2D = null;
  static var tex:CanvasTexture = null;
  static var mw = 0; // grid width in CELLS (the canvas is this times SewerStyle.MASK_PX)
  static var mh = 0;
  // the mask's GREEN channel, painted once per level: masonry or not. static, because walls do not
  // move, so it is held as a canvas and blitted in as each rebuild's clear
  static var wallLayer:js.html.CanvasElement = null;
  // the RED channel gets a canvas of its own, and that is what makes the blur possible: every rebuild
  // paints the visibility plane here and it is composited into the mask through a gaussian, so the
  // boundary widens without the green masonry channel widening with it. blurring the finished mask
  // instead would smear masonry a texel out onto open floor, and the shader gates the wobble on
  // exactly that channel
  static var scratch:js.html.CanvasElement = null;
  static var sctx:js.html.CanvasRenderingContext2D = null;
  // which cells this sweep revealed, as generation stamps rather than a cleared grid. needed twice
  // over: to stop a cell being painted by every ray that lands on it, and so a lit cell can ask
  // whether the masonry beside it was reached
  static var seen:Array<Int> = null;
  static var seenGen = 0;

  // the uniform blocks every patched material references BY IDENTITY. three stores the reference it
  // is handed in onBeforeCompile, so writing .value here reaches every material at once and an update
  // never has to walk them. two floor blocks because an ADDITIVE emissive needs a harder one than the
  // surface it sits on — see SewerStyle.MASK_HIDDEN_ADD
  static var uMap:Dynamic = { value: null };
  static var uScale:Dynamic = { value: new Vector2(0, 0) };
  static var uOrigin:Dynamic = { value: new Vector2(0, 0) };
  static var uFloor:Dynamic = { value: SewerStyle.MASK_HIDDEN };
  static var uFloorAdd:Dynamic = { value: SewerStyle.MASK_HIDDEN_ADD };
  // boundary wobble amplitude in WORLD units, pre-divided by the 1.5 the two-octave sine sum below
  // peaks at — so SewerStyle.MASK_WOBBLE reads as the maximum displacement it actually produces
  static var uWobble:Dynamic = { value: SewerStyle.MASK_WOBBLE / 1.5 };

  // dirty key: the SMOOTHED origin quantised to SewerStyle.MASK_STEP, plus the two other things that
  // can open a sightline without it moving (AreaGame.visRev, the debug reveal).
  //
  // the origin is the sliding billboard position and NOT the player's logical cell, which is what
  // makes the shadows sweep with a move instead of teleporting through it: game.playerArea.x/y snaps
  // to the destination the instant an action resolves, so a cell-centre origin ran a whole BASE_MS
  // AHEAD of the player it belonged to and swung its shadows from a cell nothing had reached yet.
  // idle still costs nothing — ActorAnim.slideTo is finite (t clamps to 1 and its whole update is
  // gated on t < 1), so a rested origin sits exactly on the cell centre and stops dead, and this key
  // stops with it rather than easing toward it forever
  static var lastKX = -1;
  static var lastKY = -1;
  static var lastRev = -1;
  static var lastLos = false;

// bind the mask to a level: the texture and the world->uv transform have to exist before anything
// samples them. MATERIALS are not touched here — every tunnel builder patches its own as it creates
// it, which is also what gives the boot pre-warm its parity for free, since render.View.warmup runs
// those same builders. it is deliberately NOT a scene traverse: the actor pool, the path line, the
// tactical grid and the batched decals all land in this same scene later, and one of them
// (render.decals.DecalBatch) carries an onBeforeCompile of its own that a blind walk would overwrite
  public static function attach(m:Sewer):Void
    {
      lastKX = -1;
      lastKY = -1;
      lastRev = -1;
      ensure(m);
      // UNCONDITIONAL, unlike ensure: two different levels can share dimensions (every habitat is
      // 21x14), so a masonry layer cached on size alone would be the previous level's walls
      buildWallLayer(m);
    }

// the mask's two STATIC channels, painted once per level and blitted in as each rebuild's clear —
// which costs one drawImage instead of a fill per cell, and keeps both of them out of MASK_BLUR.
//   GREEN: 1 where the level has masonry, 0 over open floor. the shader reads it to decide where the
//     boundary may WOBBLE — a shadow edge out on open floor is a real ray cast past a corner and has
//     to stay straight, while the same edge crossing a wall is the blocky per-cell reveal that wanted
//     breaking up. keyed off SewerModel.isFloor and NOT area.canSeeThrough: this asks "is there
//     masonry here", which is static, where canSeeThrough is object-aware and would call a door a wall
//   BLUE: the level's outer falloff (SewerStyle.MASK_EDGE_FADE), a plain multiplier on sewerVis
  static function buildWallLayer(m:Sewer):Void
    {
      var P = SewerStyle.MASK_PX;
      wallLayer = Browser.document.createCanvasElement();
      wallLayer.width = canvas.width;
      wallLayer.height = canvas.height;
      var c = wallLayer.getContext2d();
      // blue starts FULL everywhere — the rim falloff below only ever takes it away, and inland it has
      // to be an exact 1 or it would dim the whole level
      c.fillStyle = '#0000ff';
      c.fillRect(0, 0, wallLayer.width, wallLayer.height);
      // green ADDED, so masonry cannot trample the blue underneath it
      c.globalCompositeOperation = 'lighter';
      c.fillStyle = '#00ff00';
      for (row in 0...m.h)
        for (col in 0...m.w)
          if (!SewerModel.isFloor(m, col, row))
            c.fillRect(col * P, row * P, P, P);
      // then the rim, as a MULTIPLY by `rgba(255,255,0,a)`: multiply is per channel, so a source of 1
      // leaves red and green EXACTLY as painted and only the zero blue is scaled, by (1 - a). the four
      // ramps each cover the whole canvas and clamp to their far stop, so inland they are a no-op —
      // and where two meet they multiply, which drops a corner faster than an edge, as a corner should
      c.globalCompositeOperation = 'multiply';
      var f = SewerStyle.MASK_EDGE_FADE * P;
      var w = wallLayer.width;
      var h = wallLayer.height;
      rim(c, 0.5, 0, 0.5 + f, 0);
      rim(c, w - 0.5, 0, w - 0.5 - f, 0);
      rim(c, 0, 0.5, 0, 0.5 + f);
      rim(c, 0, h - 0.5, 0, h - 0.5 - f);
      c.globalCompositeOperation = 'source-over';
    }

// one side of the outer falloff. it is fully opaque at the OUTERMOST TEXEL CENTRE (the half-texel
// inset) rather than at the canvas boundary, because a linear fetch clamped to the edge returns that
// texel's value — aim the ramp at the boundary itself and the rim lands at 1/8 lit instead of 0
  static function rim(c:js.html.CanvasRenderingContext2D, x0:Float, y0:Float, x1:Float, y1:Float):Void
    {
      var g = c.createLinearGradient(x0, y0, x1, y1);
      g.addColorStop(0, 'rgba(255,255,0,1)');
      g.addColorStop(1, 'rgba(255,255,0,0)');
      c.fillStyle = g;
      c.fillRect(0, 0, wallLayer.width, wallLayer.height);
    }

// recompute the mask if anything that feeds it changed. px/pz are the player's SMOOTHED world
// position (Area3DTickOpts.player), never their logical cell — see the dirty key above for why
  public static function update(game:Game, px:Float, pz:Float):Void
    {
      // world -> CONTINUOUS cell coordinate, the space the polygon and the canvas both work in.
      // cellToWorld puts the centre of cell c at (c - GRID/2 + 0.5) * CELL, so this lands on c + 0.5
      // standing there, floor() of it is the cell the origin is in, and it is the canvas x/y over
      // MASK_PX — the same transform ensure() hands the shader, so mask and polygon cannot drift
      var ox = px / CityConfig.CELL + CityConfig.GRID / 2;
      var oy = pz / CityConfig.CELL + CityConfig.GRID / 2;
      var kx = Math.round(ox / SewerStyle.MASK_STEP);
      var ky = Math.round(oy / SewerStyle.MASK_STEP);
      var los = game.player.vars.losEnabled;
      var rev = game.area.visRev;
      if (kx == lastKX &&
          ky == lastKY &&
          rev == lastRev &&
          los == lastLos)
        return;
      lastKX = kx;
      lastKY = ky;
      lastRev = rev;
      lastLos = los;
      // hidden everywhere, then paint back what is seen — on the SCRATCH canvas, which carries the red
      // visibility plane alone. opaque black rather than a cleared canvas, because the mask is read as
      // plain channel values and leaving alpha in play would only invite the browser to premultiply
      // the antialiased polygon edge into them
      sctx.globalCompositeOperation = 'source-over';
      sctx.fillStyle = '#000000';
      sctx.fillRect(0, 0, canvas.width, canvas.height);
      // everything from here ADDS. the polygon edge antialiases into the first texel of the wall cell
      // it stopped on, and that cell may also carry an authored fade ramp — under source-over the
      // second write would replace the first instead of taking the brighter of the two
      sctx.globalCompositeOperation = 'lighter';
      sctx.fillStyle = '#ff0000';
      if (!los)
        sctx.fillRect(0, 0, canvas.width, canvas.height);
      // a free parasite has no ray vision at all — game.playerArea.sees gives it a flat 7x7 box that
      // ignores walls outright. mirrored cell by cell rather than approximated with a polygon, so the
      // level and the actors say exactly the same thing in that state
      else if (game.player.state != _PlayerState.PLR_STATE_HOST)
        box(game);
      else polygon(game, ox, oy);
      // the wall layer is the clear: black background plus the green masonry channel in one blit, and
      // it goes in UNBLURRED so the wobble gate stays a crisp per-cell edge
      ctx.globalCompositeOperation = 'source-over';
      ctx.filter = 'none';
      ctx.drawImage(wallLayer, 0, 0);
      // then the visibility plane on top, through the gaussian. ADDITIVE for the same reason as above,
      // and because it must not touch the green underneath it.
      // drawImage treats everything outside the source as transparent, so the blur pulls the outermost
      // texels down — which is right rather than incidental: those are the always-solid area border,
      // and beyond them there is no geometry at all, only the clear colour
      // MASK_BLUR is in WORLD UNITS and the filter wants TEXELS, so it converts here — otherwise
      // changing MASK_PX would silently rescale the boundary softness with it
      ctx.globalCompositeOperation = 'lighter';
      ctx.filter = 'blur(' +
        (SewerStyle.MASK_BLUR * SewerStyle.MASK_PX / CityConfig.CELL) + 'px)';
      ctx.drawImage(scratch, 0, 0);
      ctx.filter = 'none';
      ctx.globalCompositeOperation = 'source-over';
      tex.needsUpdate = true;
    }

// the parasite's boxed vision, straight off the same predicate the actors read, and painted CELL BY
// CELL rather than approximated. sees() gives a free parasite a flat 7x7 of CELLS with no occlusion
// at all, so there is no polygon edge to slide and mirroring it exactly is what keeps the level and
// the actors saying the same thing in that state — MASK_BLUR still softens the box's rim on the way
// in, which spreads it under a cell, and the mask has never been what decides visibility anyway.
// it does repaint on every frame of a slide, since the
// key above moves and this does not: 81 box tests and an 84x56 upload, both under the timer's
// resolution, which is cheaper than carrying a second dirty key to skip them
  static function box(game:Game):Void
    {
      var P = SewerStyle.MASK_PX;
      var pcol = game.playerArea.x;
      var prow = game.playerArea.y;
      for (row in prow - 4...prow + 5)
        for (col in pcol - 4...pcol + 5)
          if (game.playerArea.sees(col, row))
            sctx.fillRect(col * P, row * P, P, P);
    }

// the visibility polygon: fire a ray at every exposed blocker corner, keep the nearest hit, and the
// hits in angle order ARE the polygon. ported from AreaView.buildLOSSegments / castLOSRay /
// buildLOSVisiblePolygon, which does the same sweep in screen pixels over the 2D camera rect.
// ox/oy are CONTINUOUS cell coordinates and move sub-cell with the player's slide, so every ray in
// here already worked in floats — only the two INTEGER things below had to follow the origin
  static function polygon(game:Game, ox:Float, oy:Float):Void
    {
      var P = SewerStyle.MASK_PX;
      var R = SewerStyle.MASK_R;
      // the cell the origin actually stands in. the scan window and the own-cell skip both key off
      // THIS rather than off game.playerArea, so they stay centred on the point the rays leave from:
      // a window centred on the logical cell sits up to a cell off the origin mid-slide, and the
      // square range bound (built from ox/oy, below) would then reach past the last column scanned
      var ocol = Math.floor(ox);
      var orow = Math.floor(oy);
      var segs:Array<MaskSeg> = [];
      var angles:Array<Float> = [];
      function ray(x:Float, y:Float):Void
        {
          var a = Math.atan2(y - oy, x - ox);
          angles.push(a - RAY_EPS);
          angles.push(a);
          angles.push(a + RAY_EPS);
        }
      function seg(x1:Float, y1:Float, x2:Float, y2:Float):Void
        {
          segs.push({ x1: x1, y1: y1, x2: x2, y2: y2 });
          ray(x1, y1);
          ray(x2, y2);
        }
      // the range bound. every ray has to terminate on something and this is what catches one that
      // escapes down an open corridor; it is also what keeps the cost flat, since the whole sweep is
      // O(rays * segments) and both grow with the radius. a SQUARE rather than a disc — four segments
      // instead of an arc fan, and its corners reach R * sqrt(2), far past the ~12 cells the sewer
      // camera can show even pinned at full zoom-out (render.CameraRig.maxFootprintCells)
      seg(ox - R, oy - R, ox + R, oy - R);
      seg(ox + R, oy - R, ox + R, oy + R);
      seg(ox + R, oy + R, ox - R, oy + R);
      seg(ox - R, oy + R, ox - R, oy - R);
      for (row in orow - R...orow + R + 1)
        for (col in ocol - R...ocol + R + 1)
          {
            // the origin's own cell is transparent whatever is on it — the same rule AreaGame
            // .isVisible applies to both ends of its line, and without it a player who ends a turn in
            // a closing door stands inside a blocker and the polygon collapses to nothing. it is also
            // the net under a sliding origin: an origin inside a wall meets that wall's own faces at
            // ~zero distance, n falls under 3 and the fail-open below flashes the whole level bright
            // for a frame. ActorAnim.slideTo already routes a diagonal move as an L-path around the
            // corner (ActorAnim.cornerBend), so the origin should never leave the floor to begin with
            if (col == ocol &&
                row == orow)
              continue;
            if (game.area.canSeeThrough(col, row))
              continue;
            // only the faces that look onto see-through space. an edge buried between two solid cells
            // can never be hit and would only cost ray tests
            if (game.area.canSeeThrough(col, row - 1))
              seg(col, row, col + 1, row);
            if (game.area.canSeeThrough(col + 1, row))
              seg(col + 1, row, col + 1, row + 1);
            if (game.area.canSeeThrough(col, row + 1))
              seg(col + 1, row + 1, col, row + 1);
            if (game.area.canSeeThrough(col - 1, row))
              seg(col, row + 1, col, row);
          }
      // four rays straight down the axes, and they are a FIX rather than a refinement. every other ray
      // is aimed at a CORNER, and the blocker one stopped on is recovered by stepping past the hit — so
      // a corner LEFT of the origin reveals the cell to its left and one RIGHT of it reveals the cell
      // to its right, which leaves the cell the origin straddles (floor(ox) across a horizontal wall
      // run, floor(oy) across a vertical one) aimed at by nothing at all. it stayed dark however hard
      // the player stared straight at it, and only on a STRAIGHT run, because anywhere the geometry is
      // irregular some other corner's ray happens to cross that face and reveal it. these hit a face at
      // exactly x = ox / y = oy, which puts the step inside precisely that cell. no degeneracy: a
      // vertical ray against a vertical face gives |den| ~ 6e-17 and castRay rejects it as parallel,
      // which is correct, and against a horizontal face den is 1
      angles.push(0);
      angles.push(Math.PI / 2);
      angles.push(Math.PI);
      angles.push(-Math.PI / 2);
      angles.sort(function(a:Float, b:Float):Int
        {
          if (a < b)
            return -1;
          if (a > b)
            return 1;
          return 0;
        });
      // sorted, so the dedupe is a running compare and the hits come out in polygon order with no
      // second sort — which is the one thing the 2D original does that is pure redundancy
      var wallCol:Array<Int> = [];
      var wallRow:Array<Int> = [];
      seenGen++;
      var prev = -1e9;
      var n = 0;
      sctx.beginPath();
      for (a in angles)
        {
          if (a - prev <= DEDUPE_EPS)
            continue;
          prev = a;
          var rx = Math.cos(a);
          var ry = Math.sin(a);
          var d = castRay(segs, ox, oy, rx, ry);
          if (d <= 0)
            continue;
          var hx = ox + rx * d;
          var hy = oy + ry * d;
          if (n == 0)
            sctx.moveTo(hx * P, hy * P);
          else sctx.lineTo(hx * P, hy * P);
          n++;
          // the blocker this ray stopped on, recovered by stepping a hair further along it. revealing
          // that whole cell is what makes a wall the player is LOOKING AT read solid instead of
          // half-lit — the 2D view punches out the same tiles (addLOSHitOpaqueTilePaths) — and down
          // here it lights the wall's near face AND its ledge cap, which are the two parts of it the
          // overhead camera actually sees. the range bound lands on open floor and fails this test
          var wc = Math.floor(hx + rx * STEP_EPS);
          var wr = Math.floor(hy + ry * STEP_EPS);
          // stamped, so a cell a dozen rays land on is collected once. it used to be painted once per
          // ray and the overlaps were harmless while every cell was a flat white rect; they are not
          // harmless now that a cell can carry a gradient, and the stamps double as the "was this
          // reached" lookup the fade below asks its neighbours
          if (wc >= 0 &&
              wr >= 0 &&
              wc < mw &&
              wr < mh &&
              seen[wr * mw + wc] != seenGen &&
              !game.area.canSeeThrough(wc, wr))
            {
              seen[wr * mw + wc] = seenGen;
              wallCol.push(wc);
              wallRow.push(wr);
            }
        }
      // fail OPEN, never dark. fewer than three hits means the sweep found nothing to stand on, and
      // a level blacked out by a geometry edge case is a far worse failure than one revealed
      if (n < 3)
        {
          sctx.fillRect(0, 0, canvas.width, canvas.height);
          return;
        }
      sctx.closePath();
      sctx.fill();
      // a SECOND path, not more subpaths on the first: rect always winds one way while the polygon's
      // winding follows the angle sweep, so filling them together could cancel under the nonzero rule.
      // only the cells with nothing to fade toward go in it — one path, one fill, however long the run
      sctx.beginPath();
      for (i in 0...wallCol.length)
        if (!fades(game, wallCol[i], wallRow[i]))
          sctx.rect(wallCol[i] * P, wallRow[i] * P, P, P);
      sctx.fill();
      // and the handful at the ends of a run are painted per texel
      for (i in 0...wallCol.length)
        if (fades(game, wallCol[i], wallRow[i]))
          fadeCell(game, wallCol[i], wallRow[i]);
    }

// does this lit wall cell touch masonry the sweep never reached?
  static function fades(game:Game, c:Int, r:Int):Bool
    {
      return dark(game, c - 1, r) ||
        dark(game, c + 1, r) ||
        dark(game, c, r - 1) ||
        dark(game, c, r + 1);
    }

// is this neighbour a blocker the sweep never reached? open floor is not one whatever its state —
// the fade exists to end a run of lit MASONRY, and floor already ends at the polygon edge.
// OFF THE GRID counts as dark, and it is the one case that is not about the sweep at all. this used
// to return false, on the reasoning that there is no level out there to fade into — which is exactly
// backwards. SewerGeom caps EVERY solid cell and only insets a cap edge that overlooks floor, so the
// area border's cap runs flush to the boundary and then there is no geometry whatever: a fully lit
// ledge meeting the clear colour on a hard rim, which is what standing against the outer wall looked
// like. the black background IS what it should fade into. the cost the old comment worried about does
// not arrive either — only cells the sweep REACHED are ever tested, so a MASK_R radius bounds it
  static function dark(game:Game, c:Int, r:Int):Bool
    {
      if (c < 0 ||
          r < 0 ||
          c >= mw ||
          r >= mh)
        return true;
      return !game.area.canSeeThrough(c, r) &&
        seen[r * mw + c] != seenGen;
    }

// one step of a wall fade as a canvas colour. a and b are the distances to the two sides on this axis
// (1.0 where that side is not fading), so the ramp is their MINIMUM, scaled by the fade depth
  static function ramp(a:Float, b:Float, f:Float):String
    {
      return 'rgb(' + Std.int(Math.min(1, Math.min(a, b) / f) * 255) + ',0,0)';
    }

// one lit wall cell that borders masonry the sweep never reached, so a run of lit wall dims into the
// dark instead of stopping at a right angle — the hard 90-degree edges the per-cell reveal used to
// leave all over the tunnels.
// the unreached cell is never painted, so the whole authored ramp lives inside the cell that can
// actually be seen. MASK_BLUR then carries a little of it across the shared edge, which is the point
// of the blur and not a leak — the dark side lands above MASK_HIDDEN for a texel or so rather than
// stepping onto it, and the two ramps read as one.
//
// THIS IS THE WHOLE COST OF A REBUILD, so it goes out as STRIPS wherever it can. the value is the
// minimum of the distances to the fading sides, and a cell that fades on one axis only — which is
// nearly all of them, since the usual case is masonry sitting behind a wall the player is looking at —
// has a ramp that does not vary along the other axis at all. so that case is P fillRects instead of
// P*P. measured at MASK_PX 8, 56 fading cells: 3584 single-texel fills is 3.78ms, against 0.10ms for
// the composite and 0.02ms for the polygon. only a cell fading on BOTH axes turns a corner in its
// iso-contour and needs the per-texel loop
  static function fadeCell(game:Game, c:Int, r:Int):Void
    {
      var P = SewerStyle.MASK_PX;
      var f = SewerStyle.MASK_WALL_FADE;
      var fw = dark(game, c - 1, r);
      var fe = dark(game, c + 1, r);
      var fn = dark(game, c, r - 1);
      var fs = dark(game, c, r + 1);
      // fades east/west only: constant down a column, so one full-height strip per column
      if (!fn && !fs)
        {
          for (i in 0...P)
            {
              var u = (i + 0.5) / P;
              sctx.fillStyle = ramp(fw ? u : 1.0, fe ? 1 - u : 1.0, f);
              sctx.fillRect(c * P + i, r * P, 1, P);
            }
          return;
        }
      // fades north/south only: constant along a row
      if (!fw && !fe)
        {
          for (j in 0...P)
            {
              var v = (j + 0.5) / P;
              sctx.fillStyle = ramp(fn ? v : 1.0, fs ? 1 - v : 1.0, f);
              sctx.fillRect(c * P, r * P + j, P, 1);
            }
          return;
        }
      // both axes: the ramp turns a corner, and no stack of linear gradients gives a minimum
      for (j in 0...P)
        for (i in 0...P)
          {
            // texel centre as a fraction of the cell, then the distance to the nearest fading side
            var u = (i + 0.5) / P;
            var v = (j + 0.5) / P;
            var d = 1.0;
            if (fw)
              d = Math.min(d, u);
            if (fe)
              d = Math.min(d, 1 - u);
            if (fn)
              d = Math.min(d, v);
            if (fs)
              d = Math.min(d, 1 - v);
            sctx.fillStyle = 'rgb(' + Std.int(Math.min(1, d / f) * 255) + ',0,0)';
            sctx.fillRect(c * P + i, r * P + j, 1, 1);
          }
    }

// distance to the nearest segment along a ray, in cell units, or 0 when it escapes everything.
// deliberately ALLOCATION-FREE: this is the O(rays * segments) inner loop (~250k tests at a full
// radius) and the 2D original builds a record per candidate hit, which an on-demand canvas redraw can
// afford and a tighter rebuild rate could not. the segment-position test is deferred behind the
// distance reject for the same reason — most candidates lose on distance first
  static function castRay(segs:Array<MaskSeg>, ox:Float, oy:Float, rx:Float, ry:Float):Float
    {
      var best = 0.0;
      for (s in segs)
        {
          var sx = s.x2 - s.x1;
          var sy = s.y2 - s.y1;
          var dx = s.x1 - ox;
          var dy = s.y1 - oy;
          var den = rx * sy - ry * sx;
          if (den > -HIT_EPS &&
              den < HIT_EPS)
            continue;
          var d = (dx * sy - dy * sx) / den;
          if (d < HIT_EPS ||
              (best > 0 && d >= best))
            continue;
          var t = (dx * ry - dy * rx) / den;
          if (t < -HIT_EPS ||
              t > 1 + HIT_EPS)
            continue;
          best = d;
        }
      return best;
    }

// (re)build the canvas + texture for this level's dimensions, and the world->uv transform with them
  static function ensure(m:Sewer):Void
    {
      if (canvas != null &&
          mw == m.w &&
          mh == m.h)
        return;
      mw = m.w;
      mh = m.h;
      canvas = Browser.document.createCanvasElement();
      canvas.width = mw * SewerStyle.MASK_PX;
      canvas.height = mh * SewerStyle.MASK_PX;
      ctx = canvas.getContext2d();
      scratch = Browser.document.createCanvasElement();
      scratch.width = canvas.width;
      scratch.height = canvas.height;
      sctx = scratch.getContext2d();
      // stamps start at 0 and seenGen is already past it, so a fresh grid reads as nothing reached
      seen = [for (i in 0...mw * mh) 0];
      tex = new CanvasTexture(canvas);
      // DATA, not colour: an sRGB decode on the way in would bend the ramp between a seen and an
      // unseen point into something neither end asked for
      tex.colorSpace = THREE.NoColorSpace;
      // v runs with the row index, so row 0 of the canvas is row 0 of the grid
      tex.flipY = false;
      // linear WITHOUT mipmaps. the polygon edge is already antialiased by the canvas fill, which
      // carries it at sub-texel precision; this reconstructs that, while a mip chain would cost a
      // regeneration per rebuild and over-blur the edge at the grazing angles the sewer camera lives at
      tex.generateMipmaps = false;
      tex.minFilter = THREE.LinearFilter;
      tex.magFilter = THREE.LinearFilter;
      uMap.value = tex;
      // world XZ -> uv, and note this is RESOLUTION-INDEPENDENT: uv is normalized, so MASK_PX changes
      // how finely the mask is sampled and nothing here. CityConfig.cellToWorld puts the CENTRE of
      // cell (col,row) at (col - GRID/2 + 0.5) * CELL, so the continuous cell coordinate of a world x
      // is x / CELL + GRID/2 and the canvas is that scaled by MASK_PX
      uScale.value.set(1 / (CityConfig.CELL * mw), 1 / (CityConfig.CELL * mh));
      uOrigin.value.set(CityConfig.GRID / 2 / mw, CityConfig.GRID / 2 / mh);
    }

// patch a mesh's material, tolerating a mesh that is not there yet. every glb-backed prop down here
// arrives through a loader callback, so its InstancedMesh is null for the first frames
  public static function patchMesh(o:Object3D):Void
    {
      if (o != null &&
          o.material != null)
        patch(o.material);
    }

// fold the mask into one material, and hand it back so a builder can wrap it around the material it
// was already constructing. the mode is read off the material rather than passed in, so no caller has
// to say what kind of surface it is building:
//   fog:false  -> a UI marker, not world geometry (the tactical outline hull says so itself) — skipped
//   additive   -> scale rgb, and to a HARDER floor: additive light ADDS over whatever is behind it, so
//                 a dimmed glow quad is still a bright dot floating in a corridor nobody can see, and
//                 that is the single tell that gives the whole effect away
//   transparent-> scale alpha, so a decal fades out with the wall it is painted on
//   otherwise  -> mix toward the FOG COLOUR. toward the fog rather than toward black on purpose: the
//                 hidden surface then desaturates as it dims and lands exactly where the distance fog
//                 was already taking it, so the mask boundary adds no new silhouette to the frame
  public static function patch(mat:Dynamic):Dynamic
    {
      // the "already patched" mark lives on the HOOK, not in userData. Material.clone() copies
      // userData but NOT onBeforeCompile or customProgramCacheKey, so a userData flag rides onto the
      // ghost clones render.Models makes from a patched template and locks them out of the patch they
      // never received. found live, on the exit ladder's ghost, which read as patched and was not
      if (mat.fog == false ||
          (mat.onBeforeCompile != null &&
           mat.onBeforeCompile.sewerMask == true))
        return mat;
      var additive = (mat.blending == THREE.AdditiveBlending);
      var floor = additive ? uFloorAdd : uFloor;
      var mode = additive ? 'g' : (mat.transparent == true ? 'b' : 's');
      // the boundary WANDERS in world space, over WALL CELLS ONLY (see the .g gate below): a shadow
      // edge out on open floor is a real ray cast past a corner and reads wrong bent, while the same
      // edge crossing masonry is the per-cell reveal and is exactly what wanted breaking up.
      // two octaves of sine per axis rather than a hash, because
      // the job is to break a straight line and not to be statistically noisy — a SMOOTH offset keeps
      // an edge an edge, while white noise would dither it into salt and pepper. keyed on vSewerMask,
      // i.e. WORLD xz and nothing else: that glues the wobble to the level so the polygon slides
      // THROUGH it, and keying it to anything the player carries would make the whole boundary swim on
      // every move, which is far worse than the straight line it set out to fix. the offset is in world
      // units and converted by sewerMaskScale, so it stays isotropic and does not change with the
      // level's dimensions the way a raw uv offset would
      var sample =
        '  vec2 sewerBase = vSewerMask * sewerMaskScale + sewerMaskOrigin;\n' +
        '  vec4 sewerM = texture2D( sewerMaskMap, sewerBase );\n' +
        '  vec2 sewerW = vSewerMask;\n' +
        '  vec2 sewerWob = vec2( sin( sewerW.y * 0.70 + sewerW.x * 0.31 ),\n' +
        '                        sin( sewerW.x * 0.63 - sewerW.y * 0.27 ) )\n' +
        '            + 0.5 * vec2( sin( sewerW.y * 1.90 - sewerW.x * 1.13 ),\n' +
        '                          sin( sewerW.x * 2.10 + sewerW.y * 1.37 ) );\n' +
        '  float sewerWobbled = texture2D( sewerMaskMap,\n' +
        '    sewerBase + sewerWob * sewerMaskWobble * sewerMaskScale ).r;\n' +
        // .g is the masonry channel, so the wobbled sample is taken ONLY over a wall and the straight
        // one everywhere else. it interpolates across a wall/floor boundary, so the wobble fades in
        // over a texel rather than switching on at a seam.
        // .b is the level's outer falloff, and it multiplies AFTER the floor mix rather than feeding
        // into it — that is the whole reason it exists as a separate channel. the mix bottoms out at
        // sewerMaskFloor, so nothing routed through it can ever reach zero, and the rim has to: fog
        // and background are the same colour down here, so vis 0 lands exactly on the background and
        // the level stops having a silhouette. free, since it rides the fetch .r and .g already did
        '  float sewerVis = mix( sewerMaskFloor, 1.0,\n' +
        '    mix( sewerM.r, sewerWobbled, sewerM.g ) ) * sewerM.b;\n';
      var apply = switch (mode)
        {
          case 'g': '  gl_FragColor.rgb *= sewerVis;\n';
          case 'b': '  gl_FragColor.a *= sewerVis;\n';
          // no USE_FOG means no fogColor to reach for; a plain scale is the honest fallback
          default: '#ifdef USE_FOG\n' +
            '  gl_FragColor.rgb = mix( fogColor, gl_FragColor.rgb, sewerVis );\n' +
            '#else\n' +
            '  gl_FragColor.rgb *= sewerVis;\n' +
            '#endif\n';
        }
      // a material may already carry a hook of its OWN — render.decals.DecalBatch folds per-instance
      // alpha and the atlas window into the same shader, and the ground debris rides that batch, so
      // underground it has to take the mask without losing either. CHAIN rather than replace: the two
      // use different anchors (<uv_vertex> / <opaque_fragment> against <project_vertex> /
      // <fog_fragment>), both survive the other's edits, and ours injects into whatever the first one
      // produced. replacing here is the trap this file already carries an obituary for
      var prev:Dynamic = mat.onBeforeCompile;
      // an OWN key only. three's Material carries a DEFAULT customProgramCacheKey on the PROTOTYPE
      // that returns this.onBeforeCompile.toString(), so this field is never null and a plain
      // `mat.customProgramCacheKey` would take the default — which then threw on every draw when
      // called unbound (no receiver, so `this.onBeforeCompile` is undefined) and blanked the frame.
      // taking it only when the material set one of its own also keeps the key short
      var prevKey:Dynamic = untyped mat.hasOwnProperty('customProgramCacheKey') ?
        mat.customProgramCacheKey : null;
      var hook:Dynamic = function(shader:Dynamic, renderer:Dynamic)
        {
          if (prev != null)
            prev(shader, renderer);
          shader.uniforms.sewerMaskMap = uMap;
          shader.uniforms.sewerMaskScale = uScale;
          shader.uniforms.sewerMaskOrigin = uOrigin;
          shader.uniforms.sewerMaskFloor = floor;
          shader.uniforms.sewerMaskWobble = uWobble;
          // the instanceMatrix branch is NOT optional: the wall fixtures, the glow quads, the contact
          // shadows and every glb prop down here are InstancedMesh, and their placement lives in that
          // matrix alone — modelMatrix by itself would pin the whole batch to the world origin
          shader.vertexShader = 'varying vec2 vSewerMask;\n' +
            StringTools.replace(shader.vertexShader, '#include <project_vertex>',
              '#include <project_vertex>\n' +
              '#ifdef USE_INSTANCING\n' +
              '  vSewerMask = ( modelMatrix * instanceMatrix * vec4( transformed, 1.0 ) ).xz;\n' +
              '#else\n' +
              '  vSewerMask = ( modelMatrix * vec4( transformed, 1.0 ) ).xz;\n' +
              '#endif');
          // AFTER the fog chunk, which is where three has already left tonemapping and the colour-space
          // conversion behind — so this mixes in the same space the fog it blends toward lives in
          shader.fragmentShader = 'uniform sampler2D sewerMaskMap;\n' +
            'uniform vec2 sewerMaskScale;\n' +
            'uniform vec2 sewerMaskOrigin;\n' +
            'uniform float sewerMaskFloor;\n' +
            'uniform float sewerMaskWobble;\n' +
            'varying vec2 vSewerMask;\n' +
            StringTools.replace(shader.fragmentShader, '#include <fog_fragment>',
              '#include <fog_fragment>\n' + sample + apply);
        };
      hook.sewerMask = true;
      mat.onBeforeCompile = hook;
      // three keys its program cache on base material params, NOT on onBeforeCompile — without a key
      // of our own a masked program could be handed to an identical unmasked material, or the three
      // modes above could collide with each other. same trap render.decals.DecalBatch documents
      // the chained key has to carry the FIRST hook's key too, or a masked decal program collides
      // with the plain one that only folds instance alpha
      // called with the material as the RECEIVER: a key function is a method and may read `this`
      mat.customProgramCacheKey = function()
        return (prevKey != null ? Std.string(Reflect.callMethod(mat, prevKey, [])) : '') +
          'sewerMask' + mode;
      mat.needsUpdate = true;
      return mat;
    }
}
