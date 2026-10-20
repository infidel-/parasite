package render.cave;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import render.sewer.SewerModel.Sewer;
import render.world.VisionMask;

// one cave mouth's frame: the centre of its opening's plate at the floor, the way into the cave, and
// the way across the opening
private typedef CaveMouth = {
  o:Vector3,
  d:Vector3,
  u:Vector3,
}

// the moonlight in each cave mouth, made visible AT the mouth (asked for: a moonbeam slanting down in
// front of the arch "looks a little weird detached from the actual mouth"; the mouth itself is the
// source of the glow and the dust). the mouth's pooled spotlight (render.cave.CaveScene) lands on the
// floor in front of it and throws the actors' fake shadows into the cave; this lights the opening it
// comes through: an additive card across the hole the boulders leave, brightest in a band round its
// edges and fading out over the boulders' inner faces as a halo, and the dust drifting out of it,
// fanning and sinking a few metres into the cave. one merged mesh for every card and one for every
// speck: two draw calls a cave
class CaveMouthGlow
{
  static var mouths:Array<CaveMouth> = [];
  static var motes:Points = null;
  // per speck: its mouth, its place along its path (0 the opening .. 1 the floor), where it left the
  // opening (across, up), its sway phase and its own speed
  static var mouth:Array<Int> = [];
  static var along:Array<Float> = [];
  static var across:Array<Float> = [];
  static var up:Array<Float> = [];
  static var turn:Array<Float> = [];
  static var speed:Array<Float> = [];

// build every mouth's card and its specks. runs from render.cave.CaveGeom.build, so the warm compiles
// both programs
  public static function build(scene:Scene, m:Sewer):Void
    {
      mouths = [];
      motes = null;
      mouth = [];
      along = [];
      across = [];
      up = [];
      turn = [];
      speed = [];
      for (l in m.lamps)
        {
          if (!l.exit)
            continue;
          var w = CityConfig.cellToWorld(l.col, l.row);
          var dir = CaveScene.into(m, l.col, l.row);
          var d = new Vector3(dir.x, 0, dir.z);
          // the arch's centre is where render.world.ObjModels stands it, stepped back to the wall foot
          var back = CaveProps.mouthOff(m, l.col, l.row) - CaveStyle.MOUTH_PLATE;
          mouths.push({
            o: new Vector3(w.x + d.x * back, 0, w.z + d.z * back),
            d: d,
            u: new Vector3(d.z, 0, -d.x),
          });
        }
      if (mouths.length == 0)
        return;

      // the cards: a grid across the hole, its vertex colour the moonlight times the glow there (an
      // additive black is nothing, so the colour is the fade)
      var moon = new Color(CaveStyle.MOUTH_COLOR);
      var W = CaveStyle.MOUTH_HOLE_W;
      var E = CaveStyle.GLOW_EDGE;
      var H = CaveStyle.GLOW_HALO;
      var Y1 = CaveStyle.MOUTH_HOLE_Y1;
      var xs = [-W - H, -W, -W + E, W - E, W, W + H];
      var ys = [CaveStyle.MOUTH_HOLE_Y0, Y1 - E, Y1, Y1 + H];
      var pos:Array<Float> = [];
      var col:Array<Float> = [];
      var idx:Array<Int> = [];
      for (mo in mouths)
        {
          var base = Std.int(pos.length / 3);
          var o = mo.o.clone().addScaledVector(mo.d, CaveStyle.MOUTH_PLATE - CaveStyle.GLOW_CARD_BACK);
          for (y in ys)
            for (x in xs)
              {
                var p = o.clone().addScaledVector(mo.u, x);
                pos.push(p.x);
                pos.push(y);
                pos.push(p.z);
                var k = glow(x, y);
                col.push(moon.r * k);
                col.push(moon.g * k);
                col.push(moon.b * k);
              }
          var n = xs.length;
          for (j in 0...ys.length - 1)
            for (i in 0...n - 1)
              {
                var a = base + j * n + i;
                idx.push(a);
                idx.push(a + 1);
                idx.push(a + n + 1);
                idx.push(a);
                idx.push(a + n + 1);
                idx.push(a + n);
              }
        }
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(pos, 3));
      geo.setAttribute('color', new Float32BufferAttribute(col, 3));
      geo.setIndex(idx);
      // render.LightCone's material, for its reasons: both faces in one additive draw, no depth write,
      // and ordered after the actors so a body standing in the mouth takes its light
      var card = new Mesh(geo, VisionMask.patch(new MeshBasicMaterial({
        vertexColors: true,
        transparent: true,
        opacity: CaveStyle.GLOW_ALPHA,
        depthWrite: false,
        side: THREE.DoubleSide,
        forceSinglePass: true,
        blending: untyped THREE.AdditiveBlending,
      })));
      untyped card.renderOrder = render.particles.Sprites.ORD_ACTOR + 1;
      scene.add(card);

