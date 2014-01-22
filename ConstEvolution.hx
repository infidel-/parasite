// evolution constants

class ConstEvolution
{
  // major evolution paths
  public static var paths: Array<PathInfo> =
    [
      { id: 'protection', name: 'Protection' },
      { id: 'control', name: 'Control' },
      { id: 'attack', name: 'Attack' },
      { id: 'conceal', name: 'Concealment' },
      { id: 'misc', name: 'Miscellaneous' },
    ];


  // improvement info
  public static var improvements: Array<ImprovInfo> =
    [
      {
        path: 'conceal',
        id: 'hostRelease',
        name: 'Host release process',
        note: 'Controls what happens to the host when parasite leaves.',
        organ: null,
        levelNotes: [
          'Host dies with its brain melting and dripping out of its ears.',
          'Host becomes crazy. [TODO]',
          'Host is left intact - alive and conscious with all memory wiped. [TODO]',
          'Host is left alive and conscious, and is implanted with fake memories. [TODO]',
          ],
        levelParams: []
      },
      {
        path: 'conceal',
        id: 'chameleonSkin',
        name: '[TODO] Chameleon skin',
        note: 'Allows covering parasite body with a temporary camouflage layer that looks like host skin and clothing.',
        organ: {
          id: 'camouflageLayer',
          name: 'Camouflage layer',
          note: 'Temporary camouflage layer that covers parasite body changing its appearance.',
          gp: 100
          },
        levelNotes: [
          'A perfectly visible huge purple blob on head and upper body of the host.',
          'Streaks of purple running through the partly grown camouflage layer.',
          'Parasite body is mostly covered by camouflage layer.',
          'Camouflage layer fully covers the parasite. Only close inspection will alert bystanders.',
          ],
        levelParams: [
          {
            baseAlertness: 3,
          },
          {
            baseAlertness: 2,
          },
          {
            baseAlertness: 1,
          },
          {
            baseAlertness: 0.5,
          },
          ]
      },

      {
        path: 'misc',
        id: 'hostMemory',
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
            hostTimer: 0, 
            hostHealthBase: 0,
            hostHealthMod: 0,
            hostSkillsMod: 0,
          },
          { 
            humanSociety: 0.25, 
            hostTimer: 30, 
            hostHealthBase: 3,
            hostHealthMod: 2,
            hostSkillsMod: 0,
          },
          { 
            humanSociety: 0.5, 
            hostTimer: 20, 
            hostHealthBase: 1,
            hostHealthMod: 1,
            hostSkillsMod: 0.25,  // can access skills from level 2
          },
          { 
            humanSociety: 1.0, 
            hostTimer: 10, 
            hostHealthBase: 0,
            hostHealthMod: 1,
            hostSkillsMod: 0.5,
          },
          ],
      },

/*      
      {
        path: '',
        id: '',
        name: '',
        note: '',
        organ: null,
        levelNotes: [
          '',
          '',
          '',
          '',
          ],
        levelParams: [
          '',
          '',
          '',
          '',
          ],
      },
*/      
    ];


// ep needed to upgrade improvement to next level (index is current level)
  public static var epCostImprovement = [ 100, 200, 500, 1000 ];
// ep needed to open new improvement on path (index is current path level)
  public static var epCostPath = [ 100, 200, 500, 1000, 2000, 5000 ];


// get improvement info
  public static function getInfo(id: String): ImprovInfo
    {
      for (imp in improvements)
        if (imp.id == id)
          return imp;

      return null;
    }


// get improvement info by organ id
  public static function getInfoByOrganID(id: String): ImprovInfo
    {
      for (imp in improvements)
        if (imp.organ != null && imp.organ.id == id)
          return imp;

      return null;
    }


// get path info
  public static function getPathInfo(id: String): PathInfo
    {
      for (p in paths)
        if (p.id == id)
          return p;

      return null;
    }
}


typedef ImprovInfo =
{
  var id: String; // improvement string ID
  var path: String; // path string ID
  var name: String; // improvement name
  var note: String; // improvement description
  var organ: OrganInfo; // organ that can be grown
  var levelNotes: Array<String>; // improvement descriptions for different levels
  var levelParams: Array<Dynamic>; // improvement-specific parameters for different levels
}

typedef PathInfo =
{
  var id: String; // path string ID
  var name: String; // path name
}


typedef OrganInfo =
{
  var id: String; // string ID
  var name: String; // name
  var note: String; // description
  var gp: Int; // gp cost to grow
}
