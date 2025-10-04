// all ingame images access
import js.html.Image;

class Images
{
  var scene: GameScene;
  public var entities: Image;
  public var male: Image;
  public var female: Image;
  public var tileset: Image;
  public var cursors: Array<Image>;

  public function new(s: GameScene)
    {
      scene = s;

      // load all images
      entities = new Image();
      entities.src = 'img/entities64.png';
      male = new Image();
      male.src = 'img/male64.png';
      female = new Image();
      female.src = 'img/female64.png';
      tileset = new Image();
      tileset.src = 'img/tileset64.png';

      // load mouse cursors
      cursors = [];
      for (i in 0...5)
        {
          var img = new Image();
          img.src = 'img/mouse' + i + '.png';
          cursors.push(img);
        }
      }

// get AI graphics with given params
  public function getAI(type: String, isMale: Bool): {
      x: Int,
      y: Int,
    }
    {
      var specials = (isMale ? specialsMale : specialsFemale);
      // generic civilian
      if (type == 'civilian')
        {
          // male64.png, female64.png civilians part
          // NOTE: here
          var w = 10, h = (isMale ? 8 : 6);
          for (_ in 0...100)
            {
              var x = Std.random(w);
              var y = Std.random(h);
              // check for hitting specials
              var ok = true;
              for (_ => arr in specials)
                {
                  for (tmp in arr)
                    if (tmp.x == x && tmp.y == y)
                      {
                        ok = false;
                        break;
                      }
                  if (!ok)
                    break;
                }
              if (!ok)
                continue;
              return {
                x: x,
                y: y,
              }
            }
          trace('could not find icon for ' + type + ' ' + isMale);
          return null;
        }

      // special humans - police, soldier, agent, blackops, security
      else
        {
          var list = specials[type];
          // might only be in male atlas (security, etc)
          if (!isMale && list == null)
            list = specialsMale[type];
          if (list == null)
            {
              trace('no icons for type ' + type);
              return null;
            }
          var tmp = list[Std.random(list.length)];
          return {
            x: tmp.x,
            y: tmp.y,
          }
        }
      return null;
    }

  public static var specialsFemale = [
    'agent' => [
      { x: 8, y: 0 },
    ],
    'blackops' => [
      { x: 2, y: 6 },
      { x: 3, y: 6 },
      { x: 4, y: 6 },
      { x: 5, y: 6 },
      { x: 6, y: 6 },
      { x: 7, y: 6 },
      { x: 8, y: 6 },
      { x: 9, y: 6 },
    ],
    'bum' => [
      { x: 5, y: 7 },
      { x: 6, y: 7 },
      { x: 7, y: 7 },
    ],
    'corpo' => [
      { x: 0, y: 8 },
      { x: 1, y: 8 },
      { x: 2, y: 8 },
      { x: 3, y: 8 },
      { x: 4, y: 8 },
      { x: 5, y: 8 },
      { x: 6, y: 8 },
      { x: 7, y: 8 },
    ],
    'police' => [
      { x: 0, y: 6 },
      { x: 1, y: 6 },
    ],
    'prostitute' => [
      { x: 7, y: 10 },
      { x: 8, y: 10 },
      { x: 9, y: 10 },
    ],
    'scientist' => [
      { x: 0, y: 7 },
      { x: 1, y: 7 },
      { x: 2, y: 7 },
      { x: 3, y: 7 },
      { x: 4, y: 7 },
    ],
    'smiler' => [
      { x: 0, y: 9 },
      { x: 1, y: 9 },
      { x: 2, y: 9 },
      { x: 3, y: 9 },
      { x: 4, y: 9 },
      { x: 5, y: 9 },
      { x: 6, y: 9 },
      { x: 7, y: 9 },
    ],
    'thug' => [
      { x: 0, y: 10 },
      { x: 1, y: 10 },
      { x: 2, y: 10 },
      { x: 3, y: 10 },
      { x: 4, y: 10 },
      { x: 5, y: 10 },
      { x: 6, y: 10 },
    ],
    // NOTE: check start of file for empty tiles code on new row!
  ];

  public static var specialsMale = [
    'agent' => [
      { x: 8, y: 1 },
    ],
    'blackops' => [
      { x: 3, y: 8 },
      { x: 4, y: 8 },
      { x: 5, y: 8 },
      { x: 6, y: 8 },
      { x: 7, y: 8 },
      { x: 8, y: 8 },
      { x: 9, y: 8 },
      { x: 0, y: 9 },
      { x: 1, y: 9 },
    ],
    'blackops-heavy' => [
      { x: 0, y: 8 },
      { x: 2, y: 8 },
    ],
    'bum' => [
      { x: 1, y: 13 },
      { x: 2, y: 13 },
      { x: 3, y: 13 },
      { x: 4, y: 13 },
      { x: 5, y: 13 },
      { x: 6, y: 13 },
    ],
    'corpo' => [
      { x: 0, y: 10 },
      { x: 1, y: 10 },
      { x: 2, y: 10 },
      { x: 3, y: 10 },
      { x: 4, y: 10 },
      { x: 5, y: 10 },
      { x: 6, y: 10 },
      { x: 7, y: 10 },
    ],
    'police' => [
      { x: 9, y: 2 },
      { x: 1, y: 4 },
      { x: 4, y: 7 },
    ],
    'scientist' => [
      { x: 2, y: 9 },
      { x: 3, y: 9 },
      { x: 4, y: 9 },
      { x: 5, y: 9 },
      { x: 6, y: 9 },
    ],
    'security' => [
      { x: 1, y: 8 },
    ],
    'smiler' => [
      { x: 8, y: 9 },
      { x: 9, y: 9 },
      { x: 8, y: 10 },
      { x: 9, y: 10 },
    ],
    'soldier' => [
      { x: 8, y: 7 },
    ],
    'thug' => [
      { x: 0, y: 11 },
      { x: 1, y: 11 },
      { x: 2, y: 11 },
      { x: 3, y: 11 },
      { x: 4, y: 11 },
      { x: 5, y: 11 },
      { x: 6, y: 11 },
      { x: 7, y: 11 },
      { x: 8, y: 11 },
      { x: 9, y: 11 },

      { x: 0, y: 12 },
      { x: 1, y: 12 },
      { x: 2, y: 12 },
      { x: 3, y: 12 },
      { x: 4, y: 12 },
      { x: 5, y: 12 },
      { x: 6, y: 12 },
      { x: 7, y: 12 },
      { x: 8, y: 12 },
      { x: 9, y: 12 },

      { x: 0, y: 13 },

      { x: 0, y: 14 },
      { x: 1, y: 14 },
      { x: 2, y: 14 },
      { x: 3, y: 14 },
      { x: 4, y: 14 },
      { x: 5, y: 14 },
      { x: 6, y: 14 },
      { x: 7, y: 14 },
    ],
    'prostitute' => [
      { x: 8, y: 14 },
      { x: 9, y: 14 },
    ],

    // NOTE: check start of file for empty tiles code on new row!
  ];
}

