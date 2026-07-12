package render.choreo;

import game.Game;
import render.Actors;
import render.CameraRig;
import render.Shockwave;

// context bundle passed to the choreography modules (Shot/Melee/Projectile/Splat/Scream/Money/
// Reactions): the game plus the per-build 3D layers a choreography drives — actor billboards, the
// follow camera (recoil), the screen-space shockwave. rebuilt each city build alongside `actors`;
// holds only references, no GPU resources, so nothing to dispose
class Choreo {
  public var game:Game;                                  // game state (area queries, sounds, decorations)
  public var actors:Actors;                              // the billboard actor layer every choreography drives
  public var rig:CameraRig;                              // follow camera — Shot kicks it for player recoil
  public var shockwave:Shockwave;                        // screen-space ripple pass — Scream pulses it

  public function new(game:Game, actors:Actors, rig:CameraRig, shockwave:Shockwave)
    {
      this.game = game;
      this.actors = actors;
      this.rig = rig;
      this.shockwave = shockwave;
    }
}
