package render;

import three.Three;
import citygen.CityConfig;
import citygen.CityConfig.cellToWorld;
import game.Game;
import render.RenderConfig;
import render.world.WorldCtx;

// the mouse-hover move-path preview in the 3D street view: a thin, greenish, bloom-glowing wavy
// ribbon from the player to the hovered target tile, ending in a slightly larger target dot. it
// mirrors the old 2D dotted path, but as one triangle-strip ground ribbon (WebGL lines are 1px and
// can't bloom) plus a small disc at the end. render-only, nothing persisted.
// waviness is driven by host control: at full control (or as a free parasite) the line is dead
// straight, and it grows wavier as control is lost. the wobble scrolls over time so the line breathes
class PathLine
{
  var game:Game;
  var scene:Scene;
  var mesh:Mesh;                                          // the wavy ribbon strip (one draw call)
  var dot:Mesh;                                           // the target dot disc at the path end
  var geo:BufferGeometry;
  var mat:MeshBasicMaterial;
  var colFull:Color;                                     // HDR line/dot color at full control (green)
  var colLost:Color;                                     // HDR color at zero control (discolored, toxic rust-red)
  var cells:Array<{ x:Int, y:Int }> = [];                // current path cells, player -> target (empty = hidden)
  var phase:Float = 0.0;                                  // scrolling wobble phase (advances each frame)
  var pulse:Float = 0.0;                                  // target-dot pulse phase (advances each frame)
  var lastAmp:Float = -1.0;                               // amp used at the last rebuild (rebuild when it changes)

// build the (initially hidden) ribbon + dot on the scene; geometry filled lazily on the first set()
  public function new(game:Game, scene:Scene)
    {
      this.game = game;
      this.scene = scene;
      var P = RenderConfig.PATH;
      // HDR endpoint colors (glow baked in): green at full control, discolored toward toxic red as
      // control is lost — the material color lerps between them each frame by the control factor
      colFull = new Color(P.color).multiplyScalar(P.glow);
      colLost = new Color(P.lostColor).multiplyScalar(P.glow);
      // HDR green so the bloom pass gives the thin line + dot a soft glow (like TacticalGrid); a plain
      // alpha blend so PATH.alpha genuinely fades it. depthTest off so it drapes over curbs and stays
      // readable where the path rounds a corner behind a wall (matches the always-visible slime trail)
      mat = new MeshBasicMaterial({
        color: new Color(P.color).multiplyScalar(P.glow),
        transparent: true,
        opacity: P.alpha,
        depthWrite: false,
        depthTest: false,
        toneMapped: false,
        side: THREE.DoubleSide,
      });
      geo = new BufferGeometry();
      mesh = new Mesh(geo, mat);
      mesh.renderOrder = 2;
      untyped mesh.frustumCulled = false; // rebuilt every change + always near the player; skip bounds
      mesh.visible = false;
      scene.add(mesh);
      // target dot: a small filled disc on the same glowing material
      var dr = CityConfig.CELL * P.dotScaleCells;
      dot = new Mesh(new RingGeometry(0, dr, 16), mat);
      dot.rotation.x = -Math.PI / 2;
      dot.renderOrder = 2;
      untyped dot.frustumCulled = false;
      dot.visible = false;
      scene.add(dot);
    }

// set the previewed path from the pathfinder's cell list (player -> target, inclusive). a copy is
// kept so the ribbon can be rebuilt each frame as the wobble scrolls; null/short clears it
  public function set(path:Array<aPath.Node>):Void
    {
      if (path == null ||
          path.length < 2)
        {
          clear();
          return;
        }
      cells = [for (n in path) { x: n.x, y: n.y }];
      lastAmp = -1.0; // force a rebuild on the next update
    }

// hide the preview (keeps the meshes for the next set)
  public function clear():Void
    {
      cells = [];
      mesh.visible = false;
      dot.visible = false;
    }

// per frame: advance the wobble phase and rebuild the ribbon when the phase or amplitude moved
  public function update(dtMs:Float):Void
    {
      if (cells.length < 2)
        return;
      // hide the preview while the player is actually walking a path (it reappears once stopped)
      if (game.playerArea.path != null)
        {
          mesh.visible = false;
          dot.visible = false;
          return;
        }
      var step = dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
      phase += step * RenderConfig.PATH.waveSpeedMult;
      pulse += step / RenderConfig.PATH.dotPulseMult;
      rebuild();
      // throb the target dot around its base size
      var ps = 1.0 + RenderConfig.PATH.dotPulse * Math.sin(pulse * Math.PI * 2);
      dot.scale.set(ps, ps, ps);
      // discolor green -> toxic red as control is lost (same factor as the waviness)
      mat.color.lerpColors(colFull, colLost, lostFactor());
    }

// control-loss factor 0..1: 0 at full control (or no host), 1 at zero host control. drives both the
// waviness and the discoloration
  inline function lostFactor():Float
    {
      var hc = game.player.state == _PlayerState.PLR_STATE_HOST ? game.player.hostControl : 100;
      var f = (100 - hc) / 100.0;
      return f < 0 ? 0 : f;
    }

// current wave amplitude (world): low host control = wavy, full control / no host = straight
  inline function amp():Float
    {
      return RenderConfig.PATH.waveAmpCells * CityConfig.CELL * lostFactor();
    }

// rebuild the ribbon triangle strip: sample a Catmull-Rom spline through the cell centres (so turns
// are smooth curves, not hard V kinks), offset each sample sideways by a scrolling sine (tapered to 0
// at both ends so the line stays glued to the player and the dot), and widen into a thin quad strip.
// also parks the target dot at the last cell centre
  function rebuild():Void
    {
      var P = RenderConfig.PATH;
      var a = amp();
      lastAmp = a;
      // control points: cell centres in world (x,z) + floor height
      var cx:Array<Float> = [];
      var cz:Array<Float> = [];
      var cy:Array<Float> = [];
      for (c in cells)
        {
          var w = cellToWorld(c.x, c.y);
          cx.push(w.x);
          cz.push(w.z);
          cy.push(WorldCtx.floorY(c.x, c.y) + P.yOff);
        }
      var n = cells.length;
      var sub = P.samplesPerCell;
      var total = (n - 1) * sub;                 // last sample index (segments * sub-steps)
      var waveLenW = P.waveLenCells * CityConfig.CELL;
      var pos:Array<Float> = [];
      var idx:Array<Int> = [];
      var w = CityConfig.CELL * P.widthCells;
      var arc = 0.0;                             // running arc length (drives the sine phase)
      var pxc = cx[0], pzc = cz[0];
      var s = 0;                                 // global sample counter
      // walk each cell segment, sub-sampling the Catmull-Rom curve through it (neighbours clamped at
      // the ends). the final segment also emits its endpoint sample so the strip reaches the target
      for (seg in 0...n - 1)
        {
          var i0 = seg - 1 < 0 ? 0 : seg - 1;
          var i3 = seg + 2 > n - 1 ? n - 1 : seg + 2;
          var last = seg == n - 2;
          var kmax = last ? sub : sub - 1;
          for (k in 0...kmax + 1)
            {
              var t = k / sub;
              var mx = cr(cx[i0], cx[seg], cx[seg + 1], cx[i3], t);
              var mz = cr(cz[i0], cz[seg], cz[seg + 1], cz[i3], t);
              var my = cr(cy[i0], cy[seg], cy[seg + 1], cy[i3], t);
              // tangent = spline derivative; perpendicular in the ground plane
              var tx = crTan(cx[i0], cx[seg], cx[seg + 1], cx[i3], t);
              var tz = crTan(cz[i0], cz[seg], cz[seg + 1], cz[i3], t);
              var tl = Math.sqrt(tx * tx + tz * tz);
              if (tl < 0.0001) tl = 1.0;
              var perpx = -tz / tl;
              var perpz = tx / tl;
              // arc length for the sine phase
              arc += Math.sqrt((mx - pxc) * (mx - pxc) + (mz - pzc) * (mz - pzc));
              pxc = mx;
              pzc = mz;
              // taper the amplitude to 0 over the first/last samples so the ends stay anchored
              var edge = Math.min(s, total - s) / total * 2; // 0 at ends, 1 at the middle
              if (edge > 1) edge = 1;
              var off = Math.sin(arc / waveLenW * Math.PI * 2 + phase) * a * edge;
              var ox = mx + perpx * off;
              var oz = mz + perpz * off;
              // two verts per sample (left, right) -> strip
              pos.push(ox + perpx * w);
              pos.push(my);
              pos.push(oz + perpz * w);
              pos.push(ox - perpx * w);
              pos.push(my);
              pos.push(oz - perpz * w);
              if (s < total)
                {
                  var b = s * 2;
                  idx.push(b);
                  idx.push(b + 2);
                  idx.push(b + 1);
                  idx.push(b + 1);
                  idx.push(b + 2);
                  idx.push(b + 3);
                }
              s++;
            }
        }
      geo.setAttribute('position', new Float32BufferAttribute(pos, 3));
      geo.setIndex(idx);
      mesh.visible = true;
      // park the dot at the target cell centre
      dot.position.set(cx[n - 1], cy[n - 1], cz[n - 1]);
      dot.visible = true;
    }

// uniform Catmull-Rom position at t in [0,1] over segment p1->p2 (p0,p3 are the neighbours)
  static inline function cr(p0:Float, p1:Float, p2:Float, p3:Float, t:Float):Float
    {
      var t2 = t * t;
      var t3 = t2 * t;
      return 0.5 * ((2 * p1)
        + (-p0 + p2) * t
        + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
        + (-p0 + 3 * p1 - 3 * p2 + p3) * t3);
    }

// Catmull-Rom derivative (tangent) at t over the same segment
  static inline function crTan(p0:Float, p1:Float, p2:Float, p3:Float, t:Float):Float
    {
      var t2 = t * t;
      return 0.5 * ((-p0 + p2)
        + 2 * (2 * p0 - 5 * p1 + 4 * p2 - p3) * t
        + 3 * (-p0 + 3 * p1 - 3 * p2 + p3) * t2);
    }
}
