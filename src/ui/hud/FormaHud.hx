// hud forma block: resource ledger, organ tray, key legend and tool tooltip of the cult base build mode
package ui.hud;

import js.Browser.document;
import js.Browser.window;
import js.html.DivElement;
import js.html.Element;
import js.html.EventTarget;
import js.html.MouseEvent;

import const.CultBaseConst;
import cult.base.CultBase;
import cult.base.CultBaseResources;
import game.*;
import l10n.Loc;
import mods.AssetPath;

// one tray tool: an organ to grow or a custos to craft
typedef FormaTool = {
  // organ type name, or the custos type passed to createCustos
  var id: String;
  // organ type, null for a custos
  var organ: _CultBaseOrganType;
  // key that picks it, shown on the tile
  var key: String;
  // untranslated full name
  var name: String;
  // untranslated short tray name
  var shortName: String;
  // untranslated description
  var desc: String;
  var cost: CultBaseResources;
  // footprint in tiles
  var w: Int;
  var h: Int;
  // highest level, 1 for custodes
  var maxLevel: Int;
  // creatures64.png cell of a custos, ignored for an organ
  var row: Int;
}

// one titled tray group
typedef FormaGroup = {
  // untranslated title, {n} and {cap} filled with the custodes count for the custodes group
  var title: String;
  var tools: Array<FormaTool>;
}

class FormaHud
{
  static inline var TINT = 'rgba(253, 151, 255, .38)'; // colour layer over the tray sprites
  static var RES_NAMES = [ 'flesh', 'blood', 'bone' ];
  static inline var TUBE_PX = 194; // inner width of a reservoir tube
  var game: Game;
  var hud: HUD;
  var root: DivElement;
  var ledger: DivElement;
  var tray: DivElement;
  var keys: DivElement;
  var detail: DivElement;
  var tools: Map<String, FormaTool>;
  var groups: Array<FormaGroup>;
  var cache: Map<String, String>; // last html set into each block
  var hoverTool: String; // tray tool under the mouse or the keyboard focus
  var keyTip: String; // tool picked by key, its tooltip stays until the cursor moves
  var lastCursor: Int; // cursor tile of the last update, packed x + y * 10000
  // custos picked in the tray (createCustos type), null when the organ in base.selectedType is the tool
  public var selectedCustos: String;
  // cost shown biting the reservoirs instead of the picked tool's, null for none
  public var peek: CultBaseResources;
  // rows of the open tend menu, 0 when closed
  public var tendRows: Int;

