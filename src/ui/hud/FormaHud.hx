// hud forma block: resource ledger, organ tray, key legend and tool tooltip of the cult base build mode
package ui.hud;

import js.Browser.document;
import js.Browser.window;
import js.html.DivElement;
import js.html.Element;
import js.html.EventTarget;
import js.html.KeyboardEvent;
import js.html.MouseEvent;

import const.CultBaseConst;
import cult.base.CultBase;
import cult.base.CultBaseOrgan;
import cult.base.CultBaseResources;
import game.*;
import l10n.Loc;
import mods.AssetPath;
import render.Viewport;

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

// what a click or Enter on the cursor tile does with the picked tool
enum FormaAct
{
  // an organ stands here: open its tend menu
  TEND;
  // grow the picked organ
  BUILD;
  // craft the picked custos
  CRAFT;
}

// the verdict for the cursor tile
typedef FormaVerdict = {
  var act: FormaAct;
  // why BUILD or CRAFT is refused, '' when it can go ahead
  var reason: String;
  // the organ to tend, null unless act is TEND
  var organ: CultBaseOrgan;
}

// one row of the tend menu
typedef FormaTendRow = {
  // translated label
  var label: String;
  // cost shown on the row, null when the row shows its reason instead
  var cost: CultBaseResources;
  // why the row cannot run, '' when it can
  var reason: String;
  // runs the row's action, which logs its own refusal
  var run: Void -> Void;
}

// screen box in css px of the footprint the chip and the tend menu hang from
typedef FormaBox = {
  var minX: Float;
  var maxX: Float;
  var minY: Float;
  var maxY: Float;
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
  var chip: DivElement;
  var tend: DivElement;
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
  // organ whose tend menu is open, null when closed
  var tendOrgan: CultBaseOrgan;
  // rows of the last tend render
  var tendList: Array<FormaTendRow>;
  // tiles the chip or the tend menu hangs from, null when none
  var anchor: Array<{ x: Int, y: Int }>;
  var chipW: Float; // measured chip size, -1 after its html changed
  var chipH: Float;
  var tendW: Float; // measured tend menu size, -1 after its html changed
  var tendH: Float;
  var trayTop: Float; // top of the tray in css px, -1 after its html changed

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
      tendOrgan = null;
      tendList = [];
      anchor = null;
      chipW = -1;
      tendW = -1;
      trayTop = -1;
      initTools();

      root = document.createDivElement();
      root.id = 'hud-forma';
      root.style.display = 'none';
      ledger = block('fm-ledger', 'fm-panel');
      tray = block('fm-tray', 'fm-panel');
      keys = block('fm-keys', '');
      detail = block('fm-detail', 'fm-panel fm-card');
      detail.style.display = 'none';
      chip = block('fm-chip', 'fm-panel');
      chip.style.left = '-9999px';
      tend = block('fm-tend', 'fm-panel');
      tend.style.display = 'none';
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

      // tend menu: hover or focus a row previews its cost, click runs it, the mouse never reaches the map
      tend.onmouseover = function (e: MouseEvent) peekRow(rowOf(e.target));
      tend.onmouseleave = function (e: MouseEvent) peekRow(-1);
      tend.addEventListener('focusin', function (e) peekRow(rowOf(e.target)));
      tend.onmousedown = function (e: MouseEvent) e.preventDefault();
      tend.onclick = function (e: MouseEvent)
        {
          var i = rowOf(e.target);
          if (i == -2)
            return;
          game.scene.sounds.play('click-action');
          if (i == -1)
            closeTend();
          else runRow(i);
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
          tendOrgan = null;
          tendRows = 0;
          peek = null;
          anchor = null;
          return;
        }
      var base = game.cults[0].base;
      // the organ under the menu is gone (broken down, replaced by a gate): close it
      if (tendOrgan != null &&
          base.organs.indexOf(tendOrgan) < 0)
        {
          tendOrgan = null;
          tendRows = 0;
          peek = null;
        }
      // a key pick's tooltip goes when the cursor moves
      var cursor = base.cursorX + base.cursorY * 10000;
      if (cursor != lastCursor)
        keyTip = null;
      lastCursor = cursor;
      renderLedger(base);
      renderTray(base);
      renderKeys();
      renderChip(base);
      renderTend(base);
      renderDetail(base);
    }

