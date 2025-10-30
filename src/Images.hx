// all ingame images access
import const.Jobs._JobInfo;
import js.html.Image;

typedef _CivilianData = {
  x: Int,
  y: Int,
  job: String,
  income: Int,
  isMale: Bool,
  jobInfo: _JobInfo,
};

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

// get random civilian sprite data together with job info
  public function getRandomCivilianAI(isMale: Bool): _CivilianData
    {
      var civilians = (isMale ? civiliansMale : civiliansFemale);
      if (civilians.length == 0)
        {
          trace('no civilian icons available');
          return {
            x: 0,
            y: 0,
            job: 'unemployed',
            income: 0,
            isMale: isMale,
            jobInfo: null,
          };
        }
      var civ = civilians[Std.random(civilians.length)];
      var jobData = scene.game.jobs.getRandom(civ.job);
      // if the picked job is marked rare, there is only a 20% chance to keep it
      // otherwise pick again
      if (jobData.isRare)
        {
          if (Std.random(100) >= 20)
            jobData = scene.game.jobs.getRandom(civ.job);
        }
      return {
        x: civ.x,
        y: civ.y,
        job: jobData.name,
        income: jobData.income,
        isMale: isMale,
        jobInfo: jobData.jobInfo,
      };
    }

// get civilian sprite data for specific job type
  public function getCivilianAI(type: String, isMale: Bool): _CivilianData
    {
      var civilians = (isMale ? civiliansMale : civiliansFemale);
      // collect all civilians with matching job type
      var matching = [];
      for (civ in civilians)
        {
          if (civ.job == type)
            matching.push(civ);
        }
      
      if (matching.length == 0)
        return null;
      
      // pick random from matching records
      var civ = matching[Std.random(matching.length)];
      var jobData = scene.game.jobs.getRandom(type);
      return {
        x: civ.x,
        y: civ.y,
        job: jobData.name,
        income: jobData.income,
        isMale: isMale,
        jobInfo: jobData.jobInfo,
      };
    }

// get formal civilian sprite data for specific job type
// NOTE: used in recruit follower ordeal, level limited
  public function getFormalCivilianAI(type: String, isMale: Bool): _CivilianData
    {
      var civilians = (isMale ? civiliansMale : civiliansFemale);
      // collect all formalCivilian icons
      var formalCivilians = [];
      for (civ in civilians)
        {
          if (civ.job == 'formalCivilian')
            formalCivilians.push(civ);
        }
      
      if (formalCivilians.length == 0)
        return null;
      
      // pick random formalCivilian icon
      var civ = formalCivilians[Std.random(formalCivilians.length)];
      
      var jobData = scene.game.jobs.getRandomByGroup(type);
      return {
        x: civ.x,
        y: civ.y,
        job: jobData.name,
        income: jobData.income,
        isMale: isMale,
        jobInfo: jobData.jobInfo,
      };
    }