  public function new(g: Game, h: HUD)
    {
      game = g;
      hud = h;
      cache = new Map();
      hoverTool = null;
      keyTip = null;
      lastCursor = -1;
      selectedCustos = null;
      peek = null;
      tendRows = 0;
      initTools();

      root = document.createDivElement();
      root.id = 'hud-forma';
      root.style.display = 'none';
      ledger = block('fm-ledger', 'fm-panel');
      tray = block('fm-tray', 'fm-panel');
      keys = block('fm-keys', '');
      detail = block('fm-detail', 'fm-panel fm-card');
      detail.style.display = 'none';
      h.container.appendChild(root);

      // tray: hover or focus shows a tool's tooltip and previews its cost, click picks it
      tray.onmouseover = function (e: MouseEvent) setHover(toolOf(e.target));
      tray.onmouseleave = function (e: MouseEvent) setHover(null);
      tray.addEventListener('focusin', function (e) setHover(toolOf(e.target)));
      tray.addEventListener('focusout', function (e) setHover(null));
      // keep the keyboard on the game: a clicked tile must not take focus
      tray.onmousedown = function (e: MouseEvent) e.preventDefault();
      tray.onclick = function (e: MouseEvent)
        {
          var id = toolOf(e.target);
          if (id == null)
            return;
          game.scene.sounds.play('click-action');
          pick(id, false);
        };
    }

// creates one block of the panel
  function block(id: String, cls: String): DivElement
    {
      var el = document.createDivElement();
      el.id = 'hud-' + id;
      el.className = cls;
      root.appendChild(el);
      return el;
    }

// builds the tray tools and their groups
  function initTools()
    {
      tools = new Map();
      var organTool = function (type: _CultBaseOrganType, key: String): FormaTool
        {
          var info = CultBaseConst.info(type);
          var ret = {
            id: (type : String),
            organ: type,
            key: key,
            name: info.name,
            shortName: info.shortName,
            desc: info.desc,
            cost: info.cost,
            w: info.w,
            h: info.h,
            maxLevel: info.maxLevel,
            row: 0,
          };
          tools.set(ret.id, ret);
          return ret;
        };
      var custosTool = function (id: String, name: String, desc: String, key: String, row: Int): FormaTool
        {
          var ret = {
            id: id,
            organ: null,
            key: key,
            name: name,
            shortName: name,
            desc: desc,
            cost: CultBaseConst.custosCost,
            w: 1,
            h: 1,
            maxLevel: 1,
            row: row,
          };
          tools.set(id, ret);
          return ret;
        };
      groups = [
        {
          title: N('Defense'),
          tools: [
            organTool(RIBWALL, '1'),
            organTool(RIBGATE, '2'),
            organTool(SPINE_TURRET, '3'),
            organTool(BLOOD_TRAP, '4'),
          ],
        },
        {
          title: N('Growth'),
          tools: [
            organTool(FLESH_BLOCK, '5'),
            organTool(RAT_NEST, '6'),
            organTool(CRUSHER, '7'),
            organTool(GARBAGE_HEAP, '8'),
          ],
        },
        {
          title: N('Upkeep'),
          tools: [
            organTool(BODY_STORAGE, '9'),
            organTool(CAULDRON, '0'),
          ],
        },
        {
          title: N('Custodes {n}/{cap}'),
          tools: [
            custosTool('firmus', N('Firmus'),
              N('A sturdy guard that holds its tile. Strength 8, constitution 12.'), '-', 0),
            custosTool('mordax', N('Mordax'),
              N('A savage guard that holds its tile. Strength 10, constitution 7.'), '=', 1),
          ],
        },
      ];
    }

// returns the tray tool id under an event target, null when none
  function toolOf(target: EventTarget): String
    {
      var tile = (cast target : Element).closest('[data-t]');
      if (tile == null)
        return null;
      return tile.getAttribute('data-t');
    }

// sets the hovered tool and refreshes what depends on it
  function setHover(id: String)
    {
      if (hoverTool == id)
        return;
      hoverTool = id;
      var base = game.cults[0].base;
      renderLedger(base);
      renderDetail(base);
    }

// picks a tray tool: an organ becomes the build tool, a custos the craft tool
  public function pick(id: String, fromKey: Bool)
    {
      var base = game.cults[0].base;
      var tool = tools.get(id);
      if (tool.organ != null)
        {
          selectedCustos = null;
          base.selectedType = tool.organ;
        }
      else selectedCustos = id;
      keyTip = (fromKey ? id : null);
      game.updateHUD();
    }

// returns the id of the picked tool
  function selectedID(base: CultBase): String
    {
      return (selectedCustos != null ? selectedCustos : (base.selectedType : String));
    }

// updates every block, or hides the panel outside forma
  public function update()
    {
      var shown = (hud.state == HUD_BASE_BUILDING);
      root.style.display = (shown ? '' : 'none');
      if (!shown)
        {
          hoverTool = null;
          keyTip = null;
          return;
        }
      var base = game.cults[0].base;
      // a key pick's tooltip goes when the cursor moves
      var cursor = base.cursorX + base.cursorY * 10000;
      if (cursor != lastCursor)
        keyTip = null;
      lastCursor = cursor;
      renderLedger(base);
      renderTray(base);
      renderKeys();
      renderDetail(base);
    }

// sets the html of one block when it changed
  function put(el: DivElement, html: String)
    {
      if (cache.get(el.id) == html)
        return;
      cache.set(el.id, html);
      el.innerHTML = html;
    }

// returns a resource cost as a list of flesh, blood and bone
  function amounts(r: CultBaseResources): Array<Int>
    {
      return [ r.flesh, r.blood, r.bone ];
    }

// returns a resource icon
  function icon(res: String): String
    {
      switch (res)
        {
          case 'flesh':
            return '<svg viewBox="0 0 8 9"><ellipse cx="4" cy="5" rx="3.6" ry="3.4" fill="currentColor"/></svg>';
          case 'blood':
            return '<svg viewBox="0 0 8 9"><path d="M4 .3C5.8 3 7.4 4.6 7.4 6.1A3.4 3.4 0 0 1 .6 6.1C.6 4.6 2.2 3 4 .3Z" fill="currentColor"/></svg>';
          default:
            return '<svg viewBox="0 0 8 9"><path d="M1.6 1.2a1.2 1.2 0 0 1 2 .9L5.9 6.9a1.2 1.2 0 1 1 .5 1.9 1.2 1.2 0 0 1-1.9-.5L2.1 3.6A1.2 1.2 0 0 1 1.6 1.2Z" fill="currentColor"/></svg>';
        }
    }

// returns a cost as three icons and numbers, the resources the base lacks marked
  function costHTML(cost: CultBaseResources, base: CultBase): String
    {
      var have = amounts(base.resources);
      var buf = new StringBuf();
      buf.add('<span class="fm-cost">');
      for (i => v in amounts(cost))
        buf.add('<span class="fm-c-' + RES_NAMES[i] + (v == 0 ? ' z' : '') + (have[i] < v ? ' short' : '') +
          '">' + icon(RES_NAMES[i]) + v + '</span>');
      buf.add('</span>');
      return buf.toString();
    }

// returns the tool a hover or the picked tool puts on the reservoirs
  function costTool(base: CultBase): FormaTool
    {
      return tools.get(hoverTool != null ? hoverTool : selectedID(base));
    }

// returns the tray sprite of a tool: a colour layer blended over the art, clipped to the art's own alpha
  function tint(tool: FormaTool): String
    {
      var src: String;
      var pos: String;
      var size: String;
      var w: Int;
      var h: Int;
      if (tool.organ == null)
        {
          // custodes sheet, 64 px cells
          src = AssetPath.resolve('img/creatures64.png');
          pos = '0 -' + (tool.row * 64) + 'px';
          size = '512px 192px';
          w = 64;
          h = 64;
        }
      else
        {
          // a 2x2 organ shows at half size so every tile is 64 px, never scaled above native
          var cell = (tool.w > 1 ? 32 : 64);
          var atlas = (tool.organ == SPINE_TURRET ?
            CultBaseConst.spineTurretBlock(game.cults[0].base.selectedDirection) :
            CultBaseConst.block(tool.organ));
          src = AssetPath.resolve(CultBaseConst.IMAGE_PATH);
          pos = '-' + (atlas.col * cell) + 'px -' + (atlas.row * cell) + 'px';
          // the atlas is square
          size = (CultBaseConst.IMAGE_COLS * cell) + 'px ' + (CultBaseConst.IMAGE_COLS * cell) + 'px';
          w = tool.w * cell;
          h = tool.h * cell;
        }
      return '<span class="fm-tint" style="--src:url(\'' + src + '\');--pos:' + pos + ';--size:' + size +
        ';width:' + w + 'px;height:' + h + 'px"></span>';
    }

// returns true when a tool cannot be used now
  function isPoor(tool: FormaTool, base: CultBase): Bool
    {
      return !base.resources.canAfford(tool.cost) ||
        (tool.organ == null &&
        (!base.hasWorkingOrgan(CAULDRON) ||
        base.custodes.length >= base.custosCap()));
    }

// renders the reservoirs, income, stats and Corpus Basilica checklist
  function renderLedger(base: CultBase)
    {
      var cap = base.stockpileCap();
      var px = TUBE_PX / cap;
      var cost = amounts(peek != null ? peek : (tendRows > 0 ? new CultBaseResources() : costTool(base).cost));
      var have = amounts(base.resources);
      var buf = new StringBuf();
      buf.add('<h1>' + T('Forma') + '</h1>');
      for (i => res in RES_NAMES)
        {
          // the cost bites the fill, a shortfall overhangs in alert stripes
          var v = have[i];
          var c = cost[i];
          var bite = Std.int(Math.min(c, v));
          var over = Std.int(Math.max(0, c - v));
          var after = (c == 0 ? '' : (over > 0 ? T('short {n}', { n: over }) : '&rarr; ' + (v - c)));
          buf.add('<div class="fm-res fm-r-' + res + '"><span class="fm-name">' +
            (res == 'flesh' ? T('Flesh') : (res == 'blood' ? T('Blood') : T('Bone'))) + '</span><span class="fm-tube">');
          for (p in [ 25, 50, 75 ])
            buf.add('<span class="fm-tick" style="left:' + (2 + p * 1.94) + 'px"></span>');
          buf.add('<i class="fm-keep" style="width:' + ((v - bite) * px) + 'px"></i>' +
            '<i class="fm-bite" style="left:' + (2 + (v - bite) * px) + 'px;width:' + (bite * px) + 'px"></i>');
          if (over > 0)
            buf.add('<i class="fm-over" style="left:' + (2 + v * px) + 'px;width:' + (over * px) + 'px"></i>');
          buf.add('</span><span class="fm-val"><span>' + v + '<small>/' + cap + '</small></span>' +
            '<span class="fm-after' + (over > 0 ? ' short' : '') + '">' + after + '</span></span></div>');
        }
      // income per turn
      buf.add('<div class="fm-income">');
      for (i => v in amounts(base.incomePerTurn().income))
        buf.add('<span class="fm-c-' + RES_NAMES[i] + '">+' + v + '</span>');
      buf.add(T('each turn') + '</div>');
      // bodies, custodes, pressure and the defense timer
      buf.add('<div class="fm-stats"><span>' + T('Bodies') + '<b>' + base.storedBodies + '/' + base.bodyCapacity() + '</b></span>' +
        '<span>' + T('Custodes') + '<b>' + base.custodes.length + '/' + base.custosCap() + '</b></span>' +
        '<span>' + T('Pressure') + '<b>' + base.attackPressure + '</b></span>');
      if (base.activeDefenseMissionID >= 0)
        buf.add('<span class="warn">' + T('Defense in') + '<b>' + base.activeDefenseTimer + '</b></span>');
      buf.add('</div>');
      // Corpus Basilica checklist
      var r = base.readiness();
      buf.add('<div class="fm-basilica"><h2>' + T('Corpus Basilica') + '</h2><ul>' +
        li(T('Heart {n}/3', { n: r.heart }), r.heart >= 3) +
        li(T('Organ levels {n}/10', { n: r.organLevels }), r.organLevels >= 10) +
        li(T('A growth organ'), r.hasGrowth) +
        li(T('Defenses {n}/5', { n: r.defenses }), r.defenses >= 5) +
        li(T('Body storage'), r.hasStorage) +
        li(T('Survived {n}/2', { n: r.survived }), r.survived >= 2) +
        li(T('A Caldarium'), r.hasCauldron) +
        '</ul></div>');
      put(ledger, buf.toString());
    }

// returns one checklist line
  function li(text: String, met: Bool): String
    {
      return '<li' + (met ? ' class="met"' : '') + '>' + text + '</li>';
    }

// renders the organ groups with their keys, costs and the picked tool pressed
  function renderTray(base: CultBase)
    {
      var picked = selectedID(base);
      var buf = new StringBuf();
      for (g in groups)
        {
          buf.add('<div class="fm-group"><h3>' +
            Loc.fmt(Loc.tr(g.title), { n: base.custodes.length, cap: base.custosCap() }) + '</h3><div class="fm-tiles">');
          for (t in g.tools)
            {
              var poor = isPoor(t, base);
              var name = Loc.tr(t.name);
              buf.add('<button type="button" class="fm-tile' + (poor ? ' poor' : '') + '" data-t="' + t.id +
                '" aria-pressed="' + (picked == t.id) + '" aria-label="' + name + (poor ? ', ' + T('not available') : '') +
                '">' + tint(t) + '<span class="fm-key">' + t.key + '</span>');
              if (t.organ == SPINE_TURRET)
                buf.add('<svg class="fm-dir" viewBox="0 0 18 18" style="transform:rotate(' + (base.selectedDirection * 90) +
                  'deg)"><path d="M9 2l6 9h-4v5H7v-5H3z" fill="currentColor"/></svg>');
              buf.add('<span class="fm-nm">' + Loc.tr(t.shortName) + '</span>' + costHTML(t.cost, base) + '</button>');
            }
          buf.add('</div></div>');
        }
      put(tray, buf.toString());
      tray.classList.toggle('inert', tendRows > 0);
    }

// renders the key legend, the tend menu variant while its menu is open
  function renderKeys()
    {
      if (tendRows > 0)
        put(keys, '<span><kbd>1</kbd>&ndash;<kbd>' + tendRows + '</kbd>' + T('choose') + '</span>' +
          '<span><kbd>Esc</kbd>' + T('back') + '</span>' +
          '<span><kbd>&larr;&uarr;&rarr;&darr;</kbd>' + T('move away') + '</span>');
      else put(keys, '<span><kbd>&larr;&uarr;&rarr;&darr;</kbd>' + T('move') + '</span>' +
        '<span><kbd>1</kbd>&ndash;<kbd>0</kbd>' + T('organ') + '</span>' +
        '<span><kbd>-</kbd><kbd>=</kbd>' + T('custos') + '</span>' +
        '<span><kbd>Enter</kbd>' + T('or click: build, craft or tend') + '</span>' +
        '<span><kbd>Q</kbd><kbd>E</kbd>' + T('turn turret') + '</span>' +
        '<span><kbd>F</kbd>' + T('exit') + '</span>');
    }

// returns the footprint and growth line of a tool's tooltip
  function sizeText(tool: FormaTool): String
    {
      if (tool.w > 1)
        return (tool.maxLevel > 1 ? T('2 by 2 tiles, grows to level {max}', { max: tool.maxLevel }) : T('2 by 2 tiles'));
      return (tool.maxLevel > 1 ? T('1 tile, grows to level {max}', { max: tool.maxLevel }) : T('1 tile'));
    }

// renders the tooltip of the hovered tool, or of the key-picked one until the cursor moves
  function renderDetail(base: CultBase)
    {
      var id = (tendRows > 0 ? null : (hoverTool != null ? hoverTool : keyTip));
      if (id == null)
        {
          detail.style.display = 'none';
          return;
        }
      var tool = tools.get(id);
      var buf = new StringBuf();
      buf.add('<div class="latin">' + Loc.tr(tool.name));
      if (tool.organ == SPINE_TURRET)
        {
          var dir = [ T('north'), T('east'), T('south'), T('west') ][base.selectedDirection];
          buf.add(' <span class="facing">' + T('facing {dir}, Q/E to turn', { dir: dir }) + '</span>');
        }
      buf.add('</div><div class="does">' + Loc.tr(tool.desc) + '</div><div class="meta">' + costHTML(tool.cost, base) + '<span>');
      if (tool.organ == null)
        buf.add(base.hasWorkingOrgan(CAULDRON) ?
          T('Custodes {n}/{cap}', { n: base.custodes.length, cap: base.custosCap() }) :
          T('Needs a working Caldarium'));
      else buf.add(sizeText(tool));
      buf.add('</span></div>');
      put(detail, buf.toString());
      detail.style.display = '';
      // above its tile, the arrow on the tile's centre, kept inside the tray's span
      var trayRect = tray.getBoundingClientRect();
      var tile = tray.querySelector('[data-t="' + id + '"]').getBoundingClientRect();
      var centre = tile.left + tile.width / 2;
      var x = Math.max(trayRect.left, Math.min(centre - detail.offsetWidth / 2, trayRect.right - detail.offsetWidth));
      detail.style.bottom = (window.innerHeight - trayRect.top + 12) + 'px';
      detail.style.left = x + 'px';
      detail.style.setProperty('--ax', (centre - x) + 'px');
    }
}
