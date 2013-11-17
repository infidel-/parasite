// evolution constants

class EvolutionConst
{
  // major evolution paths
  public static var paths: Array<EvolutionPath> =
    [
      { id: 'protection', name: 'Protection' },
      { id: 'control', name: 'Control' },
      { id: 'attack', name: 'Attack' },
      { id: 'conceal', name: 'Concealment' },
    ];


  // improvement info
  public static var improvements: Array<ImprovInfo> =
    [
      {
        path: 'conceal',
        id: 'hostRelease',
        name: 'Host release',
        note: 'Controls what happens to the host when parasite leaves.',
        levelNotes: [
          'Host dies with its brain melting and dripping out of its ears.',
          'Host becomes crazy.',
          'Host is left intact - alive and conscious with all memory wiped.',
          'Host is left alive and conscious, and is implanted with fake memories.',
          ]
      },
      {
        path: 'conceal',
        id: 'hostAppearance',
        name: 'Host appearance',
        note: 'Controls host appearance to passers by.',
        levelNotes: [
          'Host looks and walks like a zombie with a huge purple blob on his neck, sometimes emits moans.',
          'Host looks and walks like a zombie, no huge purple blob, just some streaks here and there.',
          'Host looks and walks almost like a human, but is still a bit creepy.',
          'Parasite is either completely inside of the host body or changes its protective cover visually to look like human skin.',
          ]
      },


/*      
      {
        path: '',
        id: '',
        name: '',
        note: '',
        levelNotes: [
          '',
          ]
      },
*/      
    ];


  public static function getInfo(id: String): ImprovInfo
    {
      for (imp in improvements)
        if (imp.id == id)
          return imp;

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
}

typedef EvolutionPath =
{
  var id: String; // path string ID
  var name: String; // path name
}