// get special human sprite for provided type
  public function getSpecialAI(type: String, isMale: Bool): {
      x: Int,
      y: Int,
    }
    {
      var specials = (isMale ? specialsMale : specialsFemale);
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
      };
    }

  public static var civiliansFemale = [
    { x: 0, y: 0, job: 'teacher' },
    { x: 1, y: 0, job: 'nurse' },
    { x: 2, y: 0, job: 'casualCivilian' },
    { x: 3, y: 0, job: 'casualCivilian' },
    { x: 4, y: 0, job: 'casualCivilian' },
    { x: 5, y: 0, job: 'formalCivilian' },
    { x: 6, y: 0, job: 'casualCivilian' },
    { x: 7, y: 0, job: 'casualCivilian' },
    { x: 8, y: 0, job: 'formalCivilian' },
    { x: 9, y: 0, job: 'callCenter' },

    { x: 0, y: 1, job: 'casualCivilian' },
    { x: 1, y: 1, job: 'casualCivilian' },
    { x: 2, y: 1, job: 'nurse' },
    { x: 3, y: 1, job: 'barista' },
    { x: 4, y: 1, job: 'casualCivilian' },
    { x: 5, y: 1, job: 'casualCivilian' },
    { x: 6, y: 1, job: 'teacher' },
    { x: 7, y: 1, job: 'casualCivilian' },
    { x: 8, y: 1, job: 'stewardess' },
    { x: 9, y: 1, job: 'casualCivilian' },

    { x: 0, y: 2, job: 'formalCivilian' },
    { x: 1, y: 2, job: 'housewife' },
    { x: 2, y: 2, job: 'waiter' },
    { x: 3, y: 2, job: 'formalCivilian' },
    { x: 4, y: 2, job: 'supportSpecialist' },
    { x: 5, y: 2, job: 'stewardess' },
    { x: 6, y: 2, job: 'nurse' },
    { x: 7, y: 2, job: 'casualCivilian' },
    { x: 8, y: 2, job: 'housewife' },
    { x: 9, y: 2, job: 'casualCivilian' },

    { x: 0, y: 3, job: 'formalCivilian' },
    { x: 1, y: 3, job: 'nurse' },
    { x: 2, y: 3, job: 'nurse' },
    { x: 3, y: 3, job: 'nun' },
    { x: 4, y: 3, job: 'callCenter' },
    { x: 5, y: 3, job: 'formalCivilian' },
    { x: 6, y: 3, job: 'casualCivilian' },
    { x: 7, y: 3, job: 'casualCivilian' },
    { x: 8, y: 3, job: 'casualCivilian' },
    { x: 9, y: 3, job: 'formalCivilian' },

    { x: 0, y: 4, job: 'casualCivilian' },
    { x: 1, y: 4, job: 'casualCivilian' },
    { x: 2, y: 4, job: 'formalCivilian' },
    { x: 3, y: 4, job: 'casualCivilian' },
    { x: 4, y: 4, job: 'casualCivilian' },
    { x: 5, y: 4, job: 'casualCivilian' },
    { x: 6, y: 4, job: 'casualCivilian' },
    { x: 7, y: 4, job: 'casualCivilian' },
    { x: 8, y: 4, job: 'casualCivilian' },
    { x: 9, y: 4, job: 'doctor' },

    { x: 0, y: 5, job: 'casualCivilian' },
    { x: 1, y: 5, job: 'casualCivilian' },
    { x: 2, y: 5, job: 'formalCivilian' },
    { x: 3, y: 5, job: 'formalCivilian' },
    { x: 4, y: 5, job: 'casualCivilian' },
    { x: 5, y: 5, job: 'formalCivilian' },
    { x: 6, y: 5, job: 'student' },
    { x: 7, y: 5, job: 'casualCivilian' },
    { x: 8, y: 5, job: 'callCenter' },
    { x: 9, y: 5, job: 'nurse' },
  ];

  public static var civiliansMale = [
    { x: 0, y: 0, job: 'callCenter' },
    { x: 1, y: 0, job: 'doctor' },
    { x: 2, y: 0, job: 'worker' },
    { x: 3, y: 0, job: 'casualCivilian' },
    { x: 4, y: 0, job: 'courier' },
    { x: 5, y: 0, job: 'captain' },
    { x: 6, y: 0, job: 'fireman' },
    { x: 7, y: 0, job: 'cook' },
    { x: 8, y: 0, job: 'casualCivilian' },
    { x: 9, y: 0, job: 'painter' },

    { x: 0, y: 1, job: 'formalCivilian' },
    { x: 1, y: 1, job: 'formalCivilian' },
    { x: 2, y: 1, job: 'formalCivilian' },
    { x: 3, y: 1, job: 'casualCivilian' },
    { x: 4, y: 1, job: 'formalCivilian' },
    { x: 5, y: 1, job: 'casualCivilian' },
    { x: 6, y: 1, job: 'preacher' },
    { x: 7, y: 1, job: 'formalCivilian' },
    { x: 9, y: 1, job: 'bartender' },

    { x: 0, y: 2, job: 'formalCivilian' },
    { x: 1, y: 2, job: 'worker' },
    { x: 2, y: 2, job: 'formalCivilian' },
    { x: 3, y: 2, job: 'casualCivilian' },
    { x: 4, y: 2, job: 'formalCivilian' },
    { x: 5, y: 2, job: 'singer' },
    { x: 6, y: 2, job: 'formalCivilian' },
    { x: 7, y: 2, job: 'formalCivilian' },
    { x: 8, y: 2, job: 'hacker' },

    { x: 0, y: 3, job: 'worker' },
    { x: 1, y: 3, job: 'preacher' },
    { x: 2, y: 3, job: 'formalCivilian' },
    { x: 3, y: 3, job: 'cook' },
    { x: 4, y: 3, job: 'doctor' },
    { x: 5, y: 3, job: 'fireman' },
    { x: 6, y: 3, job: 'casualCivilian' },
    { x: 7, y: 3, job: 'preacher' },
    { x: 8, y: 3, job: 'captain' },
    { x: 9, y: 3, job: 'callCenter' },

    { x: 0, y: 4, job: 'casualCivilian' },
    { x: 2, y: 4, job: 'hotelWorker' },
    { x: 3, y: 4, job: 'formalCivilian' },
    { x: 4, y: 4, job: 'foreman' },
    { x: 5, y: 4, job: 'formalCivilian' },
    { x: 6, y: 4, job: 'worker' },
    { x: 7, y: 4, job: 'hacker' },
    { x: 8, y: 4, job: 'hotelWorker' },
    { x: 9, y: 4, job: 'fireman' },

    { x: 0, y: 5, job: 'formalCivilian' },
    { x: 1, y: 5, job: 'captain' },
    { x: 2, y: 5, job: 'casualCivilian' },
    { x: 3, y: 5, job: 'formalCivilian' },
    { x: 4, y: 5, job: 'casualCivilian' },
    { x: 5, y: 5, job: 'casualCivilian' },
    { x: 6, y: 5, job: 'doctor' },
    { x: 7, y: 5, job: 'formalCivilian' },
    { x: 8, y: 5, job: 'formalCivilian' },
    { x: 9, y: 5, job: 'formalCivilian' },

    { x: 0, y: 6, job: 'formalCivilian' },
    { x: 1, y: 6, job: 'formalCivilian' },
    { x: 2, y: 6, job: 'casualCivilian' },
    { x: 3, y: 6, job: 'barber' },
    { x: 4, y: 6, job: 'casualCivilian' },
    { x: 5, y: 6, job: 'casualCivilian' },
    { x: 6, y: 6, job: 'fireman' },
    { x: 7, y: 6, job: 'formalCivilian' },
    { x: 8, y: 6, job: 'captain' },
    { x: 9, y: 6, job: 'worker' },

    { x: 0, y: 7, job: 'formalCivilian' },
    { x: 2, y: 7, job: 'fireman' },
    { x: 3, y: 7, job: 'cook' },
    { x: 5, y: 7, job: 'barman' },
    { x: 6, y: 7, job: 'hotelWorker' },
    { x: 7, y: 7, job: 'formalCivilian' },
    { x: 9, y: 7, job: 'foreman' },
  ];

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
