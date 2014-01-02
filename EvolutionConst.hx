// evolution constants

class EvolutionConst
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
        id: 'hostAppearance',
        name: 'Host appearance',
        note: 'Controls host appearance to passers by.',
        levelNotes: [
          'Host looks and walks like a zombie with a huge purple blob on his neck. [TODO Alertness formula]',
          'Host looks and walks like a zombie, no huge purple blob, just some streaks here and there. [TODO]',
          'Host looks and walks almost like a human, but is still a bit creepy. [TODO]',
          'Parasite is either completely inside of the host body or changes its protective cover visually to look like human skin. [TODO]',
          ],
        levelParams: []
      },

      {
        path: 'misc',
        id: 'hostMemory',
        name: 'Host memory',
        note: 'Gains access to host memory',
        levelNotes: [
          'Cannot access host brain',
          'Access with severe problems',
          'Limited access with some problems',
          'Full access',
          ],
        levelParams: [
          { 
            humanSociety: 0,
            hostTimer: 0, 
            hostHealthBase: 0,
            hostHealthMod: 0
          },
          { 
            humanSociety: 0.25, 
            hostTimer: 30, 
            hostHealthBase: 3,
            hostHealthMod: 2
          },
          { 
            humanSociety: 0.5, 
            hostTimer: 20, 
            hostHealthBase: 1,
            hostHealthMod: 1
          },
          { 
            humanSociety: 1.0, 
            hostTimer: 10, 
            hostHealthBase: 0,
            hostHealthMod: 1
          },
          ],
      },

/*      
      {
        path: '',
        id: '',
        name: '',
        note: '',
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
  var levelNotes: Array<String>; // improvement descriptions for different levels
  var levelParams: Array<Dynamic>; // improvement-specific parameters for different levels
}

typedef PathInfo =
{
  var id: String; // path string ID
  var name: String; // path name
}

