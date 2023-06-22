// chat-related code
package game;

import const.*;
import ai.*;
import ai.AI;
import _AIEffectType;
import _ChatEmotion;

class Chat
{
  var game: Game;
  var player: Player;
  var target: AI;
  var turn: Int;
  var prevActions: Array<String>;

  public function new(p: Player, g: Game)
    {
      player = p;
      game = g;
    }

// start new chat
  public function start(ai: AI)
    {
      if (ai.chat.timeout > 0)
        {
          ai.log('does not want to converse with you at the moment.');
          return;
        }
      target = ai;
      if (target.chat.consent < 10)
        target.chat.consent = 10; // minimum
      target.chat.fatigue = 0;
      target.chat.emotion = 0;
      turn = 0;
      prevActions = [];
      game.ui.hud.state = HUD_CHAT;
    }

// finish chat setting timeout
  function finish(?timeout: Int = 10)
    {
      target.chat.timeout = timeout;
      target = null;
      game.ui.hud.state = HUD_DEFAULT;
    }

// get actions list
  public function updateActionList()
    {
      // generate a full list of possible actions
      var possibleActions = [
        'Analyze',
        'Assure',
        'Discuss',
        'Distort',
        'Empathize',
        'Encourage',
        'Flatter',
        'Lie',
        'Provoke',
        'Scare',
        'Shock',
        'Threaten',
      ];
      // remove actions from previous turn
      for (a in prevActions)
        possibleActions.remove(a);
      var list = [];
      var needActions = ChatConst.needActions[target.chat.needID];
      // always add one good action (too easy?)
//      list.push(needActions[Std.random(needActions.length)]);
//      possibleActions.remove(list[0]);
      // first turn: always add psychology
      if (turn == 0)
        {
          list.push('Analyze');
          possibleActions.remove('Analyze');
        }
      // add 2-3 remaining random actions
      while (list.length < 4)
        {
          var a = possibleActions[Std.random(possibleActions.length)];
          list.push(a);
          possibleActions.remove(a);
        }
      // sort list
      list.sort(function (a,b) {
        if (a > b)
          return 1;
        else if (a < b)
          return -1;
        else return 0;
      });
//      trace(list);
      // TODO: Question
      // TODO: min chance of using a skill is 5%

      // add to hud
      for (a in list)
        {
          // MATH: cost = 2 + [4-8] = 6-10
          var cost = 2 + target.psyche;
          switch (a)
            {
              case 'Analyze':
                cost = 5;
              case 'Shock', 'Threaten', 'Scare': 
                // MATH: cost = [6-10] / 2 = 3-5
                cost = Std.int(cost / 2);
            }
          game.ui.hud.addAction({
            id: 'chat.' + a.toLowerCase(),
            type: ACTION_CHAT,
            name: a,
            energy: cost,
          });
        }
      prevActions = list;

      // exit is always last
      game.ui.hud.addAction({
        id: 'chat.exit',
        type: ACTION_CHAT,
        name: 'Exit',
      });
    }

// analyze (use psychology)
  function analyze()
    {
      // form basic string replacing pronouns
      var msg = 'Analyzing ' + target.getNameCapped() + ' tells you that he ';
      if (target.chat.aspectID > 0)
        msg += 'is a ' + ChatConst.aspects[target.chat.aspectID] + ' individual, who ';
      msg += ChatConst.needStrings[target.chat.needID]
        [target.chat.needStringID];
      if (target.chat.emotion > 0)
        msg += ' He is visibly ' + ChatConst.emotions[target.chat.emotionID] + '.';
//      var needActions = ChatConst.needActions[target.chat.needID];
//      trace(needActions);
      log(msg);
    }

// manipulate: emotional state
  function manipulateEmotion(name: String)
    {
      var emotionID = target.chat.emotionID;
      // positive action
      if (Lambda.has([ 'Assure', 'Distort', 'Empathize', 'Lie'], name))
        {
          target.chat.emotion--;
          var msg = ChatConst.actionDesc[name] + ', you observe how ' + target.getNameCapped() + ' calms down ';
          if (target.chat.emotion == 0)
            msg += 'completely.';
          else msg += 'to a degree.';
          log(msg);
          return;
        }

      // negative action - increase emotion
      increaseEmotion(name.toLowerCase());
    }

// manipulate: normal state
  function manipulate(name: String)
    {
      // positive results
      var needActions = ChatConst.needActions[target.chat.needID];
      if (Lambda.has(needActions, name))
        {
          var adj = '';
          switch (target.chat.stun)
            {
              case 0:
                adj = 'noticeable';
              case 1:
                adj = 'significant';
              case 2:
                adj = 'tremendous';
              case 3:
                adj = 'staggering';
            }
          // psyche: 4-8
          // stun 3: 4 * (10 - [4-8] + [0-3]) = 4 * [2-7] = 8-28
          var val = (target.chat.stun + 1) * (10 - target.psyche + Std.random(4));
          target.chat.consent += val;
          log(ChatConst.actionDesc[name] + ', you observe a ' + adj + ' growth in the consent of ' + target.getNameCapped() + '. ' +
            (game.config.extendedInfo ? Const.smallgray('[+' + val + ' consent]') : ''));
          return;
        } 

      // negative results
      var adj = '';
      switch (target.chat.stun)
        {
          case 0:
            adj = 'unimpressed';
          case 1:
            adj = 'annoyed';
          case 2:
            adj = 'irritated';
          case 3:
            adj = 'livid';
        }
      var val = (target.chat.stun + 1) * (5 + Std.random(5));
      target.chat.consent -= val;
      log(target.getNameCapped() + ' is ' + adj + ' with your attempts to ' + name.toLowerCase() + '. ' +
        (game.config.extendedInfo ? Const.smallgray('[-' + val + ' consent]') : ''));
    }

// post-manipulation: fatigue, consent, etc
  function manipulatePost()
    {
      if (target == null)
        return;
      target.chat.stun = 0;
      // increase fatigue
      target.chat.fatigue++;
      if (target.chat.fatigue >= 10)
        {
          log('Feeling tired, ' + target.getNameCapped() + ' ends the conversation.');
          finish();
        }
    }

// post for all actions
  function actionPost()
    {
      // chat is over
      if (target == null)
        return;
      // check for minimal consent
      if (target.chat.consent <= 0)
        {
          log('Frustrated by the conversation, ' + target.getNameCapped() + ' ends it.');
          finish();
        }
      // maximum consent
      else if (target.chat.consent >= 100)
        {
          var msg = 'Inspired by the conversation, ' + target.getNameCapped() + ' gives you his full consent.';
          if (target == player.host)
            msg += ' You can now speak with other hosts through him.';
          log(msg);
          finish();
        }
    }

