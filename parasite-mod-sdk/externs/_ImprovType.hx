// evolution improvement category (mirrors engine src/_ImprovType.hx).
// enum-abstract over String; controls which evolution tree the improvement
// belongs to. mods may also pass a plain string because of `from String`.

enum abstract _ImprovType(String) to String from String
{
  // standard improvement, leveled and grouped in the basic tree
  var TYPE_BASIC = 'TYPE_BASIC';
  // unique/special improvement (organs like watcher, ovum, preservator)
  var TYPE_SPECIAL = 'TYPE_SPECIAL';
}
