// job data and utilities
package const;

import game.Game;
import _AIJobGroup;

typedef _JobInfo = {
  var group: _AIJobGroup;
  var type: String;
  var names: Array<String>;
  var level: Int;
  var minIncome: Int;
  var maxIncome: Int;
};

class Jobs
{
  var game: Game;
  var jobsByType: Map<String, Array<_JobInfo>>;

  // sets up jobs helper with game reference
  public function new(g: Game)
    {
      game = g;
      jobsByType = new Map<String, Array<_JobInfo>>();
      initJobTable();
    }

  // builds lookup table for job infos
  function initJobTable()
    {
      // job definitions for human ai types
      var infos: Array<_JobInfo> = [
        {
          group: GROUP_CIVILIAN,
          type: 'civilian',
          names: [ 'service clerk', 'retail associate', 'customer liaison' ],
          level: 1,
          minIncome: 1200,
          maxIncome: 1500,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'civilian',
          names: [ 'district supervisor', 'municipal coordinator', 'ward manager' ],
          level: 2,
          minIncome: 3200,
          maxIncome: 4000,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'civilian',
          names: [ 'metropolitan director', 'city executive', 'urban prefect' ],
          level: 3,
          minIncome: 20000,
          maxIncome: 24000,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'corpo',
          names: [ 'junior analyst', 'compliance associate', 'risk trainee' ],
          level: 1,
          minIncome: 3800,
          maxIncome: 4400,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'corpo',
          names: [ 'portfolio manager', 'investment director', 'venture steward' ],
          level: 2,
          minIncome: 9500,
          maxIncome: 11000,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'corpo',
          names: [ 'chief strategy officer', 'corporate futurist', 'executive visionary' ],
          level: 3,
          minIncome: 60000,
          maxIncome: 80000,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'scientist',
          names: [ 'lab technician', 'research assistant', 'specimen handler' ],
          level: 1,
          minIncome: 3200,
          maxIncome: 3800,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'scientist',
          names: [ 'research scientist', 'principal investigator', 'systems researcher' ],
          level: 2,
          minIncome: 7200,
          maxIncome: 8500,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'scientist',
          names: [ 'institute director', 'chief scientist', 'research chair' ],
          level: 3,
          minIncome: 50000,
          maxIncome: 65000,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'prostitute',
          names: [ 'street worker', 'corner hustler', 'nightwalker' ],
          level: 1,
          minIncome: 900,
          maxIncome: 1200,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'prostitute',
          names: [ 'independent escort', 'courtesan', 'private companion' ],
          level: 2,
          minIncome: 2600,
          maxIncome: 3200,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'prostitute',
          names: [ 'club proprietor', 'club matriarch', 'velvet room owner' ],
          level: 3,
          minIncome: 16000,
          maxIncome: 20000,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'smiler',
          names: [ 'culture evangelist', 'brand apostle', 'mood curator' ],
          level: 1,
          minIncome: 4000,
          maxIncome: 5000,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'smiler',
          names: [ 'alignment consultant', 'synergy coach', 'paradigm facilitator' ],
          level: 2,
          minIncome: 9000,
          maxIncome: 12000,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'smiler',
          names: [ 'synergy visionary', 'corporate oracle', 'alignment prophet' ],
          level: 3,
          minIncome: 60000,
          maxIncome: 80000,
        },

        {
          group: GROUP_COMBAT,
          type: 'police',
          names: [ 'beat cop', 'patrol officer', 'street sergeant' ],
          level: 1,
          minIncome: 3000,
          maxIncome: 3500,
        },
        {
          group: GROUP_COMBAT,
          type: 'police',
          names: [ 'detective', 'investigations officer', 'case analyst' ],
          level: 2,
          minIncome: 6000,
          maxIncome: 7000,
        },
        {
          group: GROUP_COMBAT,
          type: 'police',
          names: [ 'police chief', 'commissioner', 'public safety director' ],
          level: 3,
          minIncome: 40000,
          maxIncome: 45000,
        },

        {
          group: GROUP_COMBAT,
          type: 'security',
          names: [ 'mall guard', 'patrol guard', 'floor sentry' ],
          level: 1,
          minIncome: 1800,
          maxIncome: 2300,
        },
        {
          group: GROUP_COMBAT,
          type: 'security',
          names: [ 'security supervisor', 'shift commander', 'watch captain' ],
          level: 2,
          minIncome: 3600,
          maxIncome: 4200,
        },
        {
          group: GROUP_COMBAT,
          type: 'security',
          names: [ 'corporate security director', 'director of protection', 'security strategist' ],
          level: 3,
          minIncome: 20000,
          maxIncome: 26000,
        },

        {
          group: GROUP_COMBAT,
          type: 'agent',
          names: [ 'field observer', 'case scout', 'liaison operative' ],
          level: 1,
          minIncome: 4800,
          maxIncome: 5400,
        },
        {
          group: GROUP_COMBAT,
          type: 'agent',
          names: [ 'case officer', 'handler', 'ops coordinator' ],
          level: 2,
          minIncome: 9200,
          maxIncome: 11000,
        },
        {
          group: GROUP_COMBAT,
          type: 'agent',
          names: [ 'station chief', 'regional controller', 'intelligence director' ],
          level: 3,
          minIncome: 70000,
          maxIncome: 90000,
        },

        {
          group: GROUP_COMBAT,
          type: 'thug',
          names: [ 'gang member', 'street enforcer', 'corner muscle' ],
          level: 1,
          minIncome: 800,
          maxIncome: 1200,
        },
        {
          group: GROUP_COMBAT,
          type: 'thug',
          names: [ 'gang lieutenant', 'crew captain', 'operations lieutenant' ],
          level: 2,
          minIncome: 2000,
          maxIncome: 2600,
        },
        {
          group: GROUP_COMBAT,
          type: 'thug',
          names: [ 'gang boss', 'crime lord', 'block kingpin' ],
          level: 3,
          minIncome: 15000,
          maxIncome: 20000,
        },

        {
          group: GROUP_COMBAT,
          type: 'soldier',
          names: [ 'infantry trooper', 'line rifleman', 'field specialist' ],
          level: 1,
          minIncome: 2800,
          maxIncome: 3200,
        },
        {
          group: GROUP_COMBAT,
          type: 'soldier',
          names: [ 'platoon sergeant', 'unit leader', 'operations sergeant' ],
          level: 2,
          minIncome: 4500,
          maxIncome: 5200,
        },
        {
          group: GROUP_COMBAT,
          type: 'soldier',
          names: [ 'battalion commander', 'field commander', 'operations colonel' ],
          level: 3,
          minIncome: 28000,
          maxIncome: 34000,
        },

        {
          group: GROUP_COMBAT,
          type: 'blackops',
          names: [ 'covert operator', 'shadow operative', 'clandestine agent' ],
          level: 1,
          minIncome: 6200,
          maxIncome: 7000,
        },
        {
          group: GROUP_COMBAT,
          type: 'blackops',
          names: [ 'strike leader', 'mission commander', 'assault lead' ],
          level: 2,
          minIncome: 12000,
          maxIncome: 15000,
        },
        {
          group: GROUP_COMBAT,
          type: 'blackops',
          names: [ 'mission architect', 'strategic mastermind', 'black budget director' ],
          level: 3,
          minIncome: 90000,
          maxIncome: 120000,
        },
      ];

      for (info in infos)
        {
          var list = jobsByType.get(info.type);
          if (list == null)
            {
              list = [];
              jobsByType.set(info.type, list);
            }
          list.push(info);
        }
    }

  // returns random job info for the provided type
  public function getRandom(type: String): { name: String, income: Int }
    {
      var infos = jobsByType.get(type);
      if (infos == null || infos.length == 0)
        return { name: 'unemployed', income: 0 };

      var level1: Array<_JobInfo> = [];
      var level2: Array<_JobInfo> = [];
      var level3: Array<_JobInfo> = [];
      for (info in infos)
        {
          switch (info.level)
            {
              case 1:
                level1.push(info);
              case 2:
                level2.push(info);
              case 3:
                level3.push(info);
              default:
            }
        }

      var pool: Array<_JobInfo> = level1;
      if (level2.length > 0 && Std.random(100) < 10)
        pool = level2;

      if (pool.length == 0)
        pool = infos;

      var picked = pool[Std.random(pool.length)];
      var pickedName = picked.names[Std.random(picked.names.length)];
      var income = picked.minIncome;
      if (picked.maxIncome > picked.minIncome)
        income += Std.random(picked.maxIncome - picked.minIncome + 1);
      income = Std.int(income / 100) * 100;

      return { name: pickedName, income: income };
    }
}
