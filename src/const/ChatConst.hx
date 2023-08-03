
package const;

class ChatConst
{
  public static var actionsSkill: Map<String, _Skill> = [
    'Analyze' => SKILL_PSYCHOLOGY,
    'Encourage' => SKILL_COAXING,
    'Assure' => SKILL_COAXING,
    'Discuss' => SKILL_COAXING,
    'Empathize' => SKILL_COAXING,
    'Provoke' => SKILL_COERCION,
    'Threaten' => SKILL_COERCION,
    'Scare' => SKILL_COERCION,
    'Shock' => SKILL_COERCION,
    'Lie' => SKILL_DECEPTION,
    'Distort' => SKILL_DECEPTION,
    'Flatter' => SKILL_DECEPTION,
    'Request' => SKILL_DECEPTION,
  ];
  public static var needs = [
    'Sense of Belonging', // The need to feel connected, accepted, and valued by others. It involves having meaningful relationships, social support, and a sense of community.
    'Self-Esteem/Competence', // The need for self-respect, self-acceptance, and a positive self-image. It involves having a healthy sense of self-worth and feeling confident in one's abilities and attributes.
    'Intellectual Stimulation/Curiosity', // The need for intellectual engagement, curiosity, and mental stimulation. It involves opportunities for learning, growth, and the pursuit of knowledge and understanding.
    'Safety and Security', // The need to feel safe, both physically and emotionally. It involves having a sense of stability, predictability, and protection from harm or threat.
    'Achievement', // The drive to set and accomplish goals, experience success, and attain a sense of competence and accomplishment.
    'Competitiveness', // The drive to outperform others, excel in activities, and strive for superiority or recognition.
    'Autonomy', // The drive for independence, self-direction, and the freedom to make choices and decisions.
    'Self-expression', // The drive to express oneself authentically, creatively, and in alignment with one's values and identity.
    'Purpose and Meaning', // The drive to find and pursue a sense of purpose, meaning, and fulfillment in life.
  ];

  public static var actionDesc = [
    'Assure' => 'Confidently reassuring',
    'Discuss' => 'While openly discussing the topic with',
    'Distort' => 'Skillfully distorting the narrative for',
    'Empathize' => 'When you sincerely empathize with',
    'Encourage' => 'Actively encouraging',
    'Flatter' => 'While you cynically flatter',
    'Lie' => 'Flatly lying to',
  ];
  public static var actionDescFail = [
    'Analyze' => 'analyze',
    'Assure' => 'reassure',
    'Discuss' => 'discuss the topic with',
    'Distort' => 'distort the narrative for',
    'Empathize' => 'empathize with',
    'Encourage' => 'encourage',
    'Flatter' => 'flatter',
    'Lie' => 'lie to',
    'Provoke' => 'provoke',
    'Request' => 'request something from',
    'Scare' => 'scare',
    'Shock' => 'shock',
    'Threaten' => 'threaten',
  ];

// Coaxing - Encourage 6, Assure 7, Discuss 3, Empathize 6
// Deception - Lie 8, Distort 6, Flatter 4
  public static var needActions = [
    // Sense of Belonging
    [
      'Encourage',
      'Empathize',
    ],
    // Self-Esteem/Competence
    [
      'Assure',
      'Flatter',
      'Lie',
    ],
    // Intellectual Stimulation/Curiosity
    [
      'Discuss',
      'Lie',
    ],
    // Safety and Security
    [
      'Assure',
      'Distort',
      'Empathize',
      'Lie',
    ],
    // Achievement
    [
      'Assure',
      'Distort',
      'Empathize',
      'Encourage',
      'Flatter',
      'Lie',
    ],
    // Competitiveness
    [
      'Assure',
      'Distort',
      'Encourage',
      'Flatter',
      'Lie',
    ],
    // Autonomy
    [
      'Assure',
      'Distort',
      'Empathize',
      'Encourage',
      'Lie',
    ],
    // Self-expression
    [
      'Assure',
      'Discuss',
      'Distort',
      'Empathize',
      'Encourage',
      'Flatter',
      'Lie',
    ],
    // Purpose and Meaning
    [
      'Assure',
      'Discuss',
      'Distort',
      'Empathize',
      'Encourage',
      'Lie',
    ],
  ];