      // the specks, off a fixed sequence, so a cave's dust is the same on every entry
      var r = 12345;
      inline function roll():Float
        {
          r = (r * 1103515245 + 12345) & 0x7fffffff;
          return r / 0x7fffffff;
        }
      for (mi in 0...mouths.length)
        for (_ in 0...CaveStyle.MOTES)
          {
            mouth.push(mi);
            along.push(roll());
            across.push((roll() * 2 - 1) * W * 0.8);
            up.push(0.7 + roll() * (Y1 - 0.8));
            turn.push(roll() * 2 * Math.PI);
            speed.push(0.6 + 0.8 * roll());
          }
      var mg = new BufferGeometry();
      mg.setAttribute('position', new Float32BufferAttribute([for (_ in 0...mouth.length * 3) 0.0], 3));
      mg.setAttribute('color', new Float32BufferAttribute([for (_ in 0...mouth.length * 3) 0.0], 3));
      motes = new Points(mg, VisionMask.patch(new PointsMaterial({
        size: CaveStyle.MOTE_SIZE,
        sizeAttenuation: true,
        vertexColors: true,
        transparent: true,
        depthWrite: false,
        blending: untyped THREE.AdditiveBlending,
      })));
      untyped motes.frustumCulled = false;
      untyped motes.renderOrder = render.particles.Sprites.ORD_ACTOR + 1;
      scene.add(motes);
      tick(0);
    }

// the card's glow at (x across, y up) in the hole's frame: 1 on the rim band just inside the hole's
// sides and top, GLOW_FILL in its middle, and fading to nothing over GLOW_HALO outside it
  static function glow(x:Float, y:Float):Float
    {
      var W = CaveStyle.MOUTH_HOLE_W;
      var Y1 = CaveStyle.MOUTH_HOLE_Y1;
      var out = Math.max(Math.abs(x) - W, y - Y1);
      if (out > 0)
        return Math.max(0, 1 - out / CaveStyle.GLOW_HALO);
      var rim = Math.max(0, 1 - Math.min(W - Math.abs(x), Y1 - y) / CaveStyle.GLOW_EDGE);
      return CaveStyle.GLOW_FILL + (1 - CaveStyle.GLOW_FILL) * rim;
    }

// drift the specks out of the openings, fanning out and sinking as they go with a slow sway, fading
// in at the opening and out at the floor so the wrap back to the start never shows
  public static function tick(dtMs:Float):Void
    {
      if (motes == null)
        return;
      var dt = dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
      var moon = new Color(CaveStyle.MOUTH_COLOR).multiplyScalar(CaveStyle.MOTE_MUL);
      var pos:Dynamic = untyped motes.geometry.getAttribute('position');
      var col:Dynamic = untyped motes.geometry.getAttribute('color');
      for (i in 0...mouth.length)
        {
          along[i] += dt * CaveStyle.MOTE_RATE * speed[i];
          if (along[i] > 1)
            along[i] -= 1;
          turn[i] += dt * CaveStyle.MOTE_RATE * 6 * speed[i];
          var t = along[i];
          var mo = mouths[mouth[i]];
          var x = across[i] * (1 + (CaveStyle.MOTE_SPREAD - 1) * t) + Math.sin(turn[i]) * 0.15;
          var p = mo.o.clone()
            .addScaledVector(mo.d, CaveStyle.MOTE_REACH * t)
            .addScaledVector(mo.u, x);
          pos.setXYZ(i, p.x, up[i] + (CaveStyle.MOTE_FLOOR - up[i]) * t * t, p.z);
          var k = Math.sin(Math.PI * t);
          col.setXYZ(i, moon.r * k, moon.g * k, moon.b * k);
        }
      pos.needsUpdate = true;
      col.needsUpdate = true;
    }
}
