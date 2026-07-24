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
        kind: 'bark',
        file: 'dog-whimper',
        radius: 2,
        alertness: 5,
        params: null
      },
      {
        text: '*WHINE*',
        kind: 'bark',
        file: 'dog-whine',
        radius: 2,
        alertness: 5,
        params: null
      },
      {
        text: '*YELP*',
        kind: 'bark',
        file: 'dog-yelp',
        radius: 3,
        alertness: 5,
        params: null
      },
    ],
    '' + AI_STATE_IDLE => [
      {
        text: '*GROWL*',
        kind: 'bark',
        file: 'dog-growl',
        radius: 2,
        alertness: 5,
        params: { minAlertness: 25 }
      },
    ],
    '' + AI_STATE_ALERT => [
      {
        text: '*BARK*',
        kind: 'bark',
        file: 'dog-bark',
        radius: 5,
        alertness: 10,
        params: null
      },
    ],
    '' + AI_STATE_HOST => [
      {
        text: '*whimper*',
        kind: 'bark',
        file: 'dog-whimper',
        radius: 2,
        alertness: 3,
        params: null
      },
      {
        text: '*whine*',
        kind: 'bark',
        file: 'dog-whine',
        radius: 2,
        alertness: 3,
        params: null
      },
      {
        text: '*growl*',
        kind: 'bark',
        file: 'dog-growl',
        radius: 2,
        alertness: 3,
        params: null
      },
      {
        text: '*GROWL*',
        kind: 'bark',
        file: 'dog-growl',
        radius: 2,
        alertness: 3,
        params: null
      },
    ],
    '' + AI_STATE_DEAD => [
      {
        text: '*whine*',
        kind: 'bark',
        file: 'dog-die',
        radius: 2,
        alertness: 3,
        params: null
      },
    ]
  ];

  // firmus custos sounds
  public static var firmus: Map<String, Array<AISound>> = [
    '' + REASON_DAMAGE => [
      {
        text: '*HRMM*',
        kind: 'bark',
        file: 'firmus-hrmm',
        radius: 2,
        alertness: 5,
        params: null
      },
      {
        text: '*HURR*',
        kind: 'bark',
        file: 'firmus-hurr',
        radius: 2,
        alertness: 5,
        params: null
      },
      {
        text: '*HRRGH*',
        kind: 'bark',
        file: 'firmus-hrrgh',
        radius: 3,
        alertness: 5,
        params: null
      },
    ],
    '' + AI_STATE_IDLE => [
      {
        text: '*HRMM*',
        kind: 'bark',
        file: 'firmus-hrmm',
        radius: 2,
        alertness: 5,
        params: { minAlertness: 25 }
      },
    ],
    '' + AI_STATE_ALERT => [
      {
        text: '*HURR*',
        kind: 'bark',
        file: 'firmus-hurr',
        radius: 5,
        alertness: 10,
        params: null
      },
    ],
    '' + AI_STATE_HOST => [
      {
        text: '*hrmm*',
        kind: 'bark',
        file: 'firmus-hrmm',
        radius: 2,
        alertness: 3,
        params: null
      },
      {
        text: '*hurr*',
        kind: 'bark',
        file: 'firmus-hurr',
        radius: 2,
        alertness: 3,
        params: null
      },
    ],
    '' + AI_STATE_DEAD => [
      {
        text: '*hrrgh*',
        kind: 'bark',
        file: 'firmus-die',
        radius: 2,
        alertness: 3,
        params: null
      },
    ]
  ];

  // mordax custos sounds
  public static var mordax: Map<String, Array<AISound>> = [
    '' + REASON_DAMAGE => [
      {
        text: '*CHUMP*',
        kind: 'bark',
        file: 'mordax-chump',
        radius: 2,
        alertness: 5,
        params: null
      },
      {
        text: '*CHORR*',
        kind: 'bark',
        file: 'mordax-chorr',
        radius: 2,
        alertness: 5,
        params: null
      },
      {
        text: '*CHOMP*',
        kind: 'bark',
        file: 'mordax-chomp',
        radius: 3,
        alertness: 5,
        params: null
      },
    ],
    '' + AI_STATE_IDLE => [
      {
        text: '*CHORR*',
        kind: 'bark',
        file: 'mordax-chorr',
        radius: 2,
        alertness: 5,
        params: { minAlertness: 25 }
      },
    ],
    '' + AI_STATE_ALERT => [
      {
        text: '*CHOMP*',
        kind: 'bark',
        file: 'mordax-chomp',
        radius: 5,
        alertness: 10,
        params: null
      },
    ],
    '' + AI_STATE_HOST => [
      {
        text: '*chump*',
        kind: 'bark',
        file: 'mordax-chump',
        radius: 2,
        alertness: 3,
        params: null
      },
      {
        text: '*chorr*',
        kind: 'bark',
        file: 'mordax-chorr',
        radius: 2,
        alertness: 3,
        params: null
      },
    ],
    '' + AI_STATE_DEAD => [
      {
        text: '*chorr*',
        kind: 'bark',
        file: 'mordax-die',
        radius: 2,
        alertness: 3,
        params: null
      },
    ]
  ];

  // choir of discord sounds
  public static var choir: Map<String, Array<AISound>> = [
    '' + REASON_DAMAGE => [
      {
        text: '***',
        kind: 'bark',
        radius: 4,
        alertness: 10,
        params: null
      },
    ],
    '' + AI_STATE_IDLE => [
      {
        text: '...',
        kind: 'say',
        radius: 0,
        alertness: 0,
        params: null
      },
    ],
    '' + AI_STATE_ALERT => [
      {
        text: '***',
        kind: 'bark',
        radius: 7,
        alertness: 15,
        params: null
      },
    ],
    '' + AI_STATE_HOST => [
      {
        text: '...',
        kind: 'say',
        radius: 2,
        alertness: 3,
        params: null
      },
    ],
    '' + AI_STATE_DEAD => [
      {
        text: '***',
        kind: 'bark',
        radius: 4,
        alertness: 10,
        params: null
      },
    ]
  ];

  // common human sounds
  static var humanDamage: Array<AISound> = [
    {
      text: 'Ouch!',
      kind: 'shout',
      file: 'male-ouch',
      radius: 2,
      alertness: 5,
      params: null
    },
    {
      text: '*GROAN*',
      kind: 'bark',
      file: 'male-grunt',
      radius: 2,
      alertness: 5,
      params: null
    },
  ];
  static var humanIdle: Array<AISound> = [
    {
      text: 'Huh?',
      kind: 'say',
      file: 'male-huh',
      radius: 0,
      alertness: 0,
      params: { minAlertness: 25 }
    },
    {
      text: 'Whu?',
      kind: 'say',
      file: 'male-whu',
      radius: 0,
      alertness: 0,
      params: { minAlertness: 25 }
    },
    {
      text: 'What the?',
      kind: 'say',
      file: 'male-what',
      radius: 0,
      alertness: 0,
      params: { minAlertness: 50 }
    },
    {
      text: '*GASP*',
      kind: 'bark',
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
      kind: 'bark',
      radius: 2,
      alertness: 3,
      params: null
    },
    {
      file: 'male-moan',
      text: '*moan*',
      kind: 'bark',
      radius: 2,
      alertness: 5,
      params: null
    },
    {
      file: 'male-moan-loud',
      text: '*MOAN*',
      kind: 'bark',
      radius: 3,
      alertness: 5,
      params: null
    },
  ];
  static var genericAlert: Array<AISound> = [
    {
      file: 'human-stop',
      text: 'STOP!',
      kind: 'shout',
      radius: 7,
      alertness: 10,
      params: null
    },
  ];
  static var humanDie: Array<AISound> = [
    {
      text: '*death*',
      kind: 'bark',
      file: 'male-die',
      radius: 6,
      alertness: 10,
      params: null
    },
  ];
  static var humanCrying: Array<AISound> = [
    {
      text: '*sob*',
      kind: 'bark',
      file: 'male-crying',
      radius: 2,
      alertness: 5,
      params: null
    },
    {
      text: '*weep*',
      kind: 'bark',
      file: 'male-crying',
      radius: 2,
      alertness: 5,
      params: null
    },
    {
      text: '*sniff*',
      kind: 'bark',
      file: 'male-crying',
      radius: 2,
      alertness: 5,
      params: null
    },
    {
      text: '*bawl*',
      kind: 'bark',
      file: 'male-crying-loud',
      radius: 3,
      alertness: 5,
      params: null
    },
  ];
  static var humanChatFail: Array<AISound> = [
    {
      text: '*urk*',
      kind: 'bark',
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
        kind: 'bark',
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
        kind: 'shout',
        file: 'male-ouch',
        radius: 2,
        alertness: 5,
        params: null
      },
      {
        text: 'YES!',
        kind: 'shout',
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
        kind: 'shout',
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
        kind: 'bark',
        file: 'male-grunt',
        radius: 2,
        alertness: 5,
        params: null
      },
      {
        text: '*GROAN*',
        kind: 'bark',
        file: 'male-grunt',
        radius: 2,
        alertness: 5,
        params: null
      },
    ],
    '' + AI_STATE_IDLE => [
      {
        text: 'Huh?',
        kind: 'say',
        file: 'male-huh',
        radius: 0,
        alertness: 0,
        params: { minAlertness: 25 }
      },
      {
        text: 'Whu?',
        kind: 'say',
        file: 'male-whu',
        radius: 0,
        alertness: 0,
        params: { minAlertness: 25 }
      },
      {
        text: 'What the?',
        kind: 'say',
        file: 'male-what',
        radius: 0,
        alertness: 0,
        params: { minAlertness: 50 }
      },
      {
        text: 'BOGEY!',
        kind: 'shout',
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
        kind: 'shout',
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
        kind: 'shout',
        file: 'male-ouch',
        radius: 2,
        alertness: 5,
        params: null
      },
      {
        text: 'Shit!',
        kind: 'shout',
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
        kind: 'shout',
        radius: 7,
        alertness: 15,
        params: null
      },
      {
        file: 'male-scream',
        text: 'Bitch!',
        kind: 'shout',
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
