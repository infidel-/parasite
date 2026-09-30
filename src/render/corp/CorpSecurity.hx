package render.corp;

import three.Three;
import citygen.CityConfig;
import render.Models;
import render.RenderConfig;
import render.Textures;
import render.facility.FacilityGeom;
import render.facility.FacilityModel;
import render.facility.FacilityStyle;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// the security room's own kit, and the tower's CCTV cameras that feed it.
//
// THE VIDEO WALL is one panel of corp/cctv-wall per console cell, hung on the north wall the console
// stands against (gen.corp.CorpRooms.security puts it there because it is the wall this camera looks
// at). Its own material, because the feeds GLOW: the art is its own emissive map, and the bezels are
// near black so only the screens clear the bloom. THE CAMERAS stand on the corridor's inside corners
// and the reception's, one corner in CAM_EVERY, each a wall-mounted glb with a red recording light in
// render.corp.CorpFurniture's blinking LED mesh. Both are pure functions of the grid, so the prop
// batch and the LED pass find the same cameras without either having run first
class CorpSecurity
{
// the console cells that hang a panel: a worktop on a security room's first row, with masonry behind
  public static function videoCells(m:Facility):Array<{ col:Int, row:Int }>
    {
      var out = [];
      for (r in m.rooms)
        {
          if (r.role != gen.corp.CorpTemp.ROLE_SECURITY)
            continue;
          for (col in r.x1...r.x2 + 1)
            if (FacilityModel.inside(m, col, r.y1) &&
                m.table[r.y1][col] &&
                FacilityModel.isSolidWall(m, col, r.y1 - 1))
              out.push({
                col: col,
                row: r.y1,
              });
        }
      return out;
    }

// and those cells as the stretch of wall render.corp.CorpSigns keeps its framed art off, with the
// hand the wall is on (north)
  public static function videoClear(m:Facility):Array<{ col:Int, row:Int, dir:Int }>
    {
      return [for (c in videoCells(m)) {
        col: c.col,
        row: c.row,
        dir: 0,
      }];
    }

// the feed clock, in turns (RenderConfig.BASE_MS); advanced by `tick`
  static var uFeed = { value: 0.0 };

// hang the video wall and the SECURITY headers over its room's doorways; answers how many panels
  public static function build(scene:Scene, m:Facility):Int
    {
      var b = MeshBufTools.make();
      var cells = videoCells(m);
      for (i in 0...cells.length)
        {
          var c = cells[i];
          var s = FacilityGeom.slab(m, c.col, c.row - 1);
          var w = CityConfig.cellToWorld(c.col, c.row);
          var z = s.z1 + CorpStyle.VIDEO_PROUD;
          var at = b.uv.length;
          FacilityGeom.pane(b, w.x - CorpStyle.VIDEO_W / 2, w.x + CorpStyle.VIDEO_W / 2, z, z, 1,
            CorpStyle.VIDEO_Y0, CorpStyle.VIDEO_Y0 + CorpStyle.VIDEO_H);
          // the panel's index rides in u's whole part, which is what the feed shader deals its
          // six screens off: u runs i..i+1 and the shader reads fract() of it
          var k = at;
          while (k < b.uv.length)
            {
              b.uv[k] += i;
              k += 2;
            }
        }
      addScreens(scene, b);
      var sb = MeshBufTools.make();
      signs(sb, m);
      addGlow(scene, sb, CorpStyle.SECURITY_SIGN, CorpStyle.SEC_SIGN_EMISSIVE, 'corp security sign');
      return cells.length;
    }

// advance the feeds' cut clock, BASE_MS-relative like every timed anim in the game
  public static function tick(dtMs:Float):Void
    {
      uFeed.value += dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
    }

// the lit SECURITY header over every doorway into a security room, on the lintel's face OUTSIDE
// the room: FacilityExit.quad's plane (the door cell's slab IS its lintel), at SIGN_Y between the
// door head and the ceiling. Public for render.corp.CorpWarm
  public static function signs(b:MeshBuf, m:Facility):Void
    {
      var h = CorpStyle.SEC_SIGN_W / 2;
      var y0 = CorpStyle.SEC_SIGN_Y - CorpStyle.SEC_SIGN_H / 2;
      var y1 = CorpStyle.SEC_SIGN_Y + CorpStyle.SEC_SIGN_H / 2;
      for (d in m.doors)
        for (sd in [-1, 1])
          {
            // the security room on this hand, and the sign on the other
            if (CorpModel.securityRoom(m, d.col + (d.alongX ? 0 : sd),
                d.row + (d.alongX ? sd : 0)) == null)
              continue;
            var s = FacilityGeom.slab(m, d.col, d.row);
            var c = CityConfig.cellToWorld(d.col, d.row);
            var e = FacilityStyle.MOUNT_PROUD;
            if (d.alongX)
              {
                var z = (sd > 0 ? s.z0 - e : s.z1 + e);
                FacilityGeom.pane(b, c.x - h, c.x + h, z, z, (sd > 0 ? 0 : 1), y0, y1);
              }
            else
              {
                var x = (sd > 0 ? s.x0 - e : s.x1 + e);
                FacilityGeom.pane(b, x, x, c.z - h, c.z + h, (sd > 0 ? 2 : 3), y0, y1);
              }
          }
    }

// the video wall's material: its art is its own emissive map, and its six feeds CUT between views.
// Public for render.corp.CorpWarm, which has no security room to hang one in
  public static function addScreens(scene:Scene, b:MeshBuf):Void
    {
      var mat = glow(CorpStyle.CCTV_WALL, CorpStyle.VIDEO_EMISSIVE);
      feeds(mat);
      add(scene, b, VisionMask.patch(mat), 'corp video wall');
    }

// a plain lit pane in `tex` (the doorway header). Public for render.corp.CorpWarm
  public static function addGlow(scene:Scene, b:MeshBuf, tex:String, emissive:Float, name:String):Void
    {
      add(scene, b, VisionMask.patch(glow(tex, emissive)), name);
    }

// an emissive lambert whose art is its own emissive map, so only what is bright in it glows
  static function glow(tex:String, emissive:Float):MeshLambertMaterial
    {
      var t = Textures.loadTexture(tex, 'wall', 1);
      return new MeshLambertMaterial({
        map: t,
        emissiveMap: t,
        emissive: new Color(0xffffff),
        emissiveIntensity: emissive,
        side: THREE.FrontSide,
      });
    }

// one unshadowed mesh off a buffer, or nothing for an empty one
  static function add(scene:Scene, b:MeshBuf, mat:Dynamic, name:String):Void
    {
      if (b.idx.length == 0)
        return;
      var mesh = new Mesh(FacilityGeom.geom(b), mat);
      mesh.name = name;
      mesh.receiveShadow = false;
      mesh.castShadow = false;
      scene.add(mesh);
    }

// THE FEEDS CUT: each of a panel's six screens shows one of the art's six feeds, re-dealt every
// FEED_TURNS off a hash of (panel, screen, epoch), each screen on its own phase so the wall never
// cuts all at once, and a FEED_STATIC burst of noise at each cut. The screens are the art's
// MEASURED cells -- columns on thirds, but the rows split at 324 of 672 and not at the half -- so a
// feed dealt into a screen of another height is fitted to it rather than cut off at a bezel.
// textureGrad off the continuous uv, or the jump at every screen edge would pick the smallest mip
  // Dynamic: three's onBeforeCompile hook is not in the extern, every shader patch here takes it so
  static function feeds(mat:Dynamic):Void
    {
      var fn = 'uniform float feedClock;\n' +
        'float feedHash( vec3 p ) {\n' +
        '  return fract( sin( dot( p, vec3( 12.9898, 78.233, 37.719 ) ) ) * 43758.5453 );\n' +
        '}\n' +
        // a screen's left edge and width by column, top edge and height by row, in image space
        'float feedX( float c ) { return c < 0.5 ? 0.0 : ( c < 1.5 ? ' + CorpStyle.FEED_COL1 + ' : ' +
          CorpStyle.FEED_COL2 + ' ); }\n' +
        'float feedW( float c ) { return c < 0.5 ? ' + CorpStyle.FEED_COL1 + ' : ( c < 1.5 ? ' +
          (CorpStyle.FEED_COL2 - CorpStyle.FEED_COL1) + ' : ' + (1 - CorpStyle.FEED_COL2) + ' ); }\n' +
        'float feedY( float r ) { return r < 0.5 ? 0.0 : ' + CorpStyle.FEED_ROW1 + '; }\n' +
        'float feedH( float r ) { return r < 0.5 ? ' + CorpStyle.FEED_ROW1 + ' : ' +
          (1 - CorpStyle.FEED_ROW1) + '; }\n' +
        'vec4 feedTex( sampler2D tx, vec2 uv ) {\n' +
        '  float panel = floor( uv.x );\n' +
        // image space: x across, y DOWN from the art's top row (the texture is flipY)
        '  vec2 p = vec2( uv.x - panel, 1.0 - uv.y );\n' +
        '  float c0 = p.x < ' + CorpStyle.FEED_COL1 + ' ? 0.0 : ( p.x < ' + CorpStyle.FEED_COL2 +
          ' ? 1.0 : 2.0 );\n' +
        '  float r0 = p.y < ' + CorpStyle.FEED_ROW1 + ' ? 0.0 : 1.0;\n' +
        '  vec2 local = vec2( ( p.x - feedX( c0 ) ) / feedW( c0 ), ( p.y - feedY( r0 ) ) / feedH( r0 ) );\n' +
        '  float screen = c0 + r0 * 3.0;\n' +
        '  float t = feedClock / float( ' + CorpStyle.FEED_TURNS + ' ) + feedHash( vec3( panel, screen, 0.5 ) );\n' +
        '  float epoch = floor( t );\n' +
        '  float src = floor( feedHash( vec3( panel, screen, epoch ) ) * 5.999 );\n' +
        '  float sc = mod( src, 3.0 );\n' +
        '  float sr = floor( src / 3.0 );\n' +
        '  vec2 q = vec2( feedX( sc ) + local.x * feedW( sc ), feedY( sr ) + local.y * feedH( sr ) );\n' +
        '  vec4 o = textureGrad( tx, vec2( q.x, 1.0 - q.y ), dFdx( uv ), dFdy( uv ) );\n' +
        // the cut: a burst of grey snow over the screen's own area, bezels and all, for a moment
        '  float snow = step( fract( t ), ' + CorpStyle.FEED_STATIC + ' );\n' +
        '  float n = feedHash( vec3( floor( local * vec2( 48.0, 32.0 ) ), floor( feedClock * 8.0 ) ) );\n' +
        '  o.rgb = mix( o.rgb, vec3( 0.04 + 0.14 * n ), snow );\n' +
        '  return o;\n' +
        '}\n';
      mat.onBeforeCompile = function(shader:Dynamic, _)
        {
          shader.uniforms.feedClock = uFeed;
          // the includes are still unexpanded here, so the two samples are swapped inside the
          // chunks' own text and the chunk goes in expanded in its place
          var f:String = shader.fragmentShader;
          for (c in [
              [ 'map_fragment', 'texture2D( map, vMapUv )', 'feedTex( map, vMapUv )' ],
              [ 'emissivemap_fragment', 'texture2D( emissiveMap, vEmissiveMapUv )',
                'feedTex( emissiveMap, vEmissiveMapUv )' ],
            ])
            f = StringTools.replace(f, '#include <' + c[0] + '>',
              StringTools.replace(THREE.ShaderChunk.get(c[0]), c[1], c[2]));
          shader.fragmentShader = fn + f;
        };
      mat.customProgramCacheKey = function() return 'corpfeeds';
    }

// every CCTV camera on the plate, as the placement of its glb: on the NORTH wall of an inside corner
// (the wall this camera looks at, so the lens is seen), CAM_SIDE out from the side wall and turned
// CAM_TURN toward the floor it watches. A corridor cell (no room owns it) or a reception cell, with
// nothing standing on it
  public static function cams(m:Facility):Array<Models.PropPlace>
    {
      var out:Array<Models.PropPlace> = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!FacilityModel.inside(m, col, row) ||
                m.table[row][col] ||
                m.fit[row][col] != 0 ||
                !FacilityModel.isSolidWall(m, col, row - 1))
              continue;
            var s = m.surf[row][col];
            if (s != Surf.RECEPTION &&
                (s != Surf.CARPET ||
                roomAt(m, col, row)))
              continue;
            for (side in [2, 3])
              {
                var sc = col + FacilityGeom.DC[side];
                if (!FacilityModel.isSolidWall(m, sc, row) ||
                    FacilityModel.mix((col * 73856093) ^ (row * 19349663) ^ side) %
                    CorpStyle.CAM_EVERY != 0)
                  continue;
                var ss = FacilityGeom.slab(m, sc, row);
                var yaw = (side == 2 ? CorpStyle.CAM_TURN : -CorpStyle.CAM_TURN);
                var x = (side == 2 ? ss.x1 + CorpStyle.CAM_SIDE : ss.x0 - CorpStyle.CAM_SIDE);
                var z = FacilityGeom.slab(m, col, row - 1).z1;
                // the glb is recentred on its footprint, so its centre is half its depth out along
                // the way it faces from the plate
                out.push({
                  x: x + Math.sin(yaw) * CorpStyle.CAM_D / 2,
                  z: z + Math.cos(yaw) * CorpStyle.CAM_D / 2,
                  yaw: yaw,
                  y: CorpStyle.CAM_Y,
                });
              }
          }
      return out;
    }