  public static var needStrings = [
    // Sense of Belonging
    [
	  'experiences a sense of isolation and estrangement from others.',
	  'perceives himself as disconnected and distant from those around him.',
	  'feels socially excluded and out of place in social interactions.',
	  'has a deep feeling of estrangement and disconnection.',
	  'senses a lack of belonging and struggles to connect with others.',
	  'feels like an outsider, not fitting in with the social dynamics.',
	  'is emotionally disconnected, finding it difficult to form meaningful connections.',
	  'feels isolated and distant from the social fabric.',
	  'perceives a divide between himself and others, leading to a sense of alienation.',
	  'feels cut off from social connections and experiences a sense of separation.',
    ],
    // Self-Esteem/Competence
    [
	  'lacks confidence in his abilities and feels incompetent.',
	  'struggles with tasks and experiences a sense of incompetence.',
	  'doubts his own capabilities and feels inadequate.',
	  'perceives himself as ineffective and lacking the necessary skills.',
	  'feels incapable and unsure of his own abilities.',
	  'has a low self-esteem and believes he is incompetent.',
	  'constantly questions his competence and feels inadequate.',
	  'is overwhelmed by tasks and experiences a sense of incompetence.',
	  'views himself as unskilled and often feels incompetent.',
	  'has a persistent feeling of incompetence and self-doubt.',
    ],
    // Intellectual Stimulation/Curiosity
    [
	  'has an insatiable desire to explore and learn.',
	  'possesses an innate inclination to discover and inquire.',
	  'experiences an eager inquisitiveness about the world around him.',
	  'is driven by a deep sense of wonder and a thirst for knowledge.',
	  'has a keen interest in unraveling mysteries and uncovering new information.',
	  'feels a natural inclination to investigate and understand the unknown.',
	  'is captivated by the allure of discovering and expanding his understanding.',
	  'possesses an inquiring mind, always seeking to broaden his intellectual horizons.',
	  'is animated by an insatiable curiosity that fuels his quest for knowledge.',
	  'has an innate drive to explore, question, and gain deeper insights into various subjects.',
    ],
    // Safety and Security
    [
	  'experiences a sense of vulnerability and insecurity.',
	  'has a deep feeling of unease and lack of security.',
	  'perceives a constant threat and a lack of personal safety.',
	  'feels apprehensive and on edge in his surroundings.',
	  'senses a heightened level of danger and discomfort.',
	  'has a persistent feeling of being at risk and unprotected.',
	  'is unsettled and wary in his environment.',
	  'feels a profound sense of insecurity and vulnerability.',
	  'experiences a lack of peace of mind and a constant sense of uneasiness.',
	  'perceives a lack of stability and a potential for harm in his surroundings.',
    ],
    // Achievement
    [
	  'experiences a sense of unfulfillment and disappointment.',
	  'has a deep feeling of not achieving his desired goals.',
	  'perceives himself as falling short of his expectations.',
	  'feels a sense of underachievement and dissatisfaction.',
	  'senses a lack of accomplishment and progress in his endeavors.',
	  'has a persistent feeling of not reaching his desired level of success.',
	  'is dissatisfied with his current achievements and feels unaccomplished.',
	  'feels like he hasn\'t lived up to his own standards of success.',
	  'experiences a sense of inadequacy and a lack of personal fulfillment.',
	  'perceives a gap between where he is and where he wants to be in terms of success.',
    ],
    // Competitiveness
    [
	  'has a strong drive to excel and surpass others.',
	  'yearns to be superior and stand out from the rest.',
	  'aspires to outshine his peers and be the best.',
	  'harbors a competitive spirit and strives for supremacy.',
	  'longs to surpass the achievements of others and be at the top.',
	  'has an intense desire to outdo his competitors and be on top of the game.',
	  'is motivated by the goal of outperforming his counterparts and achieving greatness.',
	  'seeks to outstrip the accomplishments of others and establish himself as the leader.',
	  'is driven by a relentless ambition to outshine and outperform those around him.',
	  'craves to surpass the abilities and achievements of his peers and be the pinnacle of success.',
    ],
    // Autonomy
    [
	  'yearns for independence and self-governance.',
	  'longs for the freedom to make his own decisions and choices.',
	  'aspires to have control over his own life and actions.',
	  'seeks self-reliance and the ability to steer his own path.',
	  'craves personal freedom and the power to determine his own destiny.',
	  'desires to break free from constraints and embrace autonomy.',
	  'yearns for the ability to live on his own terms and be self-sufficient.',
	  'strives for independence and the freedom to follow his own principles.',
	  'seeks liberation from external influences and the opportunity to chart his own course.',
	  'has a strong desire for autonomy, where he can take full ownership and responsibility for his actions and decisions.',
    ],
    // Self-expression
    [
	  'yearns to share his thoughts, emotions, and ideas freely.',
	  'longs to communicate his true self and be heard.',
	  'has an inner drive to articulate his unique perspective and experiences.',
	  'aspires to convey his thoughts and feelings authentically.',
	  'craves the opportunity to express his creativity and individuality.',
	  'seeks a platform to voice his opinions, beliefs, and values.',
	  'desires to communicate his inner world and connect with others through self-expression.',
	  'yearns to unleash his artistic abilities to convey his identity.',
	  'strives for the freedom to express himself without fear of judgment or suppression.',
	  'seeks outlets that allow him to share his unique voice and leave a meaningful impact.',
    ],
    // Purpose and Meaning
    [
	  'yearns for a sense of meaning and significance in his life.',
	  'longs to find his true calling and a sense of purpose.',
	  'has a deep desire to contribute meaningfully and make a difference.',
	  'aspires to lead a purpose-driven life, where his actions align with his values.',
	  'craves a sense of direction and a clear sense of purpose in his endeavors.',
	  'seeks to discover his unique purpose and live a life of fulfillment.',
	  'desires to find meaning in his experiences and connect with something greater than himself.',
	  'yearns to make a meaningful impact on the world and leave a lasting legacy.',
	  'strives to find his passion and purpose, where his work and contributions have significance.',
	  'seeks a sense of purpose that brings joy and fulfillment to his life.',
    ],
  ];

