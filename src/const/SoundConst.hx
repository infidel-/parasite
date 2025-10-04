// AI sounds

package const;

import ai.AI;
import _AIState;
import _AIEffectType;

class SoundConst
{
  public static function getSounds(field: String): Map<String, Array<AISound>>
    {
      return Reflect.field(SoundConst, field);
    }

  // dog sounds
  public static var dog: Map<String, Array<AISound>> = [
    '' + REASON_DAMAGE => [
      {
        text: '*WHIMPER*',
        file: 'dog-whimper',
        radius: 2,
        alertness: 5,
        params: null
      },
      {
        text: '*WHINE*',
        file: 'dog-whine',
        radius: 2,
        alertness: 5,
        params: null
      },
      {
        text: '*YELP*',
        file: 'dog-yelp',
        radius: 3,
        alertness: 5,
        params: null
      },
    ],
    '' + AI_STATE_IDLE => [
      {
        text: '*GROWL*',
        file: 'dog-growl',
        radius: 2,
        alertness: 5,
        params: { minAlertness: 25 }
      },
    ],
    '' + AI_STATE_ALERT => [
      {
        text: '*BARK*',
        file: 'dog-bark',
        radius: 5,
        alertness: 10,
        params: null
      },
    ],
    '' + AI_STATE_HOST => [
      {
        text: '*whimper*',
        file: 'dog-whimper',
        radius: 2,
        alertness: 3,
        params: null
      },
      {
        text: '*whine*',
        file: 'dog-whine',
        radius: 2,
        alertness: 3,
        params: null
      },
      {
        text: '*growl*',
        file: 'dog-growl',
        radius: 2,
        alertness: 3,
        params: null
      },
      {
        text: '*GROWL*',
        file: 'dog-growl',
        radius: 2,
        alertness: 3,
        params: null
      },
    ],
    '' + AI_STATE_DEAD => [
      {
        text: '*whine*',
        file: 'dog-die',
        radius: 2,
        alertness: 3,
        params: null
      },
    ]
  ];

  // common human sounds
  static var humanDamage: Array<AISound> = [
    {
      text: 'Ouch!',
      file: 'male-ouch',
      radius: 2,
      alertness: 5,
      params: null
    },
    {
      text: '*GROAN*',
      file: 'male-grunt',
      radius: 2,
      alertness: 5,
      params: null
    },
  ];
  static var humanIdle: Array<AISound> = [
    {
      text: 'Huh?',
      file: 'male-huh',
      radius: 0,
      alertness: 0,
      params: { minAlertness: 25 }
    },
    {
      text: 'Whu?',
      file: 'male-whu',
      radius: 0,
      alertness: 0,
      params: { minAlertness: 25 }
    },
    {
      text: 'What the?',
      file: 'male-what',
      radius: 0,
      alertness: 0,
      params: { minAlertness: 50 }
    },
    {
      text: '*GASP*',
      file: 'male-gasp',
      radius: 0,
      alertness: 0,
      params: { minAlertness: 75 }
    },
  ];
  static var humanHost: Array<AISound> = [
    {
      file: 'male-choke',
      text: '*choke*',
      radius: 2,
      alertness: 3,
      params: null
    },
    {
      file: 'male-moan',
      text: '*moan*',
      radius: 2,
      alertness: 5,
      params: null
    },
    {
      file: 'male-moan-loud',
      text: '*MOAN*',
      radius: 3,
      alertness: 5,
      params: null
    },
  ];
  static var genericAlert: Array<AISound> = [
    {
      file: 'human-stop',
      text: 'STOP!',
      radius: 7,
      alertness: 10,
      params: null
    },
  ];
  static var humanDie: Array<AISound> = [
    {
      text: '*death*',
      file: 'male-die',
      radius: 6,
      alertness: 10,
      params: null
    },
  ];
  static var humanCrying: Array<AISound> = [
    {
      text: '*sob*',
      file: 'male-crying',
      radius: 2,
      alertness: 5,
      params: null
    },
    {
      text: '*weep*',
      file: 'male-crying',
      radius: 2,
      alertness: 5,
      params: null
    },
    {
      text: '*sniff*',
      file: 'male-crying',
      radius: 2,
      alertness: 5,
      params: null
    },
    {
      text: '*bawl*',
      file: 'male-crying-loud',
      radius: 3,
      alertness: 5,
      params: null
    },
  ];
  static var humanChatFail: Array<AISound> = [
    {
      text: '*urk*',
      file: 'male-chat-fail',
      radius: 3,
      alertness: 5,
      params: null
    },
  ];

