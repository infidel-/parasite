// AI sounds

package const;

import ai.AI;
import _AIState;

class SoundConst
{
  // misc sounds
  public static var misc = [
    'parasite_die1',
    'parasite_die2',
    'watcher_ambush',
    'parasite_attach1',
    'parasite_detach1',
  ];

  // dog sounds
  static var growl = [
    'dog_growl1',
  ];
  public static var dog: Map<String, Array<AISound>> = [
    '' + REASON_DAMAGE => [
      {
        text: '*WHIMPER*',
        files: [
          'dog_whimper1',
        ],
        radius: 2,
        alertness: 5,
        params: null
      },
      {
        text: '*WHINE*',
        files: [
          'dog_whine1',
        ],
        radius: 2,
        alertness: 5,
        params: null
      },
      {
        text: '*YELP*',
        files: [
          'dog_yelp1',
        ],
        radius: 3,
        alertness: 5,
        params: null
      },
    ],
    '' + AI_STATE_IDLE => [
      {
        text: '*GROWL*',
        files: growl,
        radius: 2,
        alertness: 5,
        params: { minAlertness: 25 }
      },
    ],
    '' + AI_STATE_ALERT => [
      {
        text: '*BARK*',
        files: [
          'dog_bark1',
        ],
        radius: 5,
        alertness: 10,
        params: null
      },
    ],
    '' + AI_STATE_HOST => [
      {
        text: '*whimper*',
        files: [
          'dog_whimper1',
        ],
        radius: 2,
        alertness: 3,
        params: null
      },
      {
        text: '*whine*',
        files: [
          'dog_whine1',
        ],
        radius: 2,
        alertness: 3,
        params: null
      },
      {
        text: '*growl*',
        files: growl,
        radius: 2,
        alertness: 3,
        params: null
      },
      {
        text: '*GROWL*',
        files: growl,
        radius: 2,
        alertness: 3,
        params: null
      },
    ],
    '' + AI_STATE_DEAD => [
      {
        text: '*whine*',
        files: [
          'dog_die1',
        ],
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
      files: [
        'male_ouch1',
      ],
      radius: 2,
      alertness: 5,
      params: null
    },
    {
      text: '*GROAN*',
      files: [
        'male_grunt1',
      ],
      radius: 2,
      alertness: 5,
      params: null
    },
  ];
  static var humanIdle: Array<AISound> = [
    {
      text: 'Huh?',
      files: [
        'male_huh1',
      ],
      radius: 0,
      alertness: 0,
      params: { minAlertness: 25 }
    },
    {
      text: 'Whu?',
      files: [
        'male_whu1',
      ],
      radius: 0,
      alertness: 0,
      params: { minAlertness: 25 }
    },
    {
      text: 'What the?',
      files: [
        'male_what1',
      ],
      radius: 0,
      alertness: 0,
      params: { minAlertness: 50 }
    },
    {
      text: '*GASP*',
      files: [
        'male_gasp1',
      ],
      radius: 0,
      alertness: 0,
      params: { minAlertness: 75 }
    },
  ];
  static var humanHost: Array<AISound> = [
    {
      files: [
        'male_choke1',
        'male_choke2',
        'male_choke3',
      ],
      text: '*choke*',
      radius: 2,
      alertness: 3,
      params: null
    },
    {
      files: [
        'male_moan1',
        'male_moan2',
        'male_moan3',
      ],
      text: '*moan*',
      radius: 2,
      alertness: 5,
      params: null
    },
    {
      files: [
        'male_moan_loud1',
        'male_moan_loud2',
        'male_moan_loud3',
      ],
      text: '*MOAN*',
      radius: 3,
      alertness: 5,
      params: null
    },
  ];
  static var genericAlert: Array<AISound> = [
    {
      files: [
        'human_stop1',
      ],
      text: 'STOP!',
      radius: 7,
      alertness: 10,
      params: null
    },
  ];
  static var humanDie: Array<AISound> = [
    {
      text: '*death*',
      files: [
        'male_die1',
        'male_die2',
        'male_die3',
      ],
      radius: 6,
      alertness: 10,
      params: null
    },
  ];

  // civilian sounds
  public static var civilian: Map<String, Array<AISound>> = [
    '' + REASON_DAMAGE => humanDamage,
    '' + AI_STATE_IDLE => humanIdle,
    '' + AI_STATE_ALERT => [
      {
        files: [
          'male_scream1',
        ],
        text: '*SCREAM*',
        radius: 7,
        alertness: 15,
        params: null
      },
    ],
    '' + AI_STATE_HOST => humanHost,
    '' + AI_STATE_DEAD => humanDie,
  ];

  // police officer sounds
  public static var police: Map<String, Array<AISound>> = [
    '' + REASON_DAMAGE => humanDamage,
    '' + AI_STATE_IDLE => humanIdle,
    '' + AI_STATE_ALERT => genericAlert,
    '' + AI_STATE_HOST => humanHost,
    '' + AI_STATE_DEAD => humanDie,
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
        files: [
          'male_grunt1',
        ],
        radius: 2,
        alertness: 5,
        params: null
      },
      {
        text: '*GROAN*',
        files: [
          'male_grunt1',
        ],
        radius: 2,
        alertness: 5,
        params: null
      },
    ],
    '' + AI_STATE_IDLE => [
      {
        text: 'Huh?',
        files: [
          'male_huh1',
        ],
        radius: 0,
        alertness: 0,
        params: { minAlertness: 25 }
      },
      {
        text: 'Whu?',
        files: [
          'male_whu1',
        ],
        radius: 0,
        alertness: 0,
        params: { minAlertness: 25 }
      },
      {
        text: 'What the?',
        files: [
          'male_what1',
        ],
        radius: 0,
        alertness: 0,
        params: { minAlertness: 50 }
      },
      {
        text: 'BOGEY!',
        files: [
          'human_alert1',
        ],
        radius: 0,
        alertness: 0,
        params: { minAlertness: 75 }
      },
    ],
    '' + AI_STATE_ALERT => [
      {
        files: [
          'human_stop1',
        ],
        text: 'TANGO!',
        radius: 7,
        alertness: 10,
        params: null
      },
    ],
    '' + AI_STATE_HOST => humanHost,
    '' + AI_STATE_DEAD => humanDie,
  ];
}