  public static var aspects = [
    'normal',
    'jumpy',
    'nervous',
    'submissive',
    'non-confrontational',
    'timid', // 5
    'resilient',
    'hot-headed',
    'irritable',
    'explosive',
    'temperamental', // 10
    'detached',
    'indifferent',
    'prone to anger',
    'impatient',
    'adaptive', // 15
    'impulsive',
    'narcissistic',
    'exhausted',
  ];
  // NOTE: indexes must be the same as in _ChatEmotion
  public static var emotions = [
    'none',
    'startled',
    'angry',
    'distressed',
    'desensitized',
  ];

  public static var shockSpeechHost = [
    'I will expose your secret.',
    'I will harm you and your loved ones.',
    'I will make your life miserable.',
    'If you resist, you will suffer the consequences.',
    "I have ways of making your life a living nightmare.",
    "I have the power to ruin everything you've worked for.",
    "I'll haunt your every waking moment.",
    "I have the power to make your life unravel.",
    "There's no running from me.",
    "Your secrets won't stay hidden for long.",
    "I can make your worst nightmares come true.",
    "I have ways of making you suffer.",
    "Resistance is futile.",
    "I can see into your deepest fears and desires.",
    "I will consume your mind and leave only darkness.",
    "You cannot escape my grasp.",
    "I am always watching.",
    "Your existence is insignificant.",
    "Every step you take, I am right behind you.",
    "Your screams will be music to my ears.",
    "I will drain your life force until there is nothing left.",
    "You cannot comprehend the horrors that await you.",
  ];

  public static var shockSpeech = [
    "You're not as safe as you think.",
    "We know everything about you and your past.",
    "You're just a pawn in a much bigger game.",
    "We control your fate.",
    "We have eyes and ears everywhere.",
    "Your actions have consequences.",
    "Your life is a puzzle, and we hold the missing pieces.",
    "Your secrets will be exposed, and your life will crumble.",
    "You're being watched at all times.",
    "We have evidence that can ruin your reputation and career.",
    "You're walking on thin ice.",
    "You're playing with fire.",
    "One wrong move will shatter your world.",
  ];
}