// each camera's red recording light, one speck on its wall plate beside the arm, into the blinking
// LED buffer (render.facility.FacilityDeco.blink's mode 8)
  public static function camLeds(m:Facility, b:MeshBuf):Void
    {
      var sz = CorpStyle.CAM_LED_SIZE / 2;
      for (c in cams(m))
        {
          // the plate's own frame: across it, and out of the wall
          var rx = Math.cos(c.yaw);
          var rz = -Math.sin(c.yaw);
          var fx = Math.sin(c.yaw);
          var fz = Math.cos(c.yaw);
          var back = CorpStyle.CAM_D / 2 - CorpStyle.CAM_LED[2];
          var px = c.x - fx * back + rx * CorpStyle.CAM_LED[0];
          var pz = c.z - fz * back + rz * CorpStyle.CAM_LED[0];
          var py = c.y + CorpStyle.CAM_LED[1];
          var hash = FacilityModel.mix(Std.int(px * 131) ^ Std.int(pz * 977));
          var ph = ((hash >>> 1) % 1000) / 1000;
          MeshBufTools.quadRGB(b,
            [px - rx * sz, py - sz, pz - rz * sz],
            [px + rx * sz, py - sz, pz + rz * sz],
            [px + rx * sz, py + sz, pz + rz * sz],
            [px - rx * sz, py + sz, pz - rz * sz],
            [0, 0, 1, 0, 1, 1, 0, 1], 1.0, ph, 8.0);
        }
    }

// is this cell inside one of the plate's rooms?
  static function roomAt(m:Facility, col:Int, row:Int):Bool
    {
      for (r in m.rooms)
        if (col >= r.x1 &&
            col <= r.x2 &&
            row >= r.y1 &&
            row <= r.y2)
          return true;
      return false;
    }
}