  function debugPrint()
    {
      if (target == null)
        return;
#if mydebug
      game.log(Const.smallgray(
        '[ consent:' + target.chat.consent +
        ', fatigue: ' + target.chat.fatigue +
        ', emotion: ' + target.chat.emotion +
        ', stun: ' + target.chat.stun + ' ]'));
#end
    }

// provoke this host
  function provoke()
    {
      // TODO: skill roll
      target.chat.fatigue -= 2 + Std.random(2);
      if (target.chat.fatigue < 0)
        target.chat.fatigue = 0;
      target.chat.consent -= 5 + Std.random(2);
      target.chat.stun = 0;
      log('You provoke ' + target.getNameCapped() + ' invigorating their desire for more conversation.');
    }

// check for aspect-related logic
// returns true if it worked
  function shockAspect(id: String): Bool
    {
      // already emotional
      if (target.chat.emotionID != EMOTION_NONE)
        return false;

      // check for aspect-related logic
      var aspect = ChatConst.aspects[target.chat.aspectID];
      var emotionID = EMOTION_NONE;
      switch (aspect)
        {
          case 'normal':
          case 'jumpy', 'nervous': 
            if (id == 'scare' || id == 'threaten')
              emotionID = EMOTION_STARTLED;
          case 'submissive', 'non-confrontational', 'timid':
            if (id == 'shock')
              emotionID = EMOTION_DISTRESSED;
        }
      // nothing happened
      if (emotionID == EMOTION_NONE)
        return false;
      target.chat.emotionID = emotionID;

      // increase emotion up
      increaseEmotion(id);
      return true;
    }

// increase emotion due to any action
  function increaseEmotion(id: String)
    {
      // target is now emotional
      target.chat.emotion++;
      var adj = '';
      switch (target.chat.emotion)
        {
          case 1:
            adj = 'noticeably';
          case 2:
            adj = 'even more';
          case 3:
            adj = 'completely';
        }
//      log('When you try to ' + id + ' ' + target.getNameCapped() + ', he becomes ' + adj + ' ' + ChatConst.emotions[target.chat.emotionID] + '.');
      log(target.getNameCapped() + ' becomes ' + adj + ' ' + ChatConst.emotions[target.chat.emotionID] + ' by your attempts to communicate.');
      if (target.chat.emotion >= 3)
        maxEmotion();
      return true;
    }

// max emotion logic - runs when target reaches it
  function maxEmotion()
    {
      var emotion = ChatConst.emotions[target.chat.emotionID];
      switch (emotion)
        {
          // -> panic
          case 'startled':
            if (player.host == target)
              {
                game.playerArea.leaveHostAction('panic');
                game.playerArea.onDamage(1 + Std.random(2));
                target.emitRandomSound('' + REASON_DAMAGE);
                game.playerArea.actionPost(); // skip turn
              }
            else target.setState(AI_STATE_ALERT, null, ' is panicking.');
            target.onEffect({
              type: EFFECT_PANIC,
              points: 5,
              isTimer: true
            });
          // -> tears
          case 'distressed':
            target.emitRandomSound('' + EFFECT_CRYING);
            target.onEffect({
              type: EFFECT_CRYING,
              points: 15,
              isTimer: true
            });
        }
      // larger timeout due to emotions
      finish(30);
    }

// threaten, scare, shock - synonyms
  function shock(id: String)
    {
      // aspect-related logic
      if (shockAspect(id))
        return;
      // base logic
      if (target.chat.stun < 3)
        {
          target.chat.stun++;
          var msg = target.getNameCapped();
          switch (target.chat.stun)
            {
              case 1:
               msg += ' is unsettled by your words.';
              case 2:
               msg += ' is visibly shaken because of your words.';
              case 3:
               msg += '  is deeply disturbed by the things you said.';
            }
          log(msg);
        }
      else
        {
          log('Your words fall on deaf ears, ' + target.getNameCapped() + ' is too stunned already.');
        }
    }

// run action
  public function action(action: _PlayerAction)
    {
      var id = action.id.substr(5);
      switch (id)
        {
          case 'analyze':
            analyze();
          case 'provoke': 
            provoke();
          case 'threaten': 
            shock(id);
          case 'scare': 
            shock(id);
          case 'shock': 
            shock(id);
          case 'question': 
            Const.todo('not implemented');
          case 'exit':
            log('You interrupt the conversation.');
            finish();
          // one of the consent actions
          default:
            var name = Const.capitalize(id);
            if (target.chat.emotion > 0)
              manipulateEmotion(name);
            else manipulate(name);
            manipulatePost();
        }
      actionPost(); // check for fatigue
      debugPrint();
      turn++;
      // convo could end
      if (target != null)
        {
          target.chat.turns++;
        }
      player.actionEnergy(action); // spend energy
      game.playerArea.actionPost(); // end turn, etc
    }

// log line + stats
  function log(s: String)
    {
      if (target != null && !target.isMale)
        {
          s = StringTools.replace(s, ' he ', ' she ');
          s = StringTools.replace(s, ' him', ' her');
        }
#if mydebug
/*
      if (target.chat != null)
        game.log(s + ' ' +
          Const.smallgray(
            '[ consent:' + target.chat.consent +
            ', fatigue: ' + target.chat.fatigue +
            ', stun: ' + target.chat.stun));
      else */game.log(s);
#else
      game.log(s);
#end
    }
}
