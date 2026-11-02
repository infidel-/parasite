
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

  // whole sentence of a consent action that worked, by action name: {stun} is how hard it lands (0-3)
  public static var actionDesc = [
    // tr: a conversation move that worked; {stun} is how hard it lands, 0 (weakest) to 3
    'Assure' => T('Confidently reassuring {ai:the}, you observe a {stun, select, 0{noticeable} 1{significant} 2{tremendous} other{staggering}} growth in {ai, select, m{his} f{her} other{its}} consent.'),
    'Discuss' => T('While openly discussing the topic with {ai:the}, you observe a {stun, select, 0{noticeable} 1{significant} 2{tremendous} other{staggering}} growth in {ai, select, m{his} f{her} other{its}} consent.'),
    'Distort' => T('Skillfully distorting the narrative for {ai:the}, you observe a {stun, select, 0{noticeable} 1{significant} 2{tremendous} other{staggering}} growth in {ai, select, m{his} f{her} other{its}} consent.'),
    'Empathize' => T('When you sincerely empathize with {ai:the}, you observe a {stun, select, 0{noticeable} 1{significant} 2{tremendous} other{staggering}} growth in {ai, select, m{his} f{her} other{its}} consent.'),
    'Encourage' => T('Actively encouraging {ai:the}, you observe a {stun, select, 0{noticeable} 1{significant} 2{tremendous} other{staggering}} growth in {ai, select, m{his} f{her} other{its}} consent.'),
    'Flatter' => T('While you cynically flatter {ai:the}, you observe a {stun, select, 0{noticeable} 1{significant} 2{tremendous} other{staggering}} growth in {ai, select, m{his} f{her} other{its}} consent.'),
    'Lie' => T('Flatly lying to {ai:the}, you observe a {stun, select, 0{noticeable} 1{significant} 2{tremendous} other{staggering}} growth in {ai, select, m{his} f{her} other{its}} consent.'),
  ];
  // whole sentence of a calming action on an emotional target, by action name: {calm} is full or partial
  public static var actionDescCalm = [
    // tr: a conversation move that calms an upset person; {calm} is full (calm again) or partial
    'Assure' => T('Confidently reassuring {ai:the}, you observe how {ai, select, m{he} f{she} other{it}} calms down {calm, select, full{completely} other{to a degree}}.'),
    'Empathize' => T('When you sincerely empathize with {ai:the}, you observe how {ai, select, m{he} f{she} other{it}} calms down {calm, select, full{completely} other{to a degree}}.'),
    'Lie' => T('Flatly lying to {ai:the}, you observe how {ai, select, m{he} f{she} other{it}} calms down {calm, select, full{completely} other{to a degree}}.'),
  ];
  // whole sentence of a failed skill roll, by action name
  public static var actionDescFail = [
    'Analyze' => T('You try to analyze {ai:the} but fail miserably.'),
    'Assure' => T('You try to reassure {ai:the} but fail miserably.'),
    'Discuss' => T('You try to discuss the topic with {ai:the} but fail miserably.'),
    'Distort' => T('You try to distort the narrative for {ai:the} but fail miserably.'),
    'Empathize' => T('You try to empathize with {ai:the} but fail miserably.'),
    'Encourage' => T('You try to encourage {ai:the} but fail miserably.'),
    'Flatter' => T('You try to flatter {ai:the} but fail miserably.'),
    'Lie' => T('You try to lie to {ai:the} but fail miserably.'),
    'Provoke' => T('You try to provoke {ai:the} but fail miserably.'),
    'Request' => T('You try to request something from {ai:the} but fail miserably.'),
    'Scare' => T('You try to scare {ai:the} but fail miserably.'),
    'Shock' => T('You try to shock {ai:the} but fail miserably.'),
    'Threaten' => T('You try to threaten {ai:the} but fail miserably.'),
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

  // the analysis's first sentence, by need and string ID (both saved in _AIChat: keep the order)
  public static var needStrings = [
    // Sense of Belonging
    [
      // tr: first sentence of a psychological analysis. {aspect} is a phrase like 'a jumpy individual' (aspectDesc), or none
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}experiences a sense of isolation and estrangement from others.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}perceives {ai, select, m{himself} f{herself} other{itself}} as disconnected and distant from those around {ai, select, m{him} f{her} other{it}}.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}feels socially excluded and out of place in social interactions.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}has a deep feeling of estrangement and disconnection.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}senses a lack of belonging and struggles to connect with others.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}feels like an outsider, not fitting in with the social dynamics.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}is emotionally disconnected, finding it difficult to form meaningful connections.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}feels isolated and distant from the social fabric.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}perceives a divide between {ai, select, m{himself} f{herself} other{itself}} and others, leading to a sense of alienation.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}feels cut off from social connections and experiences a sense of separation.'),
    ],
    // Self-Esteem/Competence
    [
      // tr: first sentence of a psychological analysis. {aspect} is a phrase like 'a jumpy individual' (aspectDesc), or none
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}lacks confidence in {ai, select, m{his} f{her} other{its}} abilities and feels incompetent.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}struggles with tasks and experiences a sense of incompetence.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}doubts {ai, select, m{his} f{her} other{its}} own capabilities and feels inadequate.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}perceives {ai, select, m{himself} f{herself} other{itself}} as ineffective and lacking the necessary skills.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}feels incapable and unsure of {ai, select, m{his} f{her} other{its}} own abilities.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}has a low self-esteem and believes {ai, select, m{he} f{she} other{it}} is incompetent.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}constantly questions {ai, select, m{his} f{her} other{its}} competence and feels inadequate.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}is overwhelmed by tasks and experiences a sense of incompetence.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}views {ai, select, m{himself} f{herself} other{itself}} as unskilled and often feels incompetent.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}has a persistent feeling of incompetence and self-doubt.'),
    ],
    // Intellectual Stimulation/Curiosity
    [
      // tr: first sentence of a psychological analysis. {aspect} is a phrase like 'a jumpy individual' (aspectDesc), or none
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}has an insatiable desire to explore and learn.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}possesses an innate inclination to discover and inquire.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}experiences an eager inquisitiveness about the world around {ai, select, m{him} f{her} other{it}}.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}is driven by a deep sense of wonder and a thirst for knowledge.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}has a keen interest in unraveling mysteries and uncovering new information.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}feels a natural inclination to investigate and understand the unknown.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}is captivated by the allure of discovering and expanding {ai, select, m{his} f{her} other{its}} understanding.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}possesses an inquiring mind, always seeking to broaden {ai, select, m{his} f{her} other{its}} intellectual horizons.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}is animated by an insatiable curiosity that fuels {ai, select, m{his} f{her} other{its}} quest for knowledge.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}has an innate drive to explore, question, and gain deeper insights into various subjects.'),
    ],
    // Safety and Security
    [
      // tr: first sentence of a psychological analysis. {aspect} is a phrase like 'a jumpy individual' (aspectDesc), or none
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}experiences a sense of vulnerability and insecurity.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}has a deep feeling of unease and lack of security.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}perceives a constant threat and a lack of personal safety.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}feels apprehensive and on edge in {ai, select, m{his} f{her} other{its}} surroundings.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}senses a heightened level of danger and discomfort.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}has a persistent feeling of being at risk and unprotected.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}is unsettled and wary in {ai, select, m{his} f{her} other{its}} environment.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}feels a profound sense of insecurity and vulnerability.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}experiences a lack of peace of mind and a constant sense of uneasiness.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}perceives a lack of stability and a potential for harm in {ai, select, m{his} f{her} other{its}} surroundings.'),
    ],
    // Achievement
    [
      // tr: first sentence of a psychological analysis. {aspect} is a phrase like 'a jumpy individual' (aspectDesc), or none
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}experiences a sense of unfulfillment and disappointment.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}has a deep feeling of not achieving {ai, select, m{his} f{her} other{its}} desired goals.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}perceives {ai, select, m{himself} f{herself} other{itself}} as falling short of {ai, select, m{his} f{her} other{its}} expectations.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}feels a sense of underachievement and dissatisfaction.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}senses a lack of accomplishment and progress in {ai, select, m{his} f{her} other{its}} endeavors.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}has a persistent feeling of not reaching {ai, select, m{his} f{her} other{its}} desired level of success.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}is dissatisfied with {ai, select, m{his} f{her} other{its}} current achievements and feels unaccomplished.'),
      T("Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}feels like {ai, select, m{he} f{she} other{it}} hasn't lived up to {ai, select, m{his} f{her} other{its}} own standards of success."),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}experiences a sense of inadequacy and a lack of personal fulfillment.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}perceives a gap between where {ai, select, m{he} f{she} other{it}} is and where {ai, select, m{he} f{she} other{it}} wants to be in terms of success.'),
    ],
    // Competitiveness
    [
      // tr: first sentence of a psychological analysis. {aspect} is a phrase like 'a jumpy individual' (aspectDesc), or none
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}has a strong drive to excel and surpass others.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}yearns to be superior and stand out from the rest.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}aspires to outshine {ai, select, m{his} f{her} other{its}} peers and be the best.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}harbors a competitive spirit and strives for supremacy.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}longs to surpass the achievements of others and be at the top.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}has an intense desire to outdo {ai, select, m{his} f{her} other{its}} competitors and be on top of the game.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}is motivated by the goal of outperforming {ai, select, m{his} f{her} other{its}} counterparts and achieving greatness.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}seeks to outstrip the accomplishments of others and establish {ai, select, m{himself} f{herself} other{itself}} as the leader.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}is driven by a relentless ambition to outshine and outperform those around {ai, select, m{him} f{her} other{it}}.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}craves to surpass the abilities and achievements of {ai, select, m{his} f{her} other{its}} peers and be the pinnacle of success.'),
    ],
    // Autonomy
    [
      // tr: first sentence of a psychological analysis. {aspect} is a phrase like 'a jumpy individual' (aspectDesc), or none
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}yearns for independence and self-governance.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}longs for the freedom to make {ai, select, m{his} f{her} other{its}} own decisions and choices.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}aspires to have control over {ai, select, m{his} f{her} other{its}} own life and actions.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}seeks self-reliance and the ability to steer {ai, select, m{his} f{her} other{its}} own path.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}craves personal freedom and the power to determine {ai, select, m{his} f{her} other{its}} own destiny.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}desires to break free from constraints and embrace autonomy.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}yearns for the ability to live on {ai, select, m{his} f{her} other{its}} own terms and be self-sufficient.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}strives for independence and the freedom to follow {ai, select, m{his} f{her} other{its}} own principles.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}seeks liberation from external influences and the opportunity to chart {ai, select, m{his} f{her} other{its}} own course.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}has a strong desire for autonomy, where {ai, select, m{he} f{she} other{it}} can take full ownership and responsibility for {ai, select, m{his} f{her} other{its}} actions and decisions.'),
    ],
    // Self-expression
    [
      // tr: first sentence of a psychological analysis. {aspect} is a phrase like 'a jumpy individual' (aspectDesc), or none
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}yearns to share {ai, select, m{his} f{her} other{its}} thoughts, emotions, and ideas freely.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}longs to communicate {ai, select, m{his} f{her} other{its}} true self and be heard.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}has an inner drive to articulate {ai, select, m{his} f{her} other{its}} unique perspective and experiences.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}aspires to convey {ai, select, m{his} f{her} other{its}} thoughts and feelings authentically.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}craves the opportunity to express {ai, select, m{his} f{her} other{its}} creativity and individuality.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}seeks a platform to voice {ai, select, m{his} f{her} other{its}} opinions, beliefs, and values.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}desires to communicate {ai, select, m{his} f{her} other{its}} inner world and connect with others through self-expression.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}yearns to unleash {ai, select, m{his} f{her} other{its}} artistic abilities to convey {ai, select, m{his} f{her} other{its}} identity.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}strives for the freedom to express {ai, select, m{himself} f{herself} other{itself}} without fear of judgment or suppression.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}seeks outlets that allow {ai, select, m{him} f{her} other{it}} to share {ai, select, m{his} f{her} other{its}} unique voice and leave a meaningful impact.'),
    ],
    // Purpose and Meaning
    [
      // tr: first sentence of a psychological analysis. {aspect} is a phrase like 'a jumpy individual' (aspectDesc), or none
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}yearns for a sense of meaning and significance in {ai, select, m{his} f{her} other{its}} life.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}longs to find {ai, select, m{his} f{her} other{its}} true calling and a sense of purpose.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}has a deep desire to contribute meaningfully and make a difference.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}aspires to lead a purpose-driven life, where {ai, select, m{his} f{her} other{its}} actions align with {ai, select, m{his} f{her} other{its}} values.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}craves a sense of direction and a clear sense of purpose in {ai, select, m{his} f{her} other{its}} endeavors.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}seeks to discover {ai, select, m{his} f{her} other{its}} unique purpose and live a life of fulfillment.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}desires to find meaning in {ai, select, m{his} f{her} other{its}} experiences and connect with something greater than {ai, select, m{himself} f{herself} other{itself}}.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}yearns to make a meaningful impact on the world and leave a lasting legacy.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}strives to find {ai, select, m{his} f{her} other{its}} passion and purpose, where {ai, select, m{his} f{her} other{its}} work and contributions have significance.'),
      T('Analyzing {ai:the} tells you that {ai, select, m{he} f{she} other{it}} {aspect, select, none{} other{is {aspect}, who }}seeks a sense of purpose that brings joy and fulfillment to {ai, select, m{his} f{her} other{its}} life.'),
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
  // the aspect as a phrase for the analysis ({aspect} in needStrings), by aspect; normal has none
  public static var aspectDesc = [
    'jumpy' => T('a jumpy individual'),
    'nervous' => T('a nervous individual'),
    'submissive' => T('a submissive individual'),
    'non-confrontational' => T('a non-confrontational individual'),
    'timid' => T('a timid individual'),
    'resilient' => T('a resilient individual'),
    'hot-headed' => T('a hot-headed individual'),
    'irritable' => T('an irritable individual'),
    'explosive' => T('an explosive individual'),
    'temperamental' => T('a temperamental individual'),
    'detached' => T('a detached individual'),
    'indifferent' => T('an indifferent individual'),
    'prone to anger' => T('an individual prone to anger'),
    'impatient' => T('an impatient individual'),
    'adaptive' => T('an adaptive individual'),
    'impulsive' => T('an impulsive individual'),
    'narcissistic' => T('a narcissistic individual'),
    'exhausted' => T('an exhausted individual'),
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
    // tr: the parasite threatens its own host (a narrative line)
    T('I will expose your secret.'),
    T('I will harm you and your loved ones.'),
    T('I will make your life miserable.'),
    T('If you resist, you will suffer the consequences.'),
    T("I have ways of making your life a living nightmare."),
    T("I have the power to ruin everything you've worked for."),
    T("I'll haunt your every waking moment."),
    T("I have the power to make your life unravel."),
    T("There's no running from me."),
    T("Your secrets won't stay hidden for long."),
    T("I can make your worst nightmares come true."),
    T("I have ways of making you suffer."),
    T("Resistance is futile."),
    T("I can see into your deepest fears and desires."),
    T("I will consume your mind and leave only darkness."),
    T("You cannot escape my grasp."),
    T("I am always watching."),
    T("Your existence is insignificant."),
    T("Every step you take, I am right behind you."),
    T("Your screams will be music to my ears."),
    T("I will drain your life force until there is nothing left."),
    T("You cannot comprehend the horrors that await you."),
  ];

  public static var shockSpeech = [
    // tr: the parasite's host threatens the person it talks to (a narrative line)
    T("You're not as safe as you think."),
    T("We know everything about you and your past."),
    T("You're just a pawn in a much bigger game."),
    T("We control your fate."),
    T("We have eyes and ears everywhere."),
    T("Your actions have consequences."),
    T("Your life is a puzzle, and we hold the missing pieces."),
    T("Your secrets will be exposed, and your life will crumble."),
    T("You're being watched at all times."),
    T("We have evidence that can ruin your reputation and career."),
    T("You're walking on thin ice."),
    T("You're playing with fire."),
    T("One wrong move will shatter your world."),
  ];
}
