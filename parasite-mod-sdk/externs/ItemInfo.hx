// engine ItemInfo extern — resolves to window.parasiteHx.ItemInfo at runtime
// ModLoader publishes window.parasiteHx = $hxClasses before any mod imports,
// so this reference is live when the mod's IIFE evaluates `class X extends ItemInfo`
// minimal v1 surface — covers id/type/name fields used in registerItem flow;
// auto-generated full externs land in v1.1+ via haxe -xml

@:native('window.parasiteHx.ItemInfo')
extern class ItemInfo
{
  // unique key in ItemsConst.infos map; collisions = last-wins + log.
  // namespace with mod id prefix to avoid clashing with built-ins or other mods
  public var id: String;
  // category bucket (freeform string); engine inline-checks specific values
  // ('misc', 'clothing', 'phone', 'radio', 'readable', etc.) for inventory grouping & behavior
  public var type: String;
  // display name shown once player has learned this item
  public var name: String;
  // optional alternate names; if set, engine picks a random one per instance as display name
  public var names: Array<String>;
  // display name shown before the player has learned this item ('odd trinket', etc.)
  public var unknown: String;
  // whether player has learned this item; engine flips at runtime on pickup/inspect.
  // set true in subclass ctor only for items that should never need learning (e.g. shipParts)
  public var isKnown: Bool;

  // game arg is engine Game instance; untyped pending Game extern
  public function new(game: Dynamic): Void;
}
