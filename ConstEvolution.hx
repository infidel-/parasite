// evolution constants

class ConstEvolution
{
  // major evolution paths
  public static var paths: Array<PathInfo> =
    [
      { id: PATH_PROTECTION, name: 'Protection' },
      { id: PATH_CONTROL, name: 'Control' },
      { id: PATH_ATTACK, name: 'Attack' },
      { id: PATH_CONCEAL, name: 'Concealment' },
      { id: PATH_SPECIAL, name: 'Special' },
    ];


  // improvement info
  public static var improvements: Array<ImprovInfo> =
    [
      // =============== ************ CONCEAL *************** ===================
/*
      { // ***
        path: PATH_CONCEAL,
        id: IMP_HOST_RELEASE,
        name: '[TODO] Host release process',
        note: 'Controls what happens to the host when parasite leaves',
        levelNotes: [
          'Host dies with its brain melting and dripping out of its ears',
          'Host becomes crazy [TODO]',
          'Host is left intact - alive and conscious with all memory wiped [TODO]',
          'Host is left alive and conscious, and is implanted with fake memories [TODO]',
          ],
        levelParams: []
      },
*/
      { // ***
        path: PATH_CONCEAL,
        id: IMP_DECAY_ACCEL,
        name: 'Decay acceleration',
        note: 'Special bacteria and enzymes accelerate autolysis and putrefaction allowing significantly more efficient tissue decomposition of the host body after death',
        organ: {
          name: 'Decay accelerant cysts',
          note: 'Cysts of special bacteria and enzymes spread throughout the body to accelerate its decay after death',
          gp: 75
          },
        levelNotes: [
          'Only natural decomposition occurs',
          'Host body takes a lot of time to decompose',
          'Host body takes some time to decompose',
          'Host body takes a little time to decompose',
          ],
        levelParams: [
          { turns: 1000 },
          { turns: 10 },
          { turns: 5 },
          { turns: 2 },
          ],
      },

      { // ***
        path: PATH_CONCEAL,
        id: IMP_CAMO_LAYER, 
        name: 'Camouflage layer',
        note: 'Allows covering parasite body with a self-regenerating camouflage layer that looks like host skin and clothing',
        organ: {
          name: 'Camouflage layer',
          note: 'Self-regenerating camouflage layer that covers parasite body changing its appearance',
          gp: 100
          },
        levelNotes: [
          'A perfectly visible huge purple blob on head and upper body of the host',
          'Streaks of purple running through the partly grown camouflage layer',
          'Parasite body is mostly covered by camouflage layer',
          'Camouflage layer fully covers the parasite. Only close inspection will alert bystanders',
          ],
        levelParams: [
          { alertness: 3 },
          { alertness: 2 },
          { alertness: 1 },
          { alertness: 0.5 },
          ]
      },

      // =============== ************ PROTECTION *************** ===================

      { // ***
        path: PATH_PROTECTION,
        id: IMP_PROT_COVER,
        name: 'Protective cover',
        note: 'Heavy epidermis keratinization and dermis densification later allows for an armor-like body cover on the host with the downside of significantly altered host appearance',
        organ: {
          name: 'Protective cover',
          note: 'Armor-like host body cover providing protection against damage at the expense of appearance',
          gp: 150
          },
        levelNotes: [
          'Normal host skin',
          'Pigmented skin layer looks grayish to the eye',
          'Collagen fibres running through the dermis layer',
          'Heavily keratinized and densified skin provides the body with an effective armor',
          ],
        levelParams: [
          { armor: 0, alertness: 0 },
          { armor: 1, alertness: 1 },
          { armor: 2, alertness: 5 },
          { armor: 3, alertness: 10 },
          ],
      },

      { // ***
        path: PATH_PROTECTION,
        id: IMP_WOUND_REGEN,
        name: 'Wound regeneration',
        note: 'Microreservoirs of adult stem cells form in many tissues of the host body greatly increasing the efficacy and speed of wound healing process',
        organ: {
          name: 'Stem cell reservoirs',
          note: 'Microreservoirs of adult stem cells that increase wound recovery speed',
          gp: 120
          },
        levelNotes: [
          'Normal wound recovery',
          'Wound recovery speed is slightly increased',
          'Wound recovery speed is moderately increased',
          'Wound recovery speed is greatly increased',
          ],
        levelParams: [
          { turns: 100 },
          { turns: 20 },
          { turns: 10 },
          { turns: 5 },
          ],
      },

      { // ***
        path: PATH_PROTECTION,
        id: IMP_HEALTH,
        name: 'Health increase',
        note: 'Direct synthesis of antibodies through specialized biofactories increases the responce speed of adaptive immune system adding to overall host health',
        organ: {
          name: 'Antibody generators',
          note: 'Specialized producers of antibodies that increase overall host health',
          gp: 80
          },
        levelNotes: [
          'Normal health',
          'Health is slightly increased',
          'Health is moderately increased',
          'Health is greatly increased',
          ],
        levelParams: [
          { health: 0 },
          { health: 1 },
          { health: 2 },
          { health: 3 },
          ],
      },

      // =============== ************ ATTACK *************** ===================

      { // ***
        path: PATH_ATTACK,
        id: IMP_MUSCLE,
        name: 'Muscle enhancement',
        note: 'Neovascularization within muscles enhances the ability to move waste products out and maintain contraction reducing the accumulated metabolic fatigue which results in increased host strength',
        organ: {
          name: 'Microvascular networks',
          note: 'Functional miscrovascular networks throughout the muscle tissue enhance host body strength',
          gp: 120
          },
        levelNotes: [
          'Normal host strength',
          'Basic muscle neovascularization',
          'Enhanced muscle neovascularization',
          'Improved neovascularization with additional substrate storage',
          ],
        levelParams: [
          { strength: 0 },
          { strength: 1 },
          { strength: 2 },
          { strength: 3 },
          ],
      },

      { // ***
        path: PATH_ATTACK,
        id: IMP_ACID_SPIT,
        name: '??Acid spit',
        note: '(todo fluff)',
        organ: {
          name: '??Acid spit',
          note: '(todo fluff)',
          gp: 150,
          action: { 
            id: 'acidSpit',
            type: ACTION_ORGAN,
            name: '??Acid spit',
            energy: 10
            },
          },
        levelNotes: [
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          ],
        levelParams: [
          {
            minDamage: 0,
            maxDamage: 0,
            range: 0
          },
          {
            minDamage: 1,
            maxDamage: 2,
            range: 1
          },
          {
            minDamage: 1,
            maxDamage: 3,
            range: 2
          },
          {
            minDamage: 1,
            maxDamage: 4,
            range: 3
          },
          ],
      },

      { // ***
        path: PATH_ATTACK,
        id: IMP_SLIME_SPIT,
        name: '??Slime spit',
        note: '(todo fluff)',
        organ: {
          name: '??Slime spit',
          note: '(todo fluff)',
          gp: 100,
          action: { 
            id: 'slimeSpit',
            type: ACTION_ORGAN,
            name: '??Slime spit',
            energy: 5
            },
          },
        levelNotes: [
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          ],
        levelParams: [
          {
            strength: 0,
            range: 0
          },
          {
            strength: 10,
            range: 1
          },
          {
            strength: 20,
            range: 2
          },
          {
            strength: 30,
            range: 3
          },
          ],
      },

      // =============== ************ CONTROL *************** ===================

      { // ***
        path: PATH_CONTROL,
        id: IMP_ATTACH,
        name: '??Attach efficiency',
        note: '(todo fluff)',
        levelNotes: [
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          ],
        levelParams: [
          { attachHoldBase: 10 },
          { attachHoldBase: 15 },
          { attachHoldBase: 20 },
          { attachHoldBase: 25 },
          ],
      },

      { // ***
        path: PATH_CONTROL,
        id: IMP_HARDEN_GRIP,
        name: '??Hold efficiency',
        note: '(todo fluff)',
        levelNotes: [
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          ],
        levelParams: [
          { attachHoldBase: 15 },
          { attachHoldBase: 20 },
          { attachHoldBase: 25 },
          { attachHoldBase: 30 },
          ],
      },

      { // ***
        path: PATH_CONTROL,
        id: IMP_REINFORCE,
        name: '??Control efficiency',
        note: '(todo fluff)',
        levelNotes: [
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          ],
        levelParams: [
          { reinforceControlBase: 10 },
          { reinforceControlBase: 15 },
          { reinforceControlBase: 20 },
          { reinforceControlBase: 25 },
          ],
      },


      // =============== ************ SPECIAL *************** ===================

      { // ***
        path: PATH_SPECIAL,
        id: IMP_HOST_MEMORY, 
        name: '??Host memory',
        note: 'Gains access to host memory',
        skill: KNOW_MEMORY,
        skillValue: 1, 
        levelNotes: [
          'Cannot access host brain',
          'Access with severe problems (basic knowledge)',
          'Limited access with some problems (extensive knowledge and basic skills)',
          'Full access',
          ],
        levelParams: [
          { 
            humanSociety: 0,
            hostEnergyBase: 0, 
            hostHealthBase: 0,
            hostHealthMod: 0,
            hostSkillsMod: 0,
          },
          { 
            humanSociety: 0.25, 
            hostEnergyBase: 30, 
            hostHealthBase: 3,
            hostHealthMod: 2,
            hostSkillsMod: 0,
          },
          { 
            humanSociety: 0.5, 
            hostEnergyBase: 20, 
            hostHealthBase: 1,
            hostHealthMod: 1,
            hostSkillsMod: 0.25,  // can access skills from level 2
          },
          { 
            humanSociety: 1.0, 
            hostEnergyBase: 10, 
            hostHealthBase: 0,
            hostHealthMod: 1,
            hostSkillsMod: 0.5,
          },
          ],
      },

      { // ***
        path: PATH_SPECIAL,
        id: IMP_ENERGY,
        name: '??Host energy bonus',
        note: '(todo fluff)',
        organ: {
          name: '??Host energy bonus',
          note: '(todo fluff)',
          gp: 200
          },
        levelNotes: [
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          ],
        levelParams: [
          { hostEnergyMod: 1.0 },
          { hostEnergyMod: 1.25 },
          { hostEnergyMod: 1.50 },
          { hostEnergyMod: 2.0 },
          ],
      },
/*      
      { // ***
        path: PATH_,
        id: IMP_,
        name: '',
        note: '(todo fluff)',
        organ: {
          name: '',
          note: '(todo fluff)',
          gp: 100,
          action: { 
            id: '',
            type: ACTION_ORGAN,
            name: '',
            energy: 10
            },
          },
        levelNotes: [
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          '(todo fluff)',
          ],
        levelParams: [
          {},
          {},
          {},
          {},
          ],
      },
*/      
    ];


// ep needed to upgrade improvement to next level (index is current level)
  public static var epCostImprovement = [ 100, 200, 500, 1000 ];
// ep needed to open new improvement on path (index is current path level)
  public static var epCostPath = [ 100, 200, 500, 1000, 2000, 5000 ];


// get improvement info
  public static function getInfo(id: _Improv): ImprovInfo
    {
      for (imp in improvements)
        if (imp.id == id)
          return imp;

      return null;
    }


// get improvement parameters of the specified level
  public static function getParams(id: _Improv, level: Int): Dynamic
    {
      for (imp in improvements)
        if (imp.id == id)
          return imp.levelParams[level];
      
      return null;
    }

/*
// get improvement info by organ id
  public static function getInfoByOrganID(id: String): ImprovInfo
    {
      for (imp in improvements)
        if (imp.organ != null && imp.organ.id == id)
          return imp;

      return null;
    }
*/

// get path info
  public static function getPathInfo(id: _Path): PathInfo
    {
      for (p in paths)
        if (p.id == id)
          return p;

      return null;
    }
}


typedef ImprovInfo =
{
  id: _Improv, // improvement string ID
  path: _Path, // path ID
  name: String, // improvement name
  note: String, // improvement description
  ?organ: OrganInfo, // organ that can be grown
  ?skill: _Skill,  // given skill id
  ?skillValue: Int, // amount of skill given
  levelNotes: Array<String>, // improvement descriptions for different levels
  levelParams: Array<Dynamic>, // improvement-specific parameters for different levels
}

typedef PathInfo =
{
  var id: _Path; // path string ID
  var name: String; // path name
}


typedef OrganInfo =
{
  name: String, // name
  note: String, // description
  gp: Int, // gp cost to grow
  ?action: _PlayerAction // player action
}
