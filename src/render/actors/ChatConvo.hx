package render.actors;

import three.Three;
import render.RenderConfig;
import render.ActorAnim;
import render.world.WorldCtx;
import render.particles.Sprites;
import game.Game;
import entities.Entity;

// the chat-conversation pass of the actor layer: while the HUD is in chat mode it drives a pair of
// "talking" bubbles (the animated ... of someone mid-sentence) over the two speakers — the parasite's
// host and its chat target — alternating one at a time so they read as people in the middle of a
// conversation. when the player talks to their own host both bubbles anchor the same head, flanking
// it left then right. reads actor poses from the shared Actors map (read-only) and paints through the
// HUD-owned ChatBubbles surface, the same DOM layer the AI barks use (distinct 'chat:' keys so a
// stray bark can't clobber them)
class ChatConvo {
  static inline var DOTS = '...';        // talking-bubble text: the dot-by-dot reveal itself runs in css
  static inline var SELF_OFFSET = 46.0;  // self-chat: px each bubble sits left/right of the shared head

  var game:Game;
  var camera:PerspectiveCamera;                          // read live for the screen-space head anchor
  var actors:haxe.ds.ObjectMap<Entity, Actor>;           // shared actor-pose map (read-only here)
  var bubbles:ui.hud.ChatBubbles;                        // HUD-owned bubble surface (shared with barks)
  var _v = new Vector3();                                // scratch projection vector
  var _up = new Vector3();                               // scratch: screen-up axis for the head lift
  var _px = 0.0;                                         // scratch: last projected head client x
  var _py = 0.0;                                         // scratch: last projected head client y
  var running = false;                                  // chat pass ran last frame? (rising-edge reset)
  var slot = 0;                                         // which speaker talks now: 0 = host, 1 = target
  var clockMs = 0.0;                                    // ms into the current speaker's turn
  var turnMs = 0.0;                                     // randomized length of the current turn
  var idA = 0;                                          // per-slot bubble identity, bumped on each (re)appear to replay the pop
  var idB = 0;

  public function new(game:Game, camera:PerspectiveCamera,
      actors:haxe.ds.ObjectMap<Entity, Actor>, bubbles:ui.hud.ChatBubbles)
    {
      this.game = game;
      this.camera = camera;
      this.actors = actors;
      this.bubbles = bubbles;
    }

// drive the talking bubbles for one frame; no-op unless the HUD is in a live chat. queues only the
// active speaker's bubble (one at a time), so ChatBubbles.end() retires the other with its exit anim
  public function drive(dtMs:Float):Void
    {
      var chat = game.player.chat;
      if (game.ui.hud.state != HUD_CHAT ||
          chat.target == null)
        {
          running = false;
          return;
        }
      var host = game.player.host;
      var target = chat.target;
      // chat just opened: start on the host with a fresh turn
      if (!running)
        {
          running = true;
          slot = 0;
          clockMs = 0;
          turnMs = randTurn();
        }
      // advance the turn; on expiry hand off to the other speaker and replay its pop
      clockMs += dtMs;
      if (clockMs >= turnMs)
        {
          clockMs = 0;
          turnMs = randTurn();
          slot = 1 - slot;
          if (slot == 0)
            idA++;
          else idB++;
        }
      // 2 little hops in the final jump-window of the turn, easing out toward the switch
      var C = RenderConfig.CHAT_BUBBLE;
      var jump = 0.0;
      var winMs = C.jumpMult * RenderConfig.BASE_MS;
      var left = turnMs - clockMs;
      if (left < winMs)
        {
          var p = 1 - left / winMs;                        // 0..1 across the window
          jump = -Math.abs(Math.sin(p * C.hops * Math.PI)) * (1 - p) * C.jumpPx;
        }
      // self-chat flanks the one head (left then right); normal chat anchors each speaker's own head
      var self = (target == host);
      var speaker = (slot == 0) ? host : target;
      var dx = self ? (slot == 0 ? -SELF_OFFSET : SELF_OFFSET) : 0.0;
      // off-screen / behind the camera: skip queueing, the bubble retires itself
      if (!headPx(speaker.entity))
        return;
      bubbles.show((slot == 0) ? 'chat:A' : 'chat:B', (slot == 0) ? idA : idB,
        DOTS, '', 'talk', _px + dx, _py + jump);
    }

// randomized speaker turn length in ms (BASE_MS multiples)
  function randTurn():Float
    {
      var C = RenderConfig.CHAT_BUBBLE;
      return (C.turnMin + Math.random() * C.turnVar) * RenderConfig.BASE_MS;
    }

// project a speaker's head to client px into _px/_py (with the badge-style screen-up lift so the
// bubble rides above the head at every camera pitch); false if the head is off-screen or behind
  function headPx(e:Entity):Bool
    {
      var a = actors.get(e);
      if (a == null ||
          a.op < 0.3)
        return false;
      _up.set(0, 1, 0).applyQuaternion(camera.quaternion);
      var lift = Sprites.SIZE * RenderConfig.BUBBLE_LIFT;
      _v.set(a.x, WorldCtx.floorY(a.col, a.row) + Sprites.SIZE * 0.5, a.z);
      _v.set(_v.x + _up.x * lift, _v.y + _up.y * lift, _v.z + _up.z * lift);
      _v.project(camera);
      if (_v.z > 1 ||
          _v.x < -1 || _v.x > 1 ||
          _v.y < -1 || _v.y > 1)
        return false;
      _px = (_v.x * 0.5 + 0.5) * render.Viewport.w;
      _py = (-_v.y * 0.5 + 0.5) * render.Viewport.h;
      return true;
    }
}
