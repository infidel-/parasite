package render.world;

import citygen.CityConfig;
import render.RenderConfig;
import render.BDump;
import render.Tools;

// post-generation checklist. Runs after every World.build(): compares each building's
// intended front-role (Geom) against what the render passes ACTUALLY emitted
// (winSeen/doorSeen/bandSeen), so a silent blank (e.g. a tall plain tower that rendered
// no windows) or a doorless building surfaces immediately instead of the user flying out
// to find it. FAIL = a guarantee broke; INFO = intended (blank-by-design). Loud HUD badge
// + console + window.__check (drill-down + goto, wired in the debug HUD).
class Check {
  public static var lastFails = 0; // issue count of the latest run (topbar badge)

  public static function run():Void {
    var buildings = WorldCtx.buildings;
    var winSeen = WorldCtx.winSeen;
    var doorSeen = WorldCtx.doorSeen;
    var bandSeen = WorldCtx.bandSeen;
    var noBackDoor = WorldCtx.noBackDoor;
    var fails:Array<{ id:Int, reason:String, line:String }> = [];
    var windowless:Array<Int> = [], doorless:Array<Int> = [], blank:Array<Int> = [];
    var nSimple = 0, nStore = 0, nSmall = 0, nPlain = 0;
    for (i in 0...buildings.length) {
      var b = buildings[i];
      var fi = Geom.frontInfo(b);
      if (fi.simple) { nSimple++; if (fi.small) nSmall++; else if (fi.store) nStore++; else nPlain++; }
      var st = WorldCtx.style;
      // art carries what a render pass would otherwise have to emit: a shop's doors/closures, a
      // metal warehouse's roll-up, and a glass curtain wall's ENTIRE window grid (noWinSlots —
      // Windows.add skips those facades by design, so winSeen is never set for a tower)
      var exemptArt = b.shop >= 0
        || st.isSpecial(b.facade)
        || (st.noWinSlots != null && st.noWinSlots.indexOf(b.facade) >= 0);
      // FAIL: doorless. Only SIMPLE buildings carry the hard guarantee (a front door, street face or
      // anyFront fallback). Composite (+/T/L) pieces door only their own street faces — a buried inner
      // piece legitimately has none while the overall footprint still has doors, so they're exempt.
      // A storefront band IS an entrance: Entrances deliberately skips the door quad on a store that
      // has a street face (the band covers it), so bandSeen satisfies the guarantee on its own —
      // otherwise an island store, banded on every face, reads as doorless.
      if (fi.simple && !doorSeen.exists(b) && !bandSeen.exists(b)) { doorless.push(i); fails.push({ id: i, reason: 'doorless', line: BDump.bline(i, b) }); }
      // FAIL: windows expected but none emitted (landlocked — every face buried / store with no street face)
      if (!exemptArt && Geom.expectWindows(b) && !winSeen.exists(b)) { windowless.push(i); fails.push({ id: i, reason: 'windows expected, none emitted (landlocked?)', line: BDump.bline(i, b) }); }
      // INFO: intended blank box — simple bldg, windows not expected, no storefront band (just a door)
      if (!exemptArt && fi.simple && !Geom.expectWindows(b) && !winSeen.exists(b) && !bandSeen.exists(b)) blank.push(i);
    }
    var share = nSimple > 0 ? Math.round(100.0 * nStore / nSimple) : 0;
    var noBack = [for (b in noBackDoor) buildings.indexOf(b)];
    var pass = fails.length == 0;

    lastFails = fails.length;
    var summary = '[check] ${pass ? "PASS" : "FAIL"} seed ${WorldCtx.seed} — ${buildings.length} bldgs · doorless ${doorless.length} · winless ${windowless.length} · blank-by-design ${blank.length} · noBackDoor ${noBack.length} · store $share%';
    if (pass) js.Browser.console.log(summary);
    else {
      js.Browser.console.error(summary);
      for (f in fails) js.Browser.console.warn('#${f.id} ${f.reason}\n${f.line}');
    }
    if (nSimple >= 20 && (share < 15 || share > 45))
      js.Browser.console.warn('[check] store share $share% off target ${RenderConfig.STORE_PCT}% — check frontInfo hash/gating');

    var el = js.Browser.document.getElementById('check');
    if (el != null) {
      el.textContent = pass ? 'CHECK ✓' : 'CHECK: ${fails.length} ISSUE${fails.length == 1 ? "" : "S"}';
      el.classList.toggle('bad', !pass);
      el.classList.toggle('ok', pass);
    }
    untyped js.Browser.window.__check = {
      pass: pass, fails: fails, windowless: windowless, doorless: doorless, noBackDoor: noBack, blank: blank,
      counts: { bldgs: buildings.length, simple: nSimple, store: nStore, plain: nPlain, small: nSmall, storePct: share },
      // drill-down: fly the free-cam to a flagged building (needs street-debug tools attached)
      goto: function(id:Int) {
        if (Tools.freeCam == null) {
          js.Browser.console.warn('[check] enable street-debug (backquote) first');
          return;
        }
        var b = buildings[id];
        if (b == null) return;
        var cw = CityConfig.cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
        var r = (b.w > b.d ? b.w : b.d) * CityConfig.CELL / 2;
        Tools.freeCam.focus(cw.x, b.h / 2, cw.z, r);
      },
    };
  }
}
