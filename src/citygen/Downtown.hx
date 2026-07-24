package citygen;

import citygen.CityConfig.*;
import citygen.CityModel;
import citygen.CityProfile;

// downtown-only massing logic, kept out of the residential hot path. CityGen.leaf()
// delegates here only when profile.downtown, so none of this touches the default
// generation stream.
class Downtown {
  // convert a floor count to a glass-tower height, snapped to a whole number of CELLs.
  // the curtain wall is cell-locked (Buildings.faceMat: repeat_v = round(h/CELL)), so a
  // CELL-multiple height gives the window grid a pitch of exactly CELL — the ground band
  // (GROUND_H == CELL) and every setback deck then land on a row boundary instead of
  // slicing a window in half. the raw GROUND_H + f*FLOOR_H + TOP_MARGIN quantization
  // shares no common grid with CELL and misaligned on ~95% of decks.
  // the top row stays a real window floor: the downtown coping sits ON the wall head instead
  // of hanging over it (Roofs.addDowntownRoof), so nothing has to be spent capping it
  public static inline function glassHeight(f:Int):Float
    return CELL * Math.round((GROUND_H + f * FLOOR_H + TOP_MARGIN) / CELL);

  // try to emit a stepped setback tower into `out` from a leaf footprint: N concentric
  // pieces, each tier inset per side and TALLER than the one below, so the narrower upper
  // shafts rise out of the wider base's roofline (wedding-cake massing). only the base
  // reaches the ground — every tier above records its deck in buriedH and the renderer
  // starts its box there (Buildings.build), so no shaft stands inside the tier below.
  // pieces are marked shapeKeep so the buried inner tiers survive the landlocked/blank-box
  // drops, and winForce'd on all sides so the exposed shafts get windows all round.
  // returns true if a tower was emitted; false (roll failed / footprint too small) lets
  // the caller fall through to a plain (still tall) downtown office box.
  public static function tryTower(out:Array<Building>, x0:Int, y0:Int, x1:Int, y1:Int,
      floors:Int, roof:Int, facade:Int, rng:Void->Float, p:CityProfile):Bool {
    var w = x1 - x0 + 1;
    var d = y1 - y0 + 1;
    var minSide = w < d ? w : d;
    // need room for at least a base + one real setback (>=3 cells left after inset)
    if (minSide < 5 ||
        p.towerInset < 1 ||
        rng() >= p.towerStepChance)
      return false;

    var tiers = p.towerMinTiers + Std.int(rng() * (p.towerMaxTiers - p.towerMinTiers + 1));
    // clamp tiers so every inset keeps a >=3-cell top tier
    var maxTiers = 1 + Std.int((minSide - 3) / (2 * p.towerInset));
    if (tiers > maxTiers) tiers = maxTiers;
    if (tiers < 1) tiers = 1;
    if (tiers < 2) return false; // a single tier is just a plain box — let the caller make it

    var cap = p.floorCap[facade];
    // base floors: keep the drawn count but leave headroom to grow toward the cap
    var baseF = floors;
    if (baseF > cap - (tiers - 1)) baseF = cap - (tiers - 1);
    if (baseF < p.minFloors) baseF = p.minFloors;
    // per-tier floor growth so the top tier lands near the cap (randomized, >=2)
    var grow = 2 + Std.int((cap - baseF) / tiers);

    var pieces:Array<Building> = [];
    var cx0 = x0, cy0 = y0, cx1 = x1, cy1 = y1;
    var f = baseF;
    var prevH = 0.0; // roofline of the tier directly below (0 for the base)
    for (i in 0...tiers) {
      // each tier above the base steps back; randomize the step so growth isn't uniform
      if (i > 0) {
        // asymmetric inset: base inset per side, plus an occasional extra cell on a random side
        var extra = rng() < 0.4 ? 1 : 0;
        var side = Std.int(rng() * 4);
        cx0 += p.towerInset + (side == 3 ? extra : 0);
        cx1 -= p.towerInset + (side == 2 ? extra : 0);
        cy0 += p.towerInset + (side == 1 ? extra : 0);
        cy1 -= p.towerInset + (side == 0 ? extra : 0);
        f += grow + Std.int(rng() * 2);
        if (f > cap) f = cap;
      }
      // stop if a tier would collapse below a real footprint, or turn into a razor blade —
      // an inset eats the SHORT side twice as fast in relative terms, so a merely oblong
      // base (5x15) reaches a 3x13 slab in one step
      var tw = cx1 - cx0 + 1, td = cy1 - cy0 + 1;
      if (tw < 3 ||
          td < 3 ||
          (tw > td ? tw : td) > (tw < td ? tw : td) * MAX_ASPECT)
        break;
      var h = glassHeight(f);
      // a tier has to clear the deck it stands on by a real amount, else its exposed shaft is
      // a sliver of wall with the window grid running down inside the tier below. seen at both
      // extremes: tiers rising one CELL, and tiers landing at EXACTLY the height below
      // (invisible, coplanar roofs)
      var minH = prevH + 2 * CELL;
      if (h < minH) h = minH;
      if (h > glassHeight(cap)) break; // grown past this facade's storey cap — stop stacking
      var b = new Building(cx0, cy0, cx1 - cx0 + 1, cy1 - cy0 + 1,
        h, roof, facade, [0, 1, 2, 3]);
      b.shapeKeep = true; // buried inner tiers must survive the landlocked/blank drops
      // everything below the tier below's roofline is enclosed by that tier — record the deck
      // height so the renderer skips windows/accents there (both heights are CELL multiples,
      // so the deck sits exactly on a window-row boundary)
      b.buriedH = prevH;
      pieces.push(b);
      out.push(b);
      prevH = h;
    }
    if (pieces.length == 0) return false; // the base itself failed the footprint/aspect test — let the caller box it
    // only the topmost tier carries a mechanical penthouse — every lower tier's centre is
    // occupied by the tier above it, so a penthouse there would punch through that shaft
    for (i in 0...pieces.length - 1) pieces[i].roofPenthouse = false;
    return true;
  }
}
