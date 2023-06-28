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
  var lies: Int;
  var prevActions: Array<String>;
  var impulsiveFinish: Bool;
  var liesFlag: Bool;

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
      lies = 0;
      liesFlag = false;
      impulsiveFinish = false;
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
      var msg = 'Analyzing ' + target.theName() + ' tells you that he ';
      if (target.chat.aspectID > 0)
        {
          var aspect = ChatConst.aspects[target.chat.aspectID];
          var char0 = aspect.charAt(0);
          var a = 'a';
          if ('aeiuo'.indexOf(char0) >= 0)
            a = 'an';
          msg += 'is ' + a + ' ' + aspect + ' individual, who ';
        }
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
      var isPositive =
        (Lambda.has([ 'Assure', 'Empathize', 'Lie'], name));
      // negative action - increase emotion
      if (!isPositive)
        {
          increaseEmotion();
          return;
        }

      // positive action
      target.chat.emotion--;
      var msg = ChatConst.actionDesc[name] + ' ' + target.theName() + ', you observe how he calms down ';
      if (target.chat.emotion == 0)
        msg += 'completely.';
      else msg += 'to a degree.';
      log(msg);
    }

// common code for explosive aspect (manipulate, shock)
  function explosiveAspect(): Bool
    {
      if (target.chat.emotion >= 2 ||
          Std.random(100) > 20)
        return false;
      target.chat.stun = 0;
      target.chat.emotion = 2;
      target.chat.emotionID = EMOTION_ANGRY;
      target.log('is suddenly enraged by your words.');
      return true;
    }

// common code for temperamental aspect (manipulate, shock)
  function temperamentalAspect(): Bool
    {
      // chance of going into random emotion, often angry
      if (target.chat.emotion > 0 ||
          Std.random(100) > 15)
        return false;
      var emotions = [
        'startled',
        'angry', // higher chance
        'angry',
        'angry',
        'distressed',
      ];
      var emotion = emotions[Std.random(emotions.length)];
      var emotionID = 0;
      for (i in 0...ChatConst.emotions.length)
        if (ChatConst.emotions[i] == emotion)
          {
            emotionID = i;
            break;
          }

      // emotion chosen
      target.chat.emotion++;
      target.chat.emotionID = emotionID;
      target.chat.stun = 0;
      log(target.TheName() + "'s temperament gets the better of him. He is now noticeably " + emotion + '.');
      return true;
    }

// check for aspect-related logic
// returns true if it worked
  function manipulateAspect(id: String, name: String, isPositive: Bool): Bool
    {
      var aspect = ChatConst.aspects[target.chat.aspectID];
      switch (aspect)
        {
          case 'explosive', 'prone to anger':
            return explosiveAspect();
          case 'temperamental':
            return temperamentalAspect();
          case 'lacks self-control', 'impatient':
            if (isPositive && Std.random(100) < 30)
              {
                if (target.chat.stun == 0)
                  target.chat.stun = 1;
                manipulateNegative(id);
                return true;
              }
          case 'impulsive':
            if (isPositive && Std.random(100) < 20)
              {
                target.chat.consent = 100;
                impulsiveFinish = true;
                return true;
              }
        }
      return false;
    }

// manipulate: normal state
  function manipulate(name: String)
    {
      // aspect-related logic
      var needActions = ChatConst.needActions[target.chat.needID];
      var isPositive = (Lambda.has(needActions, name));
      if (manipulateAspect(name.toLowerCase(), name, isPositive))
        return;
      // more aspect-related logic
      var aspect = ChatConst.aspects[target.chat.aspectID];
      switch (aspect)
        {
          case 'narcissistic':
            if (name == 'Flatter' &&
                Std.random(100) < 85)
              {
                isPositive = true;
                target.chat.stun = 1 + Std.random(3);
              }
            else if (name == 'Empathize' &&
                isPositive &&
                Std.random(100) < 85)
              {
                isPositive = false;
                target.chat.stun = 1 + Std.random(3);
              }
        }
      // lying too much exposes them
      if (isPositive && name == 'Lie' &&
          lies > 2 && Std.random(100) < 5 * lies)
        {
          liesFlag = true;
          target.chat.stun = 1 + Std.random(3);
          isPositive = false;
        }
      // positive results
      if (isPositive)
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
          log(ChatConst.actionDesc[name] + ' ' + target.theName() + ', you observe a ' + adj + ' growth in his consent. ' +
            (game.config.extendedInfo ? Const.smallgray('[+' + val + ' consent]') : ''));
          // count all positive lies
          if (name == 'Lie')
            lies++;
          return;
        }

      // negative results
      manipulateNegative(name.toLowerCase());
    }