// sets the html of one block when it changed, returns true when it did
  function put(el: DivElement, html: String): Bool
    {
      if (cache.get(el.id) == html)
        return false;
      cache.set(el.id, html);
      el.innerHTML = html;
      return true;
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
      if (tool.organ == null)
        {
          // custodes sheet, 64 px cells
          return tintHTML(AssetPath.resolve('img/creatures64.png'), '0 -' + (tool.row * 64) + 'px', '512px 192px', 64, 64);
        }
      return tintOrgan(tool.organ, game.cults[0].base.selectedDirection);
    }

// returns the tinted sprite of an organ, a 2x2 one at half size so every tile is 64 px, never scaled above native
  function tintOrgan(type: _CultBaseOrganType, direction: Int): String
    {
      var info = CultBaseConst.info(type);
      var cell = (info.w > 1 ? 32 : 64);
      var atlas = (type == SPINE_TURRET ?
        CultBaseConst.spineTurretBlock(direction) :
        CultBaseConst.block(type));
      // the atlas is square
      return tintHTML(AssetPath.resolve(CultBaseConst.IMAGE_PATH),
        '-' + (atlas.col * cell) + 'px -' + (atlas.row * cell) + 'px',
        (CultBaseConst.IMAGE_COLS * cell) + 'px ' + (CultBaseConst.IMAGE_COLS * cell) + 'px',
        info.w * cell, info.h * cell);
    }

// returns one tinted sprite span: the sheet url, the cell offset, the sheet size and the box
  function tintHTML(src: String, pos: String, size: String, w: Int, h: Int): String
    {
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
          // stock above the cap fills the tube and no more
          var keepPx = Math.min(TUBE_PX, (v - bite) * px);
          var bitePx = Math.min(TUBE_PX - keepPx, bite * px);
          var overLeft = Math.min(TUBE_PX, v * px);
          buf.add('<i class="fm-keep" style="width:' + keepPx + 'px"></i>' +
            '<i class="fm-bite" style="left:' + (2 + keepPx) + 'px;width:' + bitePx + 'px"></i>');
          if (over > 0)
            buf.add('<i class="fm-over" style="left:' + (2 + overLeft) + 'px;width:' + Math.min(TUBE_PX - overLeft, over * px) + 'px"></i>');
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
              // the wall's run, a two-headed arrow east-west or north-south
              else if (t.organ == RIBWALL)
                buf.add('<svg class="fm-dir" viewBox="0 0 18 18" style="transform:rotate(' + (base.selectedDirection % 2 * 90) +
                  'deg)"><path d="M1 9l5-5v3h6V4l5 5-5 5v-3H6v3z" fill="currentColor"/></svg>');
              buf.add('<span class="fm-nm">' + Loc.tr(t.shortName) + '</span>' + costHTML(t.cost, base) + '</button>');
            }
          buf.add('</div></div>');
        }
      if (put(tray, buf.toString()))
        trayTop = -1;
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
        '<span><kbd>Q</kbd><kbd>E</kbd>' + T('turn turret or wall') + '</span>' +
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
      // the chip hides under the tooltip
      chip.style.visibility = (id == null ? '' : 'hidden');
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
      else if (tool.organ == RIBWALL)
        buf.add(' <span class="facing">' + (base.selectedDirection % 2 == 0 ?
          T('runs east to west, Q/E to turn') :
          T('runs north to south, Q/E to turn')) + '</span>');
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

// returns the key code of a tray key
  function codeOf(key: String): String
    {
      return (key == '-' ? 'Minus' : (key == '=' ? 'Equal' : 'Digit' + key));
    }

