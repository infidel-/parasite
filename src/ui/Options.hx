// options window

package ui;

import h2d.Anim;
import h2d.HtmlText;
import h2d.Interactive;
import h2d.Text;
import hxd.Event;
import game.Game;

class Options extends UIWindow
{
  var text: HtmlText;
  var restartText: Text;
  var textHeight: Int;
  var ymin: Int;
  var row: Int;
  var groups: Array<Array<Anim>>;

  public function new(g: Game, ?w: Int, ?h: Int)
    {
      // fix options window w,h to not mess with static layout
      w = 600;
      h = 400;
      super(g, w, h);
      center();
      row = 0;
      groups = [];

      // color background and border
      back.beginFill(0x415056, 1);
      back.drawRect(0, 0, w, h);
      back.endFill();
      makeBorder();

      // options list
#if !free
      addSlider('Music volume', game.config.musicVolume,
        function (v: Float) {
          game.config.set('musicVolume', '' + Std.int(v), false);
          game.scene.sounds.musicVolumeChanged();
        }, 0, 100, 'int');
      addSlider('Effects volume', game.config.effectsVolume,
        function (v: Float) {
          game.config.set('effectsVolume', '' + Std.int(v), false);
        }, 0, 100, 'int');
      addSlider('Ambience volume', game.config.ambientVolume,
        function (v: Float) {
          game.config.set('ambientVolume', '' + Std.int(v), false);
          game.scene.sounds.ambientVolumeChanged();
        }, 0, 100, 'int');
#end
      addSlider('Movement delay', game.config.pathDelay,
        function (v: Float) {
          game.config.set('pathDelay', '' + Std.int(v), false);
        }, 0, 500, 'int');
      addSlider('Map scale', game.config.mapScale,
        function (v: Float) {
          game.config.set('mapScale', '' + Const.round(v), false);
          restartText.visible = true;
        }, 0.1, 10, 'round');
      addGroup('Font size', game.config.fontSize, Const.FONTS,
        function (v: Int) {
          game.config.set('fontSize', '' + v, false);
          restartText.visible = true;
        });

      // restart label
      restartText = new Text(font24, back);
      restartText.x = 40;
      restartText.y = Std.int(height - 90);
#if js
      restartText.text = "The changes you've made will require page reload.";
#else
      restartText.text = "The changes you've made will require restart.";
#end
      restartText.visible = false;

      var tile = atlas.getInterface('button');
      textHeight = Std.int(height - 10 - tile.height);
      addButton(-1, textHeight, 'CLOSE', function () {
        game.scene.closeWindow();
        game.config.save(restartText.visible);
      });
    }


// set parameters
  public override function setParams(o: Dynamic)
    {
/*
      var buf = new StringBuf();

      buf.add('test!');
      text.text = buf.toString();
*/
    }


// add radio button group to options
  function addGroup(label: String, val: Int, values: Array<Int>,
      set: Int -> Void)
    {
      // option label
      var y = (row + 1) * 30;
      var tf = new Text(font24, back);
      tf.x = 20;
      tf.y = y;
      tf.text = label;

      var col = 0;
      var x = 210;
      var curGroup = groups.length;
      var anims = [];
      for (v in values)
        {
          // radio button
          var tile1 = atlas.getInterface('radio');
          var tile2 = atlas.getInterface('radioPress');
          var b = new Interactive(tile1.width, tile1.height, back);
          var img = new Anim([ tile1, tile2 ], 15, b);
          img.pause = true;
          if (v == val)
            img.currentFrame = 1;
          anims.push(img);
          b.x = x;
          x += Std.int(tile1.width + 10);
          b.y = y;
          b.onClick = function (e: Event)
            {
              // already pressed
              if (img.currentFrame == 1)
                return;
              img.currentFrame = 1;
              for (a in groups[curGroup])
                if (a != img)
                  a.currentFrame = 0;
              set(v);
            }
          // button label
          var t = new Text(font24, back);
          t.text = '' + v;
          t.x = x;
          x += 40;
          t.y = y;

          col++;
        }

      groups[curGroup] = anims;
    }


// add slider to options
  function addSlider(label: String, val: Float, set: Float -> Void,
      min: Float, max: Float, roundType: String)
    {
      // label
      var y = (row + 1) * 30;
      var tf = new Text(font24, back);
      tf.x = 20;
      tf.y = y;
      tf.text = label;

      // slider
      var tile = atlas.getInterface('sliderBack');
      var sl = new h2d.Slider(Std.int(tile.width),
        Std.int(tile.height), back);
      sl.x = 210;
      sl.y = y;
      sl.minValue = min;
      sl.maxValue = max;
      sl.value = val;
      sl.tile = tile;
      sl.cursorTile = atlas.getInterface('sliderKnob');

      // number
      var tf2 = new Text(font24, back);
      tf2.x = 10 + sl.x + 10 + sl.width;
      tf2.y = y;
      tf2.text = roundValue(sl.value, roundType);

      sl.onChange = function() {
        set(sl.value);
        tf2.text = roundValue(sl.value, roundType);
      };

      row++;
      return sl;
    }



  function roundValue(v: Float, t: String): String
    {
      if (t == 'int')
        return '' + Std.int(v);
      else if (t == 'round')
        return '' + Const.round(v);

      return '?';
    }
}