// negative results for manipulation
  function manipulateNegative(name: String)
    {
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
      var msg = target.TheName() + ' is ' + adj + ' with your attempts to ' + name.toLowerCase() + '. ';
      if (liesFlag)
        msg = target.TheName() + ' sees through your lies and is ' + adj + '. ';
      msg += (game.config.extendedInfo ? Const.smallgray('[-' + val + ' consent]') : '');
      log(msg);
      liesFlag = false;
    }

// post-manipulation: fatigue, consent, etc
  function manipulatePost()
    {
      if (target == null)
        return;
      target.chat.stun = 0;
      // increase fatigue
      target.chat.fatigue++;
      var aspect = ChatConst.aspects[target.chat.aspectID];
      switch (aspect)
        {
          case 'exhausted':
            target.chat.fatigue += Std.random(3);
        }
      if (target.chat.fatigue >= 10)
        {
          log('Feeling tired, ' + target.theName() + ' ends the conversation.');
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
          log('Frustrated by the conversation, ' + target.theName() + ' ends it.');
          finish();
        }
      // maximum consent
      else if (target.chat.consent >= 100)
        {
          var msg = '';
          if (impulsiveFinish)
            msg += 'Without thinking, '
          else if (target.chat.emotionID == EMOTION_DESENSITIZED)
            msg += 'Shrugging, ';
          else msg += 'Inspired by the conversation, ';
          msg += target.theName() + ' gives you his full consent.';
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
      // already emotional
      if (target.chat.emotionID != EMOTION_NONE)
        {
          // increase emotion up
          increaseEmotion();
          return;
        }

      // aspect-related logic
      var aspect = ChatConst.aspects[target.chat.aspectID];
      switch (aspect)
        {
          case 'exhausted':
            if (Std.random(100) < 65)
              {
                log('You fail to provoke ' + target.theName() + ' due to his enervation.');
                return;
              }
        }

      // TODO: skill roll
      var fatigue = 2 + Std.random(3);
      target.chat.fatigue -= fatigue;
      if (target.chat.fatigue < 0)
        target.chat.fatigue = 0;
      var consent = 5 + Std.random(2);
      target.chat.consent -= consent;
      target.chat.stun = 0;
      log('You provoke ' + target.theName() + ' invigorating his desire for more conversation. ' +
        (game.config.extendedInfo ? Const.smallgray('[-' + consent + ' consent, -' + fatigue + ' fatigue]') : ''));
    }

// increase emotion due to any action
  function increaseEmotion()
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
          default:
            adj = 'completely';
        }
      log(target.TheName() + ' becomes ' + adj + ' ' + ChatConst.emotions[target.chat.emotionID] + ' by your attempts to communicate.');
      if (target.chat.emotion >= 3)
        maxEmotion();
      return true;
    }

// max emotion logic - runs when target reaches it
  function maxEmotion()
    {
      switch (target.chat.emotionID)
        {
          // bug
          case EMOTION_NONE:
          // -> attack
          case EMOTION_ANGRY:
            if (player.host == target)
              {
                game.playerArea.leaveHostAction('berserk');
                game.playerArea.onDamage(2 + Std.random(4));
                target.emitRandomSound('' + REASON_DAMAGE);
                game.playerArea.moveToRandom(false);
              }
            else target.setState(AI_STATE_ALERT, null, ' is absolutely furious.');
            target.onEffect({
              type: EFFECT_BERSERK,
              points: 10,
              isTimer: true
            });
          // -> panic
          case EMOTION_STARTLED:
            if (player.host == target)
              {
                game.playerArea.leaveHostAction('panic');
                game.playerArea.onDamage(1 + Std.random(2));
                target.emitRandomSound('' + REASON_DAMAGE);
                game.playerArea.moveToRandom(false);
              }
            else target.setState(AI_STATE_ALERT, null, ' is panicking.');
            target.onEffect({
              type: EFFECT_PANIC,
              points: 10,
              isTimer: true
            });
          // -> tears
          case EMOTION_DISTRESSED:
            target.emitRandomSound('' + EFFECT_CRYING);
            target.log('is crying.');
            target.onEffect({
              type: EFFECT_CRYING,
              points: 15,
              isTimer: true
            });
          case EMOTION_DESENSITIZED:
            target.chat.consent = 100;
            return;
        }
      // larger timeout due to emotions
      finish(30);
    }

