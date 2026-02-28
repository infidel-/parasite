// game load deserialization and state restoration

#if electron
import js.node.Fs;
#end
import haxe.Json;

import game.Game;

class Loader
{
// load game from a slot and restore all runtime links
  public static function load(game: Game, slotID: Int)
    {
      // clear old game state before loading
      trace('====== RESTART PRE ' + game.area.id);
      game.restartPre();
      trace('====== LOAD ' + game.area.id);

#if electron
      try {
        var s = Fs.readFileSync(getSavePath(slotID), 'utf8');
        var o: _SaveGame = Json.parse(s);
        loadObject(game, o.game, game, 'game', 0);

        // restore region and area pointers
        game.region = game.world.get(o.game.regionID);
        game.area = game.region.get(o.game.areaID);
      }
      catch (e: Dynamic)
        {
          game.ui.onError('load game: ' + e, '', -1, -1, {
            stack: haxe.CallStack.toString(haxe.CallStack.exceptionStack()),
          });
          return;
        }
#end

      // run post-load initialization chain
      trace('====== ENTER ' + game.area.id);
      game.timeline.loadPost();
      game.world.loadPost();
      game.managerArea.loadPost();
      game.group.loadPost();
      if (game.location == LOCATION_AREA)
        {
          game.area.currentAreaLoadPost();
          game.playerArea.loadPost();
        }
      else if (game.location == LOCATION_REGION)
        game.region.enter();
      game.player.loadPost();
      game.scene.sounds.loadPost();
      for (cult in game.cults)
        cult.loadPost();
      game.scene.updateCamera();
      game.log('Game loaded from slot ' + slotID + '.');
    }

// build save file path from slot
  static function getSavePath(slotID: Int): String
    {
      return 'save' + (slotID < 10 ? '0' : '') + slotID + '.json';
    }

// load serialized source object into destination recursively
  static function loadObject(game: Game, src: Dynamic, dst: Dynamic, name: String, depth: Int)
    {
      for (f in Reflect.fields(src))
        {
          // ignore class ID marker
          if (f == '_classID')
            continue;
          var srcval: Dynamic = Reflect.field(src, f);
          var dstval = Reflect.field(dst, f);
          var isEnum: Bool = untyped srcval._isEnum;
          var classID: String = srcval._classID;

          // map enum values directly
          switch (Type.typeof(dstval)) {
            case TEnum(e):
              Reflect.setField(dst, f, initEnum(name, srcval, depth + 1));
              continue;
            default:
          }
          if (isEnum)
            {
              Reflect.setField(dst, f, initEnum(name, srcval, depth + 1));
              continue;
            }

          // map scalar primitives
          if (Std.isOfType(srcval, Int) ||
              Std.isOfType(srcval, Float) ||
              Std.isOfType(srcval, Bool) ||
              Std.isOfType(srcval, String))
            Reflect.setField(dst, f, srcval);

          // map arrays and lists
          else if (Std.isOfType(srcval, Array) ||
              Std.isOfType(dstval, Array) ||
              Std.isOfType(dstval, List))
            {
              var dsttmp = [];
              var srctmp: Array<Dynamic> = untyped srcval;
              for (el in srctmp)
                dsttmp.push(initValue(game, name + '.' + f + '[]', el, depth + 1));
              if (Std.isOfType(dstval, List))
                Reflect.setField(dst, f, Lambda.list(dsttmp));
              else Reflect.setField(dst, f, dsttmp);
            }

          // map int-key maps
          else if (Std.isOfType(dstval, haxe.ds.IntMap))
            {
              var dsttmp = new Map<Int, Dynamic>();
              for (ff in Reflect.fields(srcval))
                {
                  var el = Reflect.field(srcval, ff);
                  var key = Std.parseInt(ff);
                  dsttmp.set(key,
                    initValue(game, name + '[' + ff + ']', el, depth + 1));
                }
              Reflect.setField(dst, f, dsttmp);
            }

          // map string-key maps
          else if (Std.isOfType(dstval, haxe.ds.StringMap))
            {
              var dsttmp = new Map<String, Dynamic>();
              for (ff in Reflect.fields(srcval))
                {
                  var el = Reflect.field(srcval, ff);
                  dsttmp.set(ff,
                    initValue(game, name + '[' + ff + ']', el, depth + 1));
                }
              Reflect.setField(dst, f, dsttmp);
            }

          // map plain anonymous objects
          else if (classID == null &&
              Type.typeof(srcval) == TObject)
            {
              Reflect.setField(dst, f,
                initValue(game, name + '.' + f, srcval, depth + 1));
            }

          // recursively map save objects
          else if (Std.isOfType(dstval, _SaveObject))
            {
              loadObject(game, srcval, dstval, f, depth + 1);
              if (dstval.initPost != null)
                dstval.initPost(true);
              Reflect.setField(dst, f, dstval);
            }

          // initialize missing destination object
          else if (dstval == null)
            {
              dstval = initValue(game, name + '.' + f, srcval, depth + 1);
              Reflect.setField(dst, f, dstval);
            }
          else trace(name + '.' + f + ' type is unsupported (' +
            classID + ').');
        }

      // restore common circular references
      var hasUI: Bool = untyped src._hasUI;
      if (hasUI == null)
        hasUI = false;
      if (hasUI)
        dst.ui = game.ui;
      var hasGame: Bool = untyped src._hasGame;
      if (hasGame == null)
        hasGame = false;
      if (hasGame)
        dst.game = game;
    }

// initialize one serialized value recursively
  static function initValue(game: Game, name: String, src: Dynamic, depth: Int): Dynamic
    {
      if (depth > 20)
        throw 'Depth too high: ' + depth + ' ' + name;

      // return scalar primitives directly
      if (src == null ||
          Std.isOfType(src, Int) ||
          Std.isOfType(src, Float) ||
          Std.isOfType(src, Bool) ||
          Std.isOfType(src, String))
        return src;

      // initialize enum wrapper
      var isEnum: Bool = untyped src._isEnum;
      if (isEnum)
        return initEnum(name, src, depth + 1);

      // initialize arrays recursively
      if (Std.isOfType(src, Array))
        {
          var ret = [];
          var arr: Array<Dynamic> = untyped src;
          for (el in arr)
            ret.push(initValue(game, name + '[]', el, depth + 1));
          return ret;
        }

      // initialize class-backed objects
      var srcClassID: String = untyped src._classID;
      if (srcClassID != null)
        return initObject(game, name, src, depth + 1);

      // initialize plain object fields
      var ret: Dynamic = {};
      for (f in Reflect.fields(src))
        {
          if (f == '_classID' ||
              f == '_isEnum')
            continue;
          Reflect.setField(ret, f,
            initValue(game, name + '.' + f, Reflect.field(src, f), depth + 1));
        }
      return ret;
    }

// initialize enum from serialized wrapper
  static function initEnum(name: String, src: Dynamic, depth: Int): Dynamic
    {
      var classID: String = untyped src._classID;
      var ee = Type.resolveEnum(classID);
      if (ee == null)
        throw 'No such enum: ' + classID;
      return Type.createEnum(ee, untyped src.val);
    }

// create class instance and populate it from serialized object
  static function initObject(game: Game, name: String, src: Dynamic, depth: Int): Dynamic
    {
      var isEnum: Bool = untyped src._isEnum;
      if (isEnum)
        return initEnum(name, src, depth);

      // read common circular reference markers
      var hasUI: Bool = untyped src._hasUI;
      if (hasUI == null)
        hasUI = false;
      var hasGame: Bool = untyped src._hasGame;
      if (hasGame == null)
        hasGame = false;

      // create destination instance from class name
      var srcClassID: String = untyped src._classID;
      var srcClass = Type.resolveClass(srcClassID);
      if (srcClass == null)
        throw 'Could not resolve class ' + srcClassID + ' src:' + src;
      var dst = Type.createEmptyInstance(srcClass);

      // restore common references and initialization hooks
      if (hasGame)
        dst.game = game;
      if (hasUI)
        dst.ui = game.ui;
      if (dst.init != null)
        dst.init();
      else trace('no init for ' + name);
      loadObject(game, src, dst, name, depth + 1);
      if (dst.initPost != null)
        dst.initPost(true);
      return dst;
    }
}