// handles a key press in forma before the rest of the game sees it, returns true when it was used
  public function onKey(e: KeyboardEvent): Bool
    {
      if (e.ctrlKey ||
          e.altKey ||
          e.metaKey)
        return false;
      var base = game.cults[0].base;
      var code = e.code;
      if (code == 'KeyF')
        {
          exit();
          return true;
        }
      if (code == 'Escape')
        {
          // not used without a tend menu, so the main menu opens as before
          if (tendOrgan == null)
            return false;
          closeTend();
          return true;
        }
      // a turret or wall turn (a wall takes the direction's parity), the quick menu is not available here
      if (code == 'KeyQ' ||
          code == 'KeyE')
        {
          if (tendOrgan == null)
            {
              base.selectedDirection = (base.selectedDirection + (code == 'KeyE' ? 1 : 3)) % 4;
              game.updateHUD();
            }
          return true;
        }
      // the tend menu takes the digits for its rows
      if (tendOrgan != null)
        {
          if (code.indexOf('Digit') == 0)
            {
              var i = Std.parseInt(code.substr(5)) - 1;
              if (i >= 0 &&
                  i < tendRows)
                runRow(i);
              return true;
            }
          // Enter runs the focused row, or closes the menu on Back
          if (code == 'Enter' ||
              code == 'NumpadEnter')
            {
              var focus = document.activeElement;
              var row = (focus == null ? -2 : rowOf(focus));
              if (row == -1)
                closeTend();
              else if (row >= 0)
                runRow(row);
              return true;
            }
          return false;
        }
      for (g in groups)
        for (t in g.tools)
          if (code == codeOf(t.key))
            {
              pick(t.id, true);
              return true;
            }
      if (code == 'Enter' ||
          code == 'NumpadEnter')
        {
          // a focused tray tile picks itself, else Enter acts on the cursor tile
          var focus = document.activeElement;
          var id = (focus == null ? null : toolOf(focus));
          if (id != null)
            pick(id, false);
          else act();
          return true;
        }
      return false;
    }

// leaves forma
  function exit()
    {
      closeTend();
      hud.state = HUD_DEFAULT;
      game.scene.view3d.setTactical(false);
      game.updateHUD();
      game.scene.mouse.update(true);
    }

// returns what a click or Enter on the cursor tile does with the picked tool
  public function verdict(): FormaVerdict
    {
      var base = game.cults[0].base;
      var organ = base.getOrganAt(base.cursorX, base.cursorY);
      // a Porta grows over a Murus, any other organ here is tended
      if (organ != null &&
          !(selectedCustos == null &&
          base.selectedType == RIBGATE &&
          organ.type == RIBWALL))
        return { act: TEND, reason: '', organ: organ };
      if (selectedCustos != null)
        return { act: CRAFT, reason: base.validateCustos(base.cursorX, base.cursorY), organ: null };
      var reason = base.validateBuild(base.selectedType, base.cursorX, base.cursorY);
      if (reason == '' &&
          !base.resources.canAfford(CultBaseConst.buildCost(base.selectedType)))
        reason = T('Not enough base resources.');
      return { act: BUILD, reason: reason, organ: null };
    }

// does what a click or Enter on the cursor tile does: tend an organ, craft the picked custos or grow the picked organ
  public function act()
    {
      var base = game.cults[0].base;
      var v = verdict();
      switch (v.act)
        {
          case TEND:
            openTend(v.organ);
          case CRAFT:
            base.createCustos(selectedCustos);
          case BUILD:
            base.buildSelected();
        }
    }

// a click on a map tile: with the tend menu open it only closes it and moves the cursor, else it moves the cursor and acts
  public function onMapClick(x: Int, y: Int)
    {
      var base = game.cults[0].base;
      if (!base.canUseCursorTile(x, y))
        return;
      if (tendOrgan != null)
        {
          var same = (base.getOrganAt(x, y) == tendOrgan);
          closeTend();
          if (!same)
            base.setCursor(x, y);
          return;
        }
      base.setCursor(x, y);
      act();
    }

