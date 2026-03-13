import tiles.UndergroundLab._DecorPadding;

// underground lab decoration metadata shared across decor blocks
typedef _DecorMeta = {
  // stable decoration identifier used by generator logic
  var id: String;
  // semantic tags used for placement and family grouping
  var tags: Array<String>;
  // visual motifs used by room-role weighting
  var motifs: Array<String>;
  // room roles this decoration naturally belongs to
  var roles: Array<String>;
  // optional source image sheet key for object-backed decorations
  @:optional var imageKey: String;
  // optional atmosphere light emitted by this decoration
  @:optional var light: _AtmosphereLightMeta;
  // optional vertical pixel offset for near-top rendering
  @:optional var nearTopOffsetY: Int;
  // optional empty-space requirements around the placed block
  @:optional var padding: _DecorPadding;
  // base candidate weight before role and zone adjustments
  var baseWeight: Int;
  // minimum zone-adjusted weight clamp
  var minZoneWeight: Int;
  // maximum zone-adjusted weight clamp
  var maxZoneWeight: Int;
}