  // civilian sounds
  public static var civilian: Map<String, Array<AISound>> = [
    '' + REASON_DAMAGE => humanDamage,
    '' + AI_STATE_IDLE => humanIdle,
    '' + AI_STATE_ALERT => [
      {
        file: 'male-scream',
        text: '*SCREAM*',
        radius: 7,
        alertness: 15,
        params: null
      },
    ],
    '' + AI_STATE_HOST => humanHost,
    '' + AI_STATE_DEAD => humanDie,
    '' + EFFECT_CRYING => humanCrying,
    'CHAT_FAIL' => humanChatFail,
  ];

  // cultist sounds
  public static var cultist: Map<String, Array<AISound>> = [
    '' + REASON_DAMAGE => [
      {
        text: 'More!',
        file: 'male-ouch',
        radius: 2,
        alertness: 5,
        params: null
      },
      {
        text: 'YES!',
        file: 'male-grunt',
        radius: 2,
        alertness: 5,
        params: null
      },
    ],
    '' + AI_STATE_IDLE => humanIdle,
    '' + AI_STATE_ALERT => [
      {
        file: 'male-scream',
        text: 'DIE!',
        radius: 7,
        alertness: 15,
        params: null
      },
    ],
    '' + AI_STATE_HOST => humanHost,
    '' + AI_STATE_DEAD => humanDie,
    '' + EFFECT_CRYING => humanCrying,
    'CHAT_FAIL' => humanChatFail,
  ];

  // police officer sounds
  public static var police: Map<String, Array<AISound>> = [
    '' + REASON_DAMAGE => humanDamage,
    '' + AI_STATE_IDLE => humanIdle,
    '' + AI_STATE_ALERT => genericAlert,
    '' + AI_STATE_HOST => humanHost,
    '' + AI_STATE_DEAD => humanDie,
    '' + EFFECT_CRYING => humanCrying,
    'CHAT_FAIL' => humanChatFail,
  ];

  // soldier sounds
  public static var soldier: Map<String, Array<AISound>> = police;

  // agent sounds
  public static var agent: Map<String, Array<AISound>> = police;

  // security sounds
  public static var security: Map<String, Array<AISound>> = police;

  // team member/blackops sounds
  public static var team: Map<String, Array<AISound>> = [
    '' + REASON_DAMAGE => [
      {
        text: '*GRUNT*',
        file: 'male-grunt',
        radius: 2,
        alertness: 5,
        params: null
      },
      {
        text: '*GROAN*',
        file: 'male-grunt',
        radius: 2,
        alertness: 5,
        params: null
      },
    ],
    '' + AI_STATE_IDLE => [
      {
        text: 'Huh?',
        file: 'male-huh',
        radius: 0,
        alertness: 0,
        params: { minAlertness: 25 }
      },
      {
        text: 'Whu?',
        file: 'male-whu',
        radius: 0,
        alertness: 0,
        params: { minAlertness: 25 }
      },
      {
        text: 'What the?',
        file: 'male-what',
        radius: 0,
        alertness: 0,
        params: { minAlertness: 50 }
      },
      {
        text: 'BOGEY!',
        file: 'human-alert',
        radius: 0,
        alertness: 0,
        params: { minAlertness: 75 }
      },
    ],
    '' + AI_STATE_ALERT => [
      {
        file: 'human-stop',
        text: 'TANGO!',
        radius: 7,
        alertness: 10,
        params: null
      },
    ],
    '' + AI_STATE_HOST => humanHost,
    '' + AI_STATE_DEAD => humanDie,
    '' + EFFECT_CRYING => humanCrying,
    'CHAT_FAIL' => humanChatFail,
  ];

  // thug sounds
  public static var thug: Map<String, Array<AISound>> = [
    '' + REASON_DAMAGE => [
      {
        text: 'Fuck!',
        file: 'male-ouch',
        radius: 2,
        alertness: 5,
        params: null
      },
      {
        text: 'Shit!',
        file: 'male-grunt',
        radius: 2,
        alertness: 5,
        params: null
      },
    ],
    '' + AI_STATE_IDLE => humanIdle,
    '' + AI_STATE_ALERT => [
      {
        file: 'male-scream',
        text: 'Die!',
        radius: 7,
        alertness: 15,
        params: null
      },
      {
        file: 'male-scream',
        text: 'Bitch!',
        radius: 7,
        alertness: 15,
        params: null
      },
    ],
    '' + AI_STATE_HOST => humanHost,
    '' + AI_STATE_DEAD => humanDie,
    '' + EFFECT_CRYING => humanCrying,
    'CHAT_FAIL' => humanChatFail,
  ];
}
