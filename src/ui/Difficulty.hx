// difficulty selection window — triptych (three image stripes = choices)

package ui;

import js.Browser;
import js.html.DivElement;
import js.html.SpanElement;
import js.html.ImageElement;
import mods.AssetPath;

import game.Game;

class Difficulty extends UIWindow
{
  var diffImg: ImageElement;
  var noteEasy: SpanElement;
  var noteNormal: SpanElement;
  var noteHard: SpanElement;
  var stripButtons: Array<DivElement> = []; // choice stripes by 1-based index (easy/normal/hard)
  var noobStrip: DivElement; // NOOB wedge overlaid on the EASY strip (save category only)
  var noobNote: SpanElement; // NOOB wedge note text
  var diffName: SpanElement;
  var currentChoice: _Choice;

  public function new(g: Game)
    {
      super(g, 'window-difficulty');
      addCorners();

      // triptych: one photo backdrop, three vertical choice stripes
      var strips = Browser.document.createDivElement();
      strips.className = 'difficulty-strips';
      diffImg = Browser.document.createImageElement();
      diffImg.className = 'difficulty-bg';
      strips.appendChild(diffImg);
      noteEasy = addStrip(strips, 'easy', 'EASY', 1);
      noteNormal = addStrip(strips, 'normal', 'NORMAL', 2);
      noteHard = addStrip(strips, 'hard', 'HARD', 3);
      // NOOB wedge: diagonal split of the EASY strip, shown only for the save category
      noobStrip = Browser.document.createDivElement();
      noobStrip.className = 'difficulty-noob';
      noobStrip.innerHTML = '<span class="difficulty-label">NOOB</span>' +
        '<span class="difficulty-note"></span>';
      noobNote = cast noobStrip.querySelector('.difficulty-note');
      noobStrip.onclick = function (e) {
        e.stopPropagation(); // don't bubble to the EASY strip's onclick
        game.scene.sounds.play('click-menu');
        action(0);
      }
      noobStrip.style.display = 'none';
      stripButtons[0].appendChild(noobStrip);
      // inclined divider line on the EASY strip (visible only in split mode via CSS)
      var divide = Browser.document.createDivElement();
      divide.className = 'difficulty-divide';
      stripButtons[0].appendChild(divide);
      window.appendChild(strips);

      // window title (with the choice name) glued to the bottom
      var title = Browser.document.createDivElement();
      title.className = 'difficulty-title';
      title.innerHTML = "<span class='difficulty-title-pre'>Difficulty:</span> ";
      diffName = Browser.document.createSpanElement();
      title.appendChild(diffName);
      window.appendChild(title);
    }

// build one choice stripe (label + note); clicking it picks that difficulty
  function addStrip(parent: DivElement, cls: String, label: String, index: Int): SpanElement
    {
      var strip = Browser.document.createDivElement();
      strip.className = 'difficulty-strip ' + cls;
      var lab = Browser.document.createSpanElement();
      lab.className = 'difficulty-label';
      lab.innerHTML = label;
      strip.appendChild(lab);
      var note = Browser.document.createSpanElement();
      note.className = 'difficulty-note';
      strip.appendChild(note);
      strip.onclick = function (e) {
        game.scene.sounds.play('click-menu');
        action(index);
      }
      parent.appendChild(strip);
      stripButtons[index - 1] = strip;
      return note;
    }

// set parameters (obj is the difficulty type key)
  public override function setParams(obj: Dynamic)
    {
      var t: String = obj;
      currentChoice = choices[t];
      diffImg.src = AssetPath.resolve('img/difficulty/' + currentChoice.id + '.jpg');
      noteEasy.innerHTML = currentChoice.notes[0];
      noteNormal.innerHTML = currentChoice.notes[1];
      noteHard.innerHTML = currentChoice.notes[2];
      diffName.innerHTML = currentChoice.title;
      // NOOB only applies to the save category; reveal its wedge there
      var isSave = (currentChoice.id == 'save');
      stripButtons[0].classList.toggle('split', isSave);
      noobStrip.style.display = (isSave ? '' : 'none');
      if (isSave &&
          currentChoice.notes.length > 3)
        noobNote.innerHTML = currentChoice.notes[3];
    }

