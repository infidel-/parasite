// area inspect tooltip overlay for HUD (content + visibility; beam/placement in BeamTooltip).
// covers both things worth pointing at in an area: an AI, and an object. it was AI-only and named
// AITooltip for it, and the stylesheet moved with it — `#hud-inspect-info` / `.area-tip-*`, which is
// only safe because no mod's own css under examples/ references either name. NOT `#hud-area-info`:
// see the constructor, that id belongs to ui.RegionTooltip
package ui;

import ai.AI;
import game.Game;
import objects.AreaObject;

class AreaTooltip extends BeamTooltip
{
  public function new(g: Game, h: HUD)
    {
      // NOT 'hud-area-info' — ui.RegionTooltip has used that id since before this class was
      // renamed (its "area" is a tile on the world map, not the area we are standing in), and both
      // overlays live in the HUD container at once, so sharing it puts two nodes on one id
      super(g, h, 'hud-inspect-info', 'area-tip');
    }

// show area tooltip when inspect mode is active
  public function update()
    {
      // the 3D view drives its own hover tooltip (projected anchor via render.View.loop);
      // the 2D tile mapping is wrong under the perspective camera, so stand down there
      if (game.scene.view3d != null &&
          game.scene.view3d.running)
        return;
      if (!hud.isInspectMode())
        {
          hide();
          return;
        }

      var pos = game.scene.mouse.getXY();
      if (pos.x < 0 ||
          pos.y < 0 ||
          pos.x >= game.area.width ||
          pos.y >= game.area.height)
        {
          hide();
          return;
        }

      if (!game.scene.area.isVisible(pos.x, pos.y))
        {
          hide();
          return;
        }

      var ai = game.area.getAI(pos.x, pos.y);
      if (ai != null)
        {
          showBeam(ai.x, ai.y, ai.id, getTooltipText(ai));
          return;
        }

      // no AI on the tile: fall through to whatever object stands there. an AI wins the tile it
      // shares with one — it is the thing that acts
      var obj = objectAt(pos.x, pos.y);
      if (obj == null)
        {
          hide();
          return;
        }
      showBeam(obj.x, obj.y, beamID(obj), getObjectText(obj));
    }

// the first object worth describing on a tile, or null. visible() is what drops decorations and
// doors — the same test render.Actors uses to decide which objects carry the tactical marks
  public function objectAt(x: Int, y: Int): AreaObject
    {
      for (o in game.area.getObjectsAt(x, y))
        if (o.visible())
          return o;
      return null;
    }

// beam target id for an object. NEGATED, because AI ids and object ids come from separate counters
// and BeamTooltip keys its re-animation on this alone — a collision would swallow the beam redraw
// when the cursor moved from an AI straight onto an object that happened to share its number
  public static inline function beamID(o: AreaObject): Int
    {
      return -o.id - 1;
    }

// get tooltip HTML for hovered AI (public: the 3D view's hover driver reuses it verbatim)
  public function getTooltipText(ai: AI): String
    {
      var buf = new StringBuf();
      // header: name + optional cultist mark
      buf.add('<div class="area-tip-head"><span class="area-tip-name">' + ai.getNameCapped() + '</span>');
      if (ai.isCultist)
        buf.add('<span class="area-tip-cultmark">' + Icon.cultist + '</span>');
      buf.add('</div>');

      // sub rows: cult affiliation, job
      if (ai.isCultist)
        buf.add('<div class="area-tip-sub">' + game.getCultByID(ai.cultID).Name() + '</div>');
      if (!ai.isIt() && ai.isJobKnown)
        buf.add('<div class="area-tip-row"><span class="area-tip-rk">job</span>' + ai.job + '</div>');

      // attribute pills
      if (ai.isAttrsKnown)
        buf.add(attrPills(ai.strength, ai.constitution, ai.intellect, ai.psyche));

      // active effects (body window style, always shown)
      var effects = [];
      for (effect in ai.effects)
        if (!effect.isHidden)
          effects.push(effect);
      if (effects.length > 0)
        {
          effects.sort(function(a, b) {
            return (a.name < b.name ? -1 : (a.name > b.name ? 1 : 0));
          });
          buf.add('<div class="area-tip-effects">');
          for (effect in effects)
            buf.add('<div class="body-eff-row">' + UISvg.bodyEffect() + ' ' + effect.name +
              (effect.isTimer ? '<span class="body-eff-t">' +
                UISvg.clockSmall('body-ico body-ico-time') + effect.points + '</span>' : '') +
              '</div>');
          buf.add('</div>');
        }

      if (Const.isDebug)
        addDebugBlock(buf, ai);
      return buf.toString();
    }

// get tooltip HTML for a hovered object (public: the 3D view's hover driver reuses it verbatim).
// getName() already answers 'unknown object' until the type is learned and already appends the
// level for a habitat organ, so the header needs no knowledge check of its own
  public function getObjectText(o: AreaObject): String
    {
      var buf = new StringBuf();
      buf.add('<div class="area-tip-head"><span class="area-tip-name">' +
        Const.capitalize(o.getName()) + '</span></div>');

      // whatever the object wants to say about itself, but only once the player knows what it is
      if (o.known())
        for (row in o.getTooltipRows())
          buf.add('<div class="area-tip-row"><span class="area-tip-rk">' + row.name + '</span>' +
            row.value + '</div>');

      if (Const.isDebug)
        addObjectDebugBlock(buf, o);
      return buf.toString();
    }

// build the STR/CON/INT/PSY pill row
  function attrPills(str: Int, con: Int, int: Int, psy: Int): String
    {
      return '<div class="area-tip-attrs">' +
        '<span class="area-tip-attr">STR<b>' + str + '</b></span>' +
        '<span class="area-tip-attr">CON<b>' + con + '</b></span>' +
        '<span class="area-tip-attr">INT<b>' + int + '</b></span>' +
        '<span class="area-tip-attr">PSY<b>' + psy + '</b></span></div>';
    }

// append the debug detail block
  function addDebugBlock(buf: StringBuf, ai: AI)
    {
      buf.add('<div class="area-tip-debug">');
      if (!ai.isNameKnown)
        buf.add(Const.smalldebug('[debug] name: ' + ai.name.real) + '<br/>');
      if (!ai.isJobKnown)
        buf.add(Const.smalldebug('[debug] job: ' + ai.job) + '<br/>');
      buf.add(Const.smalldebug('[debug] state: ' + ai.state) + '<br/>');
      if (!ai.isAttrsKnown)
        {
          var attrs = '[debug] STR ' + ai.strength +
            ' CON ' + ai.constitution +
            ' INT ' + ai.intellect +
            ' PSY ' + ai.psyche;
          buf.add(Const.smalldebug(attrs) + '<br/>');
        }
      buf.add(Const.smalldebug('[debug] health ' + ai.health + '/' + ai.maxHealth) + '<br/>');
      buf.add(Const.smalldebug('[debug] id: ' + ai.id) + '<br/>');
      buf.add(Const.smalldebug('[debug] pos: (' + ai.x + ',' + ai.y + ')') + '<br/>');
      buf.add(Const.smalldebug('[debug] alertness: ' + ai.alertness) + '<br/>');
      addDebugListRow(buf, 'abilities', getAbilitiesText(ai));
      addDebugListRow(buf, 'hidden effects', getHiddenEffectsText(ai));
      addDebugListRow(buf, 'inventory', ai.inventory.toString());
      addDebugListRow(buf, 'skills', ai.skills.toString());
      addDebugListRow(buf, 'organs', ai.organs.toString());
      addDebugListRow(buf, 'traits', getTraitsText(ai));
      buf.add('</div>');
    }

// append the debug detail block for an object. the model key and the two tile flags are here
// because they are the three things about an object that are invisible on screen and wrong often
  function addObjectDebugBlock(buf: StringBuf, o: AreaObject)
    {
      buf.add('<div class="area-tip-debug">');
      buf.add(Const.smalldebug('[debug] id: ' + o.id) + '<br/>');
      buf.add(Const.smalldebug('[debug] type: ' + o.type) + '<br/>');
      buf.add(Const.smalldebug('[debug] model: ' + o.getModelKey()) + '<br/>');
      buf.add(Const.smalldebug('[debug] pos: (' + o.x + ',' + o.y + ')') + '<br/>');
      buf.add(Const.smalldebug('[debug] known: ' + o.known() +
        ' walk: ' + o.isWalkable() +
        ' see: ' + o.canSeeThrough()) + '<br/>');
      var linked = o.getLinkedAI();
      if (linked.length > 0)
        {
          var list = [];
          for (ai in linked)
            list.push(ai.id + '@' + ai.x + ',' + ai.y);
          addDebugListRow(buf, 'linked ai', list.join(', '));
        }
      buf.add('</div>');
    }

// get abilities text for debug tooltip
  function getAbilitiesText(ai: AI): String
    {
      var list = [];
      for (ability in ai.abilities.iterator())
        {
          var s = '' + ability.id;
          if (ability.timeout > 0)
            s += ' [' + ability.timeout + ']';
          list.push(s);
        }
      return list.join(', ');
    }

// get hidden effects text for debug tooltip (visible ones show in the normal block)
  function getHiddenEffectsText(ai: AI): String
    {
      var list = [];
      for (effect in ai.effects)
        if (effect.isHidden)
          list.push(effect.type + ' pts:' + effect.points);
      return list.join(', ');
    }

// get traits text for debug tooltip
  function getTraitsText(ai: AI): String
    {
      var list = [];
      for (trait in ai.traits)
        list.push('' + trait);
      return list.join(', ');
    }

// add debug list row only when value is not empty
  inline function addDebugListRow(buf: StringBuf, name: String, value: String)
    {
      if (value == null || value == '')
        return;
      buf.add(Const.smalldebug('[debug] ' + name + ': ' + value) + '<br/>');
    }
}
