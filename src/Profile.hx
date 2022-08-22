// user profile storage

#if electron
import js.node.Fs;
#end
import haxe.Json;

import game.Game;
import const.PediaConst;

class Profile
{
  var game: Game;
  public var object: _ProfileObject;

  public function new(g: Game)
    {
      game = g;

      // default values
      object = {
        pediaArticles: {},
      };

      game.debug('profile load');
#if electron
      try {
        var s = Fs.readFileSync('profile.json', 'utf8');
        var obj = Json.parse(s);
        for (f in Reflect.fields(obj))
          Reflect.setField(object, f,
            Reflect.field(obj, f));
      }
      catch (e: Dynamic)
        {
          trace(e);
        }
#end
    }

// add new pedia article to known list
// return true on success
  public function addPediaArticle(id: String, ?showMessage: Bool = true): Bool
    {
      // already known
      if (object.pediaArticles.get(id) > 0)
        return false;
      object.pediaArticles.set(id, 1);
      if (showMessage)
        game.log(Const.small('New pedia article available: ' +
          PediaConst.getName(id) + '.'), COLOR_PEDIA);
      var pedia: jsui.Pedia = cast game.ui.getComponent(UISTATE_PEDIA);
      pedia.newArticle(id);
      save();
      return true;
    }

// mark pedia article as read
  public function markPediaArticle(id: String)
    {
      // already read
      if (object.pediaArticles.get(id) > 1)
        return;
      object.pediaArticles.set(id, 2);
      save();
    }

// get pedia article state
  public function getPediaArticle(id: String): Int
    {
      return object.pediaArticles.get(id);
    }

// dump current config
  public function dump(isHTML: Bool)
    {
      game.log('' + object, COLOR_DEBUG);
    }

// save config
  public function save()
    {
      game.debug('profile save');
#if electron
      Fs.writeFileSync('profile.json',
        Json.stringify(object, null, '  '), 'utf8');
#end
    }
}

typedef _ProfileObject = {
  var pediaArticles: haxe.DynamicAccess<Int>;
}
