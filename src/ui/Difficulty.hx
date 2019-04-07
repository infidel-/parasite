// difficulty setting window

package ui;

import h2d.Text;
import game.Game;

class Difficulty extends UIWindow
{
  var title: Text;
  var text: Text;
  var currentChoice: _Choice;

  public function new(g: Game)
    {
      super(g, 700, 200);
      currentChoice = null;

      window.x = Std.int((game.scene.win.width - width) / 2);
      window.y = Std.int((game.scene.win.height - height) / 2);

      var tile = game.scene.atlas.getInterface('button');
      var texty = Std.int(15 + game.scene.font.lineHeight);
      text = addText(false, 10, texty, width - 10,
        Std.int(height - 20 - tile.height - texty));
      text.textAlign = Center;

      // after text to be on top of background
      title = new Text(game.scene.font, back);
      title.y = 10;
      title.textAlign = Center;
      title.maxWidth = width;

      var y = Std.int(height - 10 - tile.height);
      addButton(Std.int(width / 2 - 3 * tile.width / 2 - 10), y, 'EASY',
        action.bind(1), onOver.bind(0), onOut);
      addButton(Std.int(width / 2 - tile.width / 2) + 20, y, 'NORMAL',
        action.bind(2), onOver.bind(1), onOut);
      addButton(Std.int(width / 2 + tile.width + 5), y, 'HARD',
        action.bind(3), onOver.bind(2), onOut);
    }


// set choices
  public override function setParams(t: Dynamic)
    {
      currentChoice = choices[t];
      title.text = 'Difficulty: ' + currentChoice.title;
      text.text = 'Choose difficulty setting.';
    }


// action
  public override function action(index: Int)
    {
      var d: _Difficulty = UNSET;
      if (index == 1)
        d = EASY;
      else if (index == 2)
        d = NORMAL;
      else if (index == 3)
        d = HARD;

      // set specific game difficulty setting
      if (currentChoice.id == 'group')
        game.group.difficulty = d;
      else if (currentChoice.id == 'evolution')
        {
          game.player.evolutionManager.difficulty = d;
          game.player.evolutionManager.giveStartingImprovements();
        }
      else if (currentChoice.id == 'timeline')
        game.timeline.difficulty = d;

      game.log('Difficulty selected for ' + currentChoice.title + ': ' + d);

      game.scene.closeWindow();
    }


// on mouse over
  function onOver(id: Int)
    {
      text.text = currentChoice.notes[id];
    }


// on mouse out
  function onOut()
    {
      text.text = 'Choose difficulty setting.';
    }


  static var choices: Map<String, _Choice> = [
    'group' => {
      id: 'group',
      title: 'The Group',
      notes: [
        'Shows the exact numerical group priority information and team stats in skills and knowledges window.',
        'Shows group and team information described in vague words.',
        'No group or team information.',
      ]
    },

    'evolution' => {
      id: 'evolution',
      title: 'Evolution',
      notes: [
        'Gives 4 generic improvements. No limits for maximum improvement level.',
        'Gives 2 generic improvements. Maximum improvement level is 2, except for brain probe.',
        'Gives 1 generic improvement. Maximum improvement level is 1, except for brain probe.',
      ]
    },

    'timeline' => {
      id: 'timeline',
      title: 'Timeline',
      notes: [
        '1-3 clues on each learn attempt. Fast computer research.',
        '1-2 clues on each learn attempt. Normal computer research.',
        '1 clue on each learn attempt. Normal computer research.',
      ]
    },
    ];
}


typedef _Choice = {
  var id: String;
  var title: String;
  var notes: Array<String>;
}
