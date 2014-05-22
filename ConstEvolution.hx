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
        organ: null,
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


      // =============== ************ SPECIAL *************** ===================

      { // ***
        path: PATH_SPECIAL,
        id: IMP_HOST_MEMORY, 
        name: 'Host memory',
        note: 'Gains access to host memory',
        organ: null,
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

/*      
      { // ***
        path: PATH_,
        id: IMP_,
        name: '',
        note: '',
        organ: {
          name: '',
          note: '',
          gp: 100
          },
        levelNotes: [
          '',
          '',
          '',
          '',
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
  var id: _Improv; // improvement string ID
  var path: _Path; // path ID
  var name: String; // improvement name
  var note: String; // improvement description
  var organ: OrganInfo; // organ that can be grown
  var levelNotes: Array<String>; // improvement descriptions for different levels
  var levelParams: Array<Dynamic>; // improvement-specific parameters for different levels
}

typedef PathInfo =
{
  var id: _Path; // path string ID
  var name: String; // path name
}


typedef OrganInfo =
{
  var name: String; // name
  var note: String; // description
  var gp: Int; // gp cost to grow
}