// returns the rows of an organ's tend menu
  function tendOptions(organ: CultBaseOrgan): Array<FormaTendRow>
    {
      var base = game.cults[0].base;
      var info = CultBaseConst.info(organ.type);
      var maxed = (organ.level >= info.maxLevel);
      var whole = (organ.health >= organ.maxHealth() &&
        !organ.broken);
      var ret: Array<FormaTendRow> = [
        {
          label: (maxed ? T('Upgrade') : T('Upgrade to level {n}', { n: organ.level + 1 })),
          cost: (maxed ? null : organ.upgradeCost()),
          reason: base.validateUpgrade(organ),
          run: function () base.upgradeAtCursor(),
        },
        {
          label: T('Repair'),
          cost: (whole ? null : organ.repairCost()),
          reason: base.validateRepair(organ),
          run: function () base.repairAtCursor(),
        },
      ];
      if (organ.type == RIBWALL)
        {
          var reason = base.validateBuild(RIBGATE, organ.x, organ.y);
          var cost = CultBaseConst.buildCost(RIBGATE);
          if (reason == '' &&
              !base.resources.canAfford(cost))
            reason = T('Not enough base resources.');
          ret.push({
            label: T('Grow {organ}', { organ: Loc.tr(CultBaseConst.name(RIBGATE)) }),
            cost: cost,
            reason: reason,
            // builds the gate without changing the picked tool
            run: function ()
              {
                var keep = base.selectedType;
                base.selectedType = RIBGATE;
                var ok = base.buildSelected();
                base.selectedType = keep;
                if (ok)
                  closeTend();
              },
          });
        }
      return ret;
    }

// opens the tend menu of an organ and focuses its first usable row
  function openTend(organ: CultBaseOrgan)
    {
      tendOrgan = organ;
      tendRows = tendOptions(organ).length;
      keyTip = null;
      peek = null;
      game.updateHUD();
      var first = tend.querySelector('.fm-opt:not(.off)');
      if (first != null)
        (cast first : js.html.HtmlElement).focus();
    }

// closes the tend menu and hands the keyboard back to the game
  public function closeTend()
    {
      if (tendOrgan == null)
        return;
      tendOrgan = null;
      tendRows = 0;
      peek = null;
      game.ui.focus();
      game.updateHUD();
    }

// runs one tend row, which logs its own refusal
  function runRow(i: Int)
    {
      tendList[i].run();
      peek = null;
      game.updateHUD();
    }

// returns the tend row under an event target: its index, -1 for Back, -2 for none
  function rowOf(target: EventTarget): Int
    {
      var el = (cast target : Element).closest('[data-opt]');
      if (el == null)
        return -2;
      var v = el.getAttribute('data-opt');
      return (v == 'back' ? -1 : Std.parseInt(v));
    }

// previews the cost of a tend row in the reservoirs, none for Back or no row
  function peekRow(i: Int)
    {
      var c = (i >= 0 && i < tendList.length ? tendList[i].cost : null);
      if (c == peek)
        return;
      peek = c;
      renderLedger(game.cults[0].base);
    }

// returns the tiles a verdict is about: the tended organ's, the picked organ's or the cursor tile
  function footprintOf(v: FormaVerdict, base: CultBase): Array<{ x: Int, y: Int }>
    {
      if (v.act == TEND)
        return CultBaseConst.footprint(v.organ.type, v.organ.x, v.organ.y);
      if (v.act == CRAFT)
        return [ { x: base.cursorX, y: base.cursorY } ];
      return CultBaseConst.footprint(base.selectedType, base.cursorX, base.cursorY);
    }

// returns an organ's health bar and numbers for the chip
  function hpHTML(organ: CultBaseOrgan): String
    {
      return '<span class="fm-hp' + (organ.health * 2 < organ.maxHealth() ? ' low' : '') + '"><i style="width:' +
        (100 * organ.health / organ.maxHealth()) + '%"></i></span>' + organ.health + '/' + organ.maxHealth();
    }

