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
// floor in front of it and throws the actors' fake shadows into the cave; this is the lit air it comes
// in through, render.LightCone's idea on a lamp's cone turned on its side: a hollow additive shell out
// of the opening, a top sloping down off the lintel and two sides splaying out from the jambs (asked
// for: quads "like coming from a lamp", perpendicular to the entrance "not 90 degrees ofc", after a
// glow card across the hole), fading out into the cave, and the dust drifting down inside it. one
// merged mesh for every shell and one for every speck: two draw calls a cave
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

// build every mouth's shell and its specks. runs from render.cave.CaveGeom.build, so the warm compiles
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

      // the shells: rings out along the light, each face split into rays across it, its vertex
      // colour the moonlight times the fade along it and its ray's own brightness (an additive black
      // is nothing, so the colour is the fade). the rays off a fixed sequence, so a cave's light is
      // the same on every entry
      var moon = new Color(CaveStyle.MOUTH_COLOR);
      var rays = CaveStyle.SHAFT_RAYS;
      var rings = CaveStyle.SHAFT_RINGS;
      var r = 12345;
      inline function roll():Float
        {
          r = (r * 1103515245 + 12345) & 0x7fffffff;
          return r / 0x7fffffff;
        }
      var pos:Array<Float> = [];
      var col:Array<Float> = [];
      var idx:Array<Int> = [];
      for (mo in mouths)
        for (face in 0...3)
          {
            var base = Std.int(pos.length / 3);
            var ray = [
              for (_ in 0...rays + 1)
                CaveStyle.SHAFT_STREAK + (1 - CaveStyle.SHAFT_STREAK) * roll()
            ];
            for (j in 0...rings + 1)
              {
                var t = j / rings;
                var k = Math.pow(1 - t, CaveStyle.SHAFT_FADE);
                for (i in 0...rays + 1)
                  {
                    var p = shell(mo, face, t, i / rays);
                    pos.push(p.x);
                    pos.push(p.y);
                    pos.push(p.z);
                    // out to nothing at the face's long edges, so the shell is three soft bands of
                    // light and not a glass box with a bright seam down every corner
                    var c = k * ray[i] * Math.sin(Math.PI * i / rays);
                    col.push(moon.r * c);
                    col.push(moon.g * c);
                    col.push(moon.b * c);
                  }
              }
            var n = rays + 1;
            for (j in 0...rings)
              for (i in 0...rays)
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
      var shaft = new Mesh(geo, VisionMask.patch(new MeshBasicMaterial({
        vertexColors: true,
        transparent: true,
        opacity: CaveStyle.GLOW_ALPHA,
        depthWrite: false,
        side: THREE.DoubleSide,
        forceSinglePass: true,
        blending: untyped THREE.AdditiveBlending,
      })));
      untyped shaft.renderOrder = render.particles.Sprites.ORD_ACTOR + 1;
      scene.add(shaft);

      // the specks, off the same sequence
      for (mi in 0...mouths.length)
        for (_ in 0...CaveStyle.MOTES)
          {
            mouth.push(mi);
            along.push(roll());
            across.push(0.15 + 0.7 * roll());
            up.push(0.1 + 0.8 * roll());
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

// a point on one face of a mouth's shell, `t` out along the light (0 the opening's plate, behind the
// boulders, 1 SHAFT_LEN into the cave) and `s` across the face: face 0 the top, from one jamb's
// corner to the other's, faces 1 and 2 the sides, from the floor up. the opening's frame widens by
// SHAFT_SPLAY and its top sinks to SHAFT_TOP on the way out, its bottom to the floor
  static function shell(mo:CaveMouth, face:Int, t:Float, s:Float):Vector3
    {
      var w = CaveStyle.MOUTH_HOLE_W * (1 + (CaveStyle.SHAFT_SPLAY - 1) * t);
      var top = CaveStyle.MOUTH_HOLE_Y1 + (CaveStyle.SHAFT_TOP - CaveStyle.MOUTH_HOLE_Y1) * t;
      var bot = CaveStyle.MOUTH_HOLE_Y0 * (1 - t);
      var x = (face == 0 ? (2 * s - 1) * w : (face == 1 ? -w : w));
      var y = (face == 0 ? top : bot + (top - bot) * s);
      var p = mo.o.clone()
        .addScaledVector(mo.d, CaveStyle.SHAFT_LEN * t)
        .addScaledVector(mo.u, x);
      p.y = y;
      return p;
    }

// drift the specks out of the openings down their shells, each holding its place across the shell as
// it widens and sinks, with a slow sway, fading in at the opening and out at the shell's end so the
// wrap back to the start never shows
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
          var p = shell(mo, 1, t, up[i])
            .lerp(shell(mo, 2, t, up[i]), across[i])
            .addScaledVector(mo.u, Math.sin(turn[i]) * 0.15);
          pos.setXYZ(i, p.x, p.y, p.z);
          var k = Math.sin(Math.PI * t);
          col.setXYZ(i, moon.r * k, moon.g * k, moon.b * k);
        }
      pos.needsUpdate = true;
      col.needsUpdate = true;
    }
}
