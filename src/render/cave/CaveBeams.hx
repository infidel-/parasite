package render.cave;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import render.sewer.SewerModel.Sewer;
import render.world.VisionMask;

// one moonlight shaft: its axis from inside the arch (a) to the floor (b), and two unit vectors across it
private typedef CaveShaft = {
  a:Vector3,
  b:Vector3,
  u:Vector3,
  v:Vector3,
}

// the moonlight down each cave mouth, made visible (asked for: "we lack any interesting lighting"). the
// mouth's pooled spotlight (render.cave.CaveScene) already lands on the floor in front of it, and
// nothing showed the light in the air on the way. a slanted open shell from inside the arch down to
// that pool, additive and fading out toward the floor (render.LightCone's look; LightCone only stands
// straight down), and the dust in it as a few dozen points sinking down the shaft. one merged mesh for
// every shaft and one for every speck: two draw calls a cave
class CaveBeams
{
  static var shafts:Array<CaveShaft> = [];
  static var motes:Points = null;
  // per speck: its shaft, its place down it (0 the arch .. 1 the floor), its angle round the axis, its
  // share of the radius there and its own speed
  static var shaft:Array<Int> = [];
  static var along:Array<Float> = [];
  static var turn:Array<Float> = [];
  static var out:Array<Float> = [];
  static var speed:Array<Float> = [];

// build every mouth's shaft and its specks. runs from render.cave.CaveGeom.build, so the warm compiles
// both programs
  public static function build(scene:Scene, m:Sewer):Void
    {
      shafts = [];
      motes = null;
      shaft = [];
      along = [];
      turn = [];
      out = [];
      speed = [];
      for (l in m.lamps)
        {
          if (!l.exit)
            continue;
          var w = CityConfig.cellToWorld(l.col, l.row);
          var dir = CaveScene.into(m, l.col, l.row);
          var a = new Vector3(w.x - dir.x * CaveStyle.BEAM_BACK, CaveStyle.BEAM_TOP_Y,
            w.z - dir.z * CaveStyle.BEAM_BACK);
          var b = new Vector3(w.x + dir.x * CaveStyle.BEAM_REACH, 0, w.z + dir.z * CaveStyle.BEAM_REACH);
          var axis = b.clone().sub(a).normalize();
          var u = new Vector3(0, 1, 0).cross(axis).normalize();
          shafts.push({
            a: a,
            b: b,
            u: u,
            v: axis.clone().cross(u).normalize(),
          });
        }
      if (shafts.length == 0)
        return;

      // the shells: a ring at the arch in the moonlight's colour, one at the floor in black, so the
      // additive fade runs the length of the shaft
      var moon = new Color(CaveStyle.MOUTH_COLOR);
      var pos:Array<Float> = [];
      var col:Array<Float> = [];
      var idx:Array<Int> = [];
      var n = CaveStyle.BEAM_SEG;
      for (s in shafts)
        {
          var base = Std.int(pos.length / 3);
          for (end in 0...2)
            for (i in 0...n)
              {
                var t = 2 * Math.PI * i / n;
                var p = ring(s, end, t, 1.0);
                pos.push(p.x);
                pos.push(p.y);
                pos.push(p.z);
                var k = (end == 0 ? 1.0 : 0.0);
                col.push(moon.r * k);
                col.push(moon.g * k);
                col.push(moon.b * k);
              }
          for (i in 0...n)
            {
              var i2 = (i + 1) % n;
              idx.push(base + i);
              idx.push(base + i2);
              idx.push(base + n + i2);
              idx.push(base + i);
              idx.push(base + n + i2);
              idx.push(base + n + i);
            }
        }
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(pos, 3));
      geo.setAttribute('color', new Float32BufferAttribute(col, 3));
      geo.setIndex(idx);
      // render.LightCone's material, for its reasons: both faces in one additive draw, no depth write,
      // and ordered after the actors so a body standing in the shaft takes its tint
      var shell = new Mesh(geo, VisionMask.patch(new MeshBasicMaterial({
        vertexColors: true,
        transparent: true,
        opacity: CaveStyle.BEAM_ALPHA,
        depthWrite: false,
        side: THREE.DoubleSide,
        forceSinglePass: true,
        blending: untyped THREE.AdditiveBlending,
      })));
      untyped shell.renderOrder = render.particles.Sprites.ORD_ACTOR + 1;
      scene.add(shell);

      // the specks, scattered down every shaft off a fixed sequence, so a cave's dust is the same on
      // every entry
      var r = 12345;
      inline function roll():Float
        {
          r = (r * 1103515245 + 12345) & 0x7fffffff;
          return r / 0x7fffffff;
        }
      for (si in 0...shafts.length)
        for (_ in 0...CaveStyle.MOTES)
          {
            shaft.push(si);
            along.push(roll());
            turn.push(roll() * 2 * Math.PI);
            out.push(Math.sqrt(roll()) * 0.8);
            speed.push(0.6 + 0.8 * roll());
          }
      var mg = new BufferGeometry();
      mg.setAttribute('position', new Float32BufferAttribute([for (_ in 0...shaft.length * 3) 0.0], 3));
      mg.setAttribute('color', new Float32BufferAttribute([for (_ in 0...shaft.length * 3) 0.0], 3));
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

// sink the specks down their shafts, a slow turn round the axis as they go, fading in at the arch and
// out at the floor so the wrap back to the top never shows
  public static function tick(dtMs:Float):Void
    {
      if (motes == null)
        return;
      var dt = dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
      var moon = new Color(CaveStyle.MOUTH_COLOR).multiplyScalar(CaveStyle.MOTE_MUL);
      var pos:Dynamic = untyped motes.geometry.getAttribute('position');
      var col:Dynamic = untyped motes.geometry.getAttribute('color');
      for (i in 0...shaft.length)
        {
          along[i] += dt * CaveStyle.MOTE_RATE * speed[i];
          if (along[i] > 1)
            along[i] -= 1;
          turn[i] += dt * CaveStyle.MOTE_RATE * 6 * speed[i];
          var p = ring(shafts[shaft[i]], along[i], turn[i], out[i]);
          pos.setXYZ(i, p.x, p.y, p.z);
          var k = Math.sin(Math.PI * along[i]);
          col.setXYZ(i, moon.r * k, moon.g * k, moon.b * k);
        }
      pos.needsUpdate = true;
      col.needsUpdate = true;
    }

// a point on a shaft: `t` down it (0 the arch, 1 the floor), at angle `a` round the axis and `f` of the
// radius there
  static function ring(s:CaveShaft, t:Float, a:Float, f:Float):Vector3
    {
      var r = (CaveStyle.BEAM_TOP_R + (CaveStyle.BEAM_BOT_R - CaveStyle.BEAM_TOP_R) * t) * f;
      return s.a.clone().lerp(s.b, t)
        .addScaledVector(s.u, Math.cos(a) * r)
        .addScaledVector(s.v, Math.sin(a) * r);
    }
}