  override function hide(?skipAnimation: Bool = false)
    {
      animatedHide();
    }

// dom strip for a 1-based index, so keyboard shortcuts click/animate it
  public override function getButton(index: Int): js.html.Element
    {
      if (index < 1 ||
          index > stripButtons.length)
        return null;
      return stripButtons[index - 1];
    }

// action
  public override function action(index: Int)
    {
      var d: _Difficulty = UNSET;
      if (index == 0)
        d = NOOB;
      else if (index == 1)
        d = EASY;
      else if (index == 2)
        d = NORMAL;
      else if (index == 3)
        d = HARD;
      else return;

      // set specific game difficulty setting
      if (currentChoice.id == 'survival')
        game.player.difficulty = d;
      else if (currentChoice.id == 'group')
        {
          game.group.difficulty = d;
        }
      else if (currentChoice.id == 'evolution')
        {
          game.player.evolutionManager.difficulty = d;
          if (game.player.evolutionManager.difficulty == EASY)
            game.player.vars.habitatsLeft = 1000;
          else if (game.player.evolutionManager.difficulty == NORMAL)
            game.player.vars.habitatsLeft = 10;
          else if (game.player.evolutionManager.difficulty == HARD)
            game.player.vars.habitatsLeft = 5;
          game.player.evolutionManager.giveStartingImprovements();
          // SPOON: give all basic imps
          if (game.config.spoonEvolutionBasic)
            game.player.evolutionManager.giveAllBasic();
        }
      else if (currentChoice.id == 'timeline')
        game.timeline.difficulty = d;
      else if (currentChoice.id == 'save')
        {
          game.player.saveDifficulty = d;
          if (game.player.saveDifficulty == NOOB)
            game.player.vars.savesLeft = 999; // unused: Game.save bypasses the cap for NOOB
          else if (game.player.saveDifficulty == EASY)
            game.player.vars.savesLeft = 10;
          else if (game.player.saveDifficulty == NORMAL)
            game.player.vars.savesLeft = 3;
          else if (game.player.saveDifficulty == HARD)
            game.player.vars.savesLeft = 1;
          game.save(game.saveSlotPending);
        }
      else if (currentChoice.id == 'chat')
        game.player.chat.difficulty = d;

      game.system('Difficulty selected for ' + currentChoice.title + ': ' + d);

      game.ui.closeWindow();
    }

  public static var choices: Map<String, _Choice> = [
    'survival' => {
      id: 'survival',
      title: 'Survival',
      notes: [
        'Humans call the law slower. You will stop them from doing that when you jump on them. Minor early invasion chance bonus.',
        'Fast calling speed. Calls are not interrupted with attaching. Early invasion chance penalty.',
        'Same calling rules as normal. No free dog on exiting the sewers. Larger penalty for early invasion chance.',
      ]
    },

    'group' => {
      id: 'group',
      title: 'The Group',
      notes: [
        'Shows the exact numerical group and team information in the skills section. Limited shock and energy loss from habitat destruction.',
        'Shows group and team information described vaguely. Habitat destruction shock and energy loss is more severe.',
        'No group or team information available. Habitat destruction shock is harsh.',
      ]
    },

    'evolution' => {
      id: 'evolution',
      title: 'Evolution',
      notes: [
        'Gives 2 generic improvements. No limit for maximum improvement level. Host degradation is slower. No limit on total habitats amount.',
        'Gives 2 generic improvements. Maximum improvement level is 2, except for brain probe. Normal host degradation. Finite habitat amount per game.',
        'Gives 1 generic improvement. Maximum improvement level is 1, except for brain probe. Fast host degradation. Habitat limit decreased.',
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

    'save' => {
      id: 'save',
      title: 'Saving',
      notes: [
        'You can save your game anywhere, up to 10 times per one game.',
        'You can only save in region mode, 3 times per game.',
        'You can only save once per game while in region mode.',
        'Save anywhere, as many times as you like. Unlimited saves.',
      ]
    },

    'chat' => {
      id: 'chat',
      title: 'Conversation',
      notes: [
        'Starting consent is high. High bonus to skill rolls. Bonus to consent growth. No max energy loss on leaving host with max affinity.',
        'Medium starting consent. Medium bonus to skill rolls. Small bonus to consent growth. Tiny max energy loss.',
        'Low consent at start. Nominal bonus to skill rolls. No bonus to consent growth. Small max energy loss.',
      ]
    },
  ];
}

typedef _Choice = {
  var id: String;
  var title: String;
  var notes: Array<String>;
}
