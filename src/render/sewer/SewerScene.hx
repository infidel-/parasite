package render.sewer;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import render.SceneSetup;
import render.particles.LampLights;
import render.particles.LampPost;
import render.sewer.SewerModel.Sewer;

// the scene + light rig for an underground tunnel area. no sky, no moon, no shadow box: just a
// near-black background, fog that closes in within a few cells (this is what sells the enclosure
// with no ceiling geometry), weak fill, and the SAME live spotlight pool the streets use hung over
// the corridor nodes.
//
// CRITICAL: the pool size and the point-light pools must match the city exactly. NUM_SPOT_LIGHTS
// and NUM_POINT_LIGHTS are baked into every lit material's program key, so a different count here
// would recompile every shared material (actors, particles, decals) on the first sewer entry
class SewerScene
{
  static inline var DARK = 0x05070a; // background + fog: near black, a shade cooler than the city's

// build the sewer scene bundle (same contract render.SceneSetup.buildScene returns for a city)
  public static function build(renderer:WebGLRenderer, m:Sewer, lampPool:Int):SceneSetup.SceneBundle
    {
      var scene = new Scene();
      scene.background = new Color(DARK);
      // fog closes in far sooner than the city's (which starts at 220): sightlines end a couple of
      // block-lengths out, so the missing ceiling reads as darkness rather than as a hole. the near
      // plane has to clear the camera's own distance to the player (~20-45 by zoom) or the tunnel
      // the player is standing in is already half-fogged
      scene.fog = new Fog(DARK, CityConfig.CELL * 11, CityConfig.CELL * 30);

      var lights:Array<Object3D> = [];
      function add(l:Object3D):Object3D
        {
          lights.push(l);
          scene.add(l);
          return l;
        }
      // underground fill, and NO directional — every shaped light down here comes from a lamp.
      // still well above the city's 1.6 / 1.3, and for a reason: the street frame is carried by a
      // moon, hundreds of lamps and lit windows, while down here the fill IS the frame and only a
      // handful of pooled spotlights sit on top of it. ambient carries most of it because it is
      // normal-independent, so the vertical walls stay legible against the floor — a hemisphere
      // alone would not do that.
      //
      // these track the ALBEDO of the tunnel art and must be retuned whenever it is regenerated.
      // the first pass was authored against near-black textures and needed 7.5 / 3.6 to read at
      // all; the tileset-matched art that replaced it is far more reflective. vidBrightness still
      // scales on top.
      //
      // the albedo ratio gives the FLOOR of the range, not the answer. floor art went 0.0331 ->
      // 0.2206 in mean LINEAR luminance (6.66x), so holding the old rendered brightness would mean
      // ambient 1.13 — and in-engine that is far too dark, because the old art had no masonry or
      // moss detail to lose and the new art does. swept live against the habitat at 1x/2x/3x/3.5x/4x
      // of that: 3.5x is where the block courses and the joint moss read across the frame without
      // going flat. hence 1.13 * 3.5.
      //
      // whatever you retune to, COMPUTE THE RATIO IN LINEAR SPACE, NOT ON THE sRGB BYTE MEAN: three
      // decodes an sRGB-tagged map before the lambert multiply. the same two floors are only
      // 51 -> 127.5 = 2.5x as sRGB means, and anchoring to that would have been 2.7x off
      var ambient = add(new AmbientLight(0x3a4657, 3.95));
      var hemi = add(new HemisphereLight(0x46536e, 0x141a22, 1.89));

      // corridor-node lamps: cheap additive cones plus the fixed live-spotlight pool that follows
      // the player. the bulb height is LampLights' own (CELL * yMul = 5.6), which now sits above
      // the wall top — kept shared with the street rig rather than forked, since the cone still
      // lands on the floor and nothing up there is drawn to give the bulb a wrong-looking gap
      var coneGroup = new Group();
      scene.add(coneGroup);
      var lampPosts:Array<LampPost> = [];
      var bulbs:Array<{ x:Float, z:Float }> = [];
      for (l in m.lamps)
        {
          var w = CityConfig.cellToWorld(l.col, l.row);
          bulbs.push({ x: w.x, z: w.z });
          lampPosts.push({
            x: w.x,
            z: w.z,
            y: CityConfig.CELL * RenderConfig.LAMP_LIGHT.yMul,
            col: l.col,
            row: l.row,
            phase: 0.0,
            flick: 1.0,
            mul: 1.0,
          });
        }
      var L = RenderConfig.LAMP_LIGHT;
      var bulbY = CityConfig.CELL * L.yMul;
      var coneR = bulbY * Math.tan(L.angle) * RenderConfig.LAMP_CONE.radiusMul;
      // every NODE lamp is STEADY (phase 0), so this is the city's steady batch: built once and never
      // touched again. the bundle's coneFlick slot is the FLICKERING cone batch, which down here is
      // empty — an empty set builds no mesh at all, and it keeps the contract honest, so LightCone
      // .pulse and the lampMask loop stay no-ops instead of silently walking a phase-less set.
      // the shaft is far blunter than a street lamp's: this is light down a MANHOLE, already a
      // manhole wide where it starts (SewerStyle.CONE_TOP_R against the street's 0.2)
      render.LightCone.instanced({
        group: coneGroup,
        bulbs: bulbs,
        bulbY: bulbY,
        radius: coneR,
        topR: SewerStyle.CONE_TOP_R,
      });
      var coneFlick = render.LightCone.instanced({
        group: coneGroup,
        bulbs: [],
        bulbY: bulbY,
        radius: coneR,
        topR: SewerStyle.CONE_TOP_R,
        phases: [],
      });
      // weak bracketed fixtures along the walls, filling the runs between the junction lamps. their
      // working bulbs join the same pool, so they light, sputter and cast fake actor shadows with no
      // further wiring; the glow batch is repacked per frame by SewerArea.tick
      var wall = SewerLamps.build(scene, coneGroup, m);
      lampPosts = lampPosts.concat(wall.posts);
      var lampLights = new LampLights(scene, lampPool);
      var pts:Array<Object3D> = [];
      for (l in lampLights.debugList())
        {
          lights.push(l);
          pts.push(l);
        }
      pts.push(coneGroup); // debug 5/0 hides the cones alongside the lamp lights

      // debug full-bright WYSIWYG + the light toggles, shared with the city rig
      var tail = SceneSetup.lightingTail(scene, renderer, lights);

      return {
        scene: scene,
        toggleLighting: tail.toggleLighting,
        setLightsOff: tail.setLightsOff,
        fill: [ ambient, hemi ], // no moon underground — debug key 4 has nothing to toggle
        lights: lights,
        moon: null,
        pointLights: pts,
        coneGroup: coneGroup,
        lampLights: lampLights,
        lampPosts: lampPosts,
        lampCorners: new Map(), // no posts to slide around
        lampProp: null,
        lampPropDead: null,
        coneFlick: coneFlick,
        lampMask: [],
        lampMaskDead: [],
        wallGlow: wall.glow,
      };
    }
}
