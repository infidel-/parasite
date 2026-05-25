// pedia group/article shape externs (matches engine const/PediaConst.hx typedefs)
// used by ModContentApi.registerPediaEntry
package const;

typedef _PediaArticleInfo = {
  // unique article id; mod-registered ids must start with `mod-<modID>-`
  // (prefix enforced at registerPediaEntry; collisions = last-wins + log)
  var id: String;
  // display title shown in the pedia article header and table-of-contents row
  var name: String;
  // optional image asset path with no extension (e.g. 'event/foo'); resolved via AssetPath
  @:optional var img: String;
  // full article body; HTML allowed (engine inlines tags like <p>, <ul>, <span>)
  var text: String;
  // unused in mod-registered articles since they are learned automatically
  @:optional var groupAddFlag: Bool;
  // optional pixel font-size override for the body text
  @:optional var font: Int;
}

typedef _PediaGroupInfo = {
  // unique group id; mod-registered ids must start with `mod-<modID>-`
  // (prefix enforced at registerPediaEntry; collisions = last-wins + log)
  var id: String;
  // display title for the group header in the pedia table of contents
  var name: String;
  // ordered list of articles belonging to this group; rendered in array order
  var articles: Array<_PediaArticleInfo>;
}