// renders the one-line chip under the footprint: what a click here does, or why it cannot
  function renderChip(base: CultBase)
    {
      var v = verdict();
      anchor = footprintOf(v, base);
      chip.style.display = (tendOrgan != null ? 'none' : '');
      var html: String;
      if (v.act == TEND)
        html = Loc.tr(CultBaseConst.name(v.organ.type)) + hpHTML(v.organ) +
          '<span class="sub">' + T('Click to tend') + '</span>';
      else if (v.reason != '')
        html = v.reason;
      else if (v.act == CRAFT)
        html = T('Click to craft {name}', { name: Loc.tr(tools.get(selectedCustos).name) });
      else html = T('Click to build {name}', { name: Loc.tr(CultBaseConst.name(base.selectedType)) });
      chip.classList.toggle('no', v.act != TEND && v.reason != '');
      if (put(chip, html))
        chipW = -1;
    }

// renders the tend menu: the organ, its rows and Back
  function renderTend(base: CultBase)
    {
      if (tendOrgan == null)
        {
          tend.style.display = 'none';
          return;
        }
      var o = tendOrgan;
      var info = CultBaseConst.info(o.type);
      anchor = CultBaseConst.footprint(o.type, o.x, o.y);
      tendList = tendOptions(o);
      tendRows = tendList.length;
      var buf = new StringBuf();
      buf.add('<div class="fm-tendbox"><div class="fm-who">' + tintOrgan(o.type, o.direction) + '<div><div class="fm-latin">' +
        Loc.tr(info.name) + '</div><div class="fm-lv">' +
        (o.broken ? T('Level {n} of {max}, broken', { n: o.level, max: info.maxLevel }) :
        T('Level {n} of {max}', { n: o.level, max: info.maxLevel })) +
        '</div><div class="fm-hp' + (o.health * 2 < o.maxHealth() ? ' low' : '') + '"><i style="width:' +
        (100 * o.health / o.maxHealth()) + '%"></i></div><div class="fm-hpn">' +
        T('{hp}/{max} health', { hp: o.health, max: o.maxHealth() }) + '</div></div></div><div class="fm-opts">');
      for (i => row in tendList)
        buf.add('<button type="button" class="fm-opt' + (row.cost == null ? ' off' : '') + '" data-opt="' + i +
          '"><span class="fm-key">' + (i + 1) + '</span><span class="fm-lb">' + row.label + '</span>' +
          (row.cost != null ? costHTML(row.cost, base) : '<span class="fm-why">' + row.reason + '</span>') + '</button>');
      buf.add('<button type="button" class="fm-opt back" data-opt="back"><span class="fm-key">Esc</span>' + T('Back') +
        '</button></div></div>');
      if (put(tend, buf.toString()))
        tendW = -1;
      tend.style.display = '';
    }

// returns the tiles the chip or the tend menu hangs from, null when there are none
  public function anchorCells(): Array<{ x: Int, y: Int }>
    {
      return anchor;
    }

// places the chip under the footprint's screen box, or the tend menu beside it; the box is null when it is off screen
  public function place(b: FormaBox)
    {
      if (b == null)
        {
          chip.style.left = '-9999px';
          tend.style.left = '-9999px';
          return;
        }
      var vw = Viewport.w;
      var vh = Viewport.h;
      if (tendOrgan != null)
        {
          if (tendW < 0)
            {
              tendW = tend.offsetWidth;
              tendH = tend.offsetHeight;
            }
          // beside the organ, flipped near the right edge
          var x = b.maxX + 14;
          if (x + tendW > vw - 20)
            x = b.minX - 14 - tendW;
          tend.style.left = x + 'px';
          tend.style.top = Math.max(64, Math.min(b.minY, vh - tendH - 20)) + 'px';
          return;
        }
      if (chipW < 0)
        {
          chipW = chip.offsetWidth;
          chipH = chip.offsetHeight;
        }
      if (trayTop < 0)
        trayTop = tray.getBoundingClientRect().top - 8;
      // under the footprint, above it when it would hit the tray
      var y = b.maxY + 8;
      if (y + chipH > trayTop)
        y = b.minY - chipH - 8;
      chip.style.left = Math.max(12, Math.min((b.minX + b.maxX) / 2 - chipW / 2, vw - chipW - 12)) + 'px';
      chip.style.top = Math.max(64, y) + 'px';
    }
}