// check for aspect-related logic
// returns true if it worked
  function shockAspect(id: String): Bool
    {
      // already emotional
      if (target.chat.emotionID != EMOTION_NONE)
        {
          // increase emotion up
          increaseEmotion();
          return true;
        }

      // check for aspect-related logic
      var aspect = ChatConst.aspects[target.chat.aspectID];
      var emotionID = EMOTION_NONE;
      switch (aspect)
        {
          case 'normal':
            if (Std.random(100) < 5)
              emotionID = 1 + Std.random(4);
          case 'jumpy', 'nervous': 
            if (id == 'scare' || id == 'threaten')
              if (Std.random(100) < 75)
                emotionID = EMOTION_STARTLED;
          case 'submissive', 'non-confrontational', 'timid':
            if (id == 'shock' && Std.random(100) < 75)
              emotionID = EMOTION_DISTRESSED;
          case 'resilient':
            if (Std.random(100) < 30)
              {
                target.log('seems to be unperturbed by your words.');
                return true;
              }
            if (Std.random(100) < 10)
              emotionID = EMOTION_ANGRY;
          case 'hot-headed', 'irritable':
            if (Std.random(100) < 85)
              emotionID = EMOTION_ANGRY;
          case 'explosive', 'prone to anger':
            return explosiveAspect();
          case 'temperamental':
            return temperamentalAspect();
          case 'detached', 'indifferent':
            if (Std.random(100) < 15)
              emotionID = EMOTION_DESENSITIZED;
          case 'adaptive':
            if (Std.random(100) < 30)
              {
                var msg = 'Ignoring your attempts to ' + id + ' him, ' + target.theName();
                if (target.chat.stun == 0)
                  msg += ' stays calm.';
                else msg += ' calms down.';
                log(msg);
                target.chat.stun = 0;
                return true;
              }
          case 'exhausted':
            if (Std.random(100) < 65)
              {
                log('You fail to ' + id + ' ' + target.theName() + ' due to his enervation.');
                return true;
              }
        }
      // nothing happened
      if (emotionID == EMOTION_NONE)
        return false;
      target.chat.stun = 0;
      target.chat.emotionID = emotionID;

      // increase emotion up
      increaseEmotion();
      return true;
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
          var consent = 1 + Std.random(5);
          target.chat.consent -= consent;
          var msg = target.TheName();
          if (Std.random(100) < 15)
            {
              var speech = ChatConst.shockSpeechHost;
              if (target != player.host)
                speech = ChatConst.shockSpeech;
              game.narrative(
                speech[Std.random(speech.length)],
                COLOR_MESSAGE);
            }
          switch (target.chat.stun)
            {
              case 1:
               msg += ' is unsettled by your words.';
              case 2:
               msg += ' is visibly shaken because of your words.';
              case 3:
               msg += '  is deeply disturbed by the things you said.';
            }
          log(msg + ' ' + (game.config.extendedInfo ?
            Const.smallgray('[-' + consent + ' consent, +1 shock]') : ''));
        }
      else
        {
          log('Your words fall on deaf ears, ' + target.theName() + ' is too stunned already.');
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
          case 'threaten', 'scare', 'shock': 
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
      actionPost(); // check for fatigue/consent
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
          s = StringTools.replace(s, 'He ', 'She ');
          s = StringTools.replace(s, ' he ', ' she ');
          s = StringTools.replace(s, ' him', ' her');
          s = StringTools.replace(s, ' his', ' her');
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
