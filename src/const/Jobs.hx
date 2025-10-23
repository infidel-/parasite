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
  var isRare: Bool;
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
          type: 'callCenter',
          names: [ 'customer service rep', 'call center agent', 'support desk associate' ],
          level: 1,
          minIncome: 1800,
          maxIncome: 2300,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'callCenter',
          names: [ 'contact center supervisor', 'client support manager', 'customer experience lead' ],
          level: 2,
          minIncome: 3600,
          maxIncome: 4400,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'teacher',
          names: [ 'classroom teacher', 'school instructor', 'faculty mentor' ],
          level: 1,
          minIncome: 2600,
          maxIncome: 3200,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'teacher',
          names: [ 'department chair', 'curriculum director', 'senior educator' ],
          level: 2,
          minIncome: 4800,
          maxIncome: 6000,
          isRare: false,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'nurse',
          names: [ 'ward nurse', 'triage nurse', 'clinic nurse' ],
          level: 1,
          minIncome: 3200,
          maxIncome: 3800,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'nurse',
          names: [ 'charge nurse', 'care coordinator', 'nurse supervisor' ],
          level: 2,
          minIncome: 5400,
          maxIncome: 6800,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'doctor',
          names: [ 'clinic resident', 'ward physician', 'medical internist' ],
          level: 1,
          minIncome: 7800,
          maxIncome: 9200,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'doctor',
          names: [ 'chief surgeon', 'hospitalist', 'medical director' ],
          level: 2,
          minIncome: 13500,
          maxIncome: 16500,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'worker',
          names: [ 'construction laborer', 'factory hand', 'warehouse porter' ],
          level: 1,
          minIncome: 1600,
          maxIncome: 2100,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'worker',
          names: [ 'site foreman', 'maintenance supervisor', 'plant coordinator' ],
          level: 2,
          minIncome: 2800,
          maxIncome: 3400,
          isRare: false,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'casualCivilian',
          names: [
            'cashier',
            'fast food worker',
            'dishwasher',
            'janitor',
            'housekeeper',
            'farm worker',
            'food worker',
            'laundry worker',
            'retail salesperson',
            'waiter',
            'waitress',
            'bartender',
            'hotel clerk',
            'childcare worker',
            'home health aide',
            'personal care aide',
            'cashier',
            'stocker',
            'packer',
            'meat packer',
            'clothier',
            'telemarketer',
            'data entry clerk',
            'receptionist',
            'teacher\'s aide',
            'delivery driver',
            'gardener',
            'maid',
            'cleaner',
            'cafeteria attendant',
            'car wash attendant',
            'gas station attendant',
            'store clerk',
            'toll collector',
            'usher',
            'lifeguard',
            'barista',
            'sandwich artist',
            'grocery bagger',
            'nursery worker',
            'factory assembler',
            'warehouse worker',
            'order picker',
            'packager',
            'laborer',
          ],
          level: 1,
          minIncome: 500,
          maxIncome: 1500,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'casualCivilian',
          names: [
            'teacher',
            'nurse',
            'plumber',
            'electrician',
            'carpenter',
            'hvac technician',
            'welder',
            'machinist',
            'automotive technician',
            'dental hygienist',
            'medical sonographer',
            'radiologic technologist',
            'retail manager',
            'logistics coordinator',
            'heavy truck driver',
            'bus driver',
            'postal service worker',
            'massage therapist',
            'chef',
            'social worker',
            'quality control inspector',
            'cosmetologist',
            'fitness trainer',
            'surveyor',
            'aircraft mechanic',
            'machinery mechanic',
            'comms equipment installer',
          ],
          level: 2,
          minIncome: 2500,
          maxIncome: 3200,
          isRare: false,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'barista',
          names: [ 'coffee runner', 'espresso maker', 'cafe attendant' ],
          level: 1,
          minIncome: 1400,
          maxIncome: 1900,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'barista',
          names: [ 'lead barista', 'beverage supervisor', 'cafe manager' ],
          level: 2,
          minIncome: 2600,
          maxIncome: 3200,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'stewardess',
          names: [ 'cabin attendant', 'flight hostess', 'sky steward' ],
          level: 1,
          minIncome: 2800,
          maxIncome: 3400,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'stewardess',
          names: [ 'senior flight attendant', 'cabin supervisor', 'inflight concierge' ],
          level: 2,
          minIncome: 5200,
          maxIncome: 6600,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'housewife',
          names: [ 'community homemaker', 'house steward', 'family caretaker' ],
          level: 1,
          minIncome: 1200,
          maxIncome: 1600,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'housewife',
          names: [ 'neighborhood matron', 'household manager', 'family coordinator' ],
          level: 2,
          minIncome: 2400,
          maxIncome: 3200,
          isRare: false,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'waiter',
          names: [ 'diner server', 'table attendant', 'waitstaff' ],
          level: 1,
          minIncome: 1500,
          maxIncome: 2000,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'waiter',
          names: [ 'head server', 'shift captain', 'dining supervisor' ],
          level: 2,
          minIncome: 2600,
          maxIncome: 3200,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'supportSpecialist',
          names: [ 'help desk agent', 'technical concierge', 'service desk rep' ],
          level: 1,
          minIncome: 2100,
          maxIncome: 2700,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'supportSpecialist',
          names: [ 'support lead', 'systems support analyst', 'customer support engineer' ],
          level: 2,
          minIncome: 4200,
          maxIncome: 5200,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'nun',
          names: [ 'novice sister', 'choir nun', 'cloister attendant' ],
          level: 1,
          minIncome: 1800,
          maxIncome: 2300,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'nun',
          names: [ 'mother superior', 'abbey caretaker', 'convent director' ],
          level: 2,
          minIncome: 3200,
          maxIncome: 4200,
          isRare: false,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'student',
          names: [ 'community college student', 'night class attendee', 'academy pupil' ],
          level: 1,
          minIncome: 500,
          maxIncome: 900,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'student',
          names: [ 'graduate student', 'research assistant', 'academy fellow' ],
          level: 2,
          minIncome: 900,
          maxIncome: 1500,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'courier',
          names: [ 'bike courier', 'parcel runner', 'express messenger' ],
          level: 1,
          minIncome: 2200,
          maxIncome: 2800,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'courier',
          names: [ 'route supervisor', 'logistics dispatcher', 'fleet coordinator' ],
          level: 2,
          minIncome: 4200,
          maxIncome: 5200,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'captain',
          names: [ 'patrol captain', 'harbor skipper', 'transit pilot' ],
          level: 1,
          minIncome: 5200,
          maxIncome: 6500,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'captain',
          names: [ 'operations captain', 'fleet master', 'port commander' ],
          level: 2,
          minIncome: 9000,
          maxIncome: 11500,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'firefighter',
          names: [ 'engine operator', 'ladder specialist', 'station responder' ],
          level: 1,
          minIncome: 3200,
          maxIncome: 3900,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'firefighter',
          names: [ 'fire captain', 'incident commander', 'rescue coordinator' ],
          level: 2,
          minIncome: 5800,
          maxIncome: 7200,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'cook',
          names: [ 'line cook', 'short-order cook', 'commis chef' ],
          level: 1,
          minIncome: 1800,
          maxIncome: 2400,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'cook',
          names: [ 'head cook', 'culinary supervisor', 'executive chef' ],
          level: 2,
          minIncome: 3200,
          maxIncome: 7600,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'painter',
          names: [ 'house painter', 'wall finisher', 'decorative sprayer' ],
          level: 1,
          minIncome: 1500,
          maxIncome: 2100,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'painter',
          names: [ 'project painter', 'finish specialist', 'restoration artist' ],
          level: 2,
          minIncome: 2600,
          maxIncome: 3400,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'formalCivilian',
          names: [
            'atrium concierge',
            'ballroom usher',
            'museum docent',
            'event planner',
            'auction caller',
            'embassy greeter',
            'train steward',
            'civic volunteer',
            'opera guide',
            'heritage archivist',
            'botanical host',
            'charity runner',
            'museum guide',
            'ferry aide',
            'planetarium presenter',
            'fashion dresser',
            'auction spotter',
            'diplomatic driver',
            'club attendant',
            'lounge singer',
            'hall coordinator'
          ],
          level: 1,
          minIncome: 2000,
          maxIncome: 2800,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'formalCivilian',
          names: [ 
            'executive aide', 
            'corporate liaison', 
            'conference planner',
            'accountant',
            'admin assistant',
            'paralegal',
            'insurance agent',
            'loan officer',
            'web developer',
            'support specialist',
            'legal secretary',
            'executive assistant',
            'sales rep',
            'marketing specialist',
            'real estate broker',
            'claims adjuster',
            'bookkeeper',
            'graphic designer',
            'funeral director'
          ],
          level: 2,
          minIncome: 3600,
          maxIncome: 4500,
          isRare: false,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'preacher',
          names: [ 'youth minister', 'street preacher', 'community chaplain' ],
          level: 1,
          minIncome: 2200,
          maxIncome: 2800,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'preacher',
          names: [ 'senior pastor', 'cathedral preacher', 'civic reverend' ],
          level: 2,
          minIncome: 4600,
          maxIncome: 5800,
          isRare: false,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'hotelWorker',
          names: [ 'front desk clerk', 'bellhop', 'concierge assistant' ],
          level: 1,
          minIncome: 1800,
          maxIncome: 2400,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'hotelWorker',
          names: [ 'guest services manager', 'hospitality supervisor', 'concierge manager' ],
          level: 2,
          minIncome: 3400,
          maxIncome: 4200,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'foreman',
          names: [ 'crew foreman', 'shift lead', 'site supervisor' ],
          level: 1,
          minIncome: 2800,
          maxIncome: 3600,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'foreman',
          names: [ 'operations foreman', 'construction superintendent', 'plant foreman' ],
          level: 2,
          minIncome: 5200,
          maxIncome: 6800,
          isRare: false,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'barber',
          names: [ 'apprentice barber', 'shop stylist', 'chair clipper' ],
          level: 1,
          minIncome: 1900,
          maxIncome: 2500,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'barber',
          names: [ 'master barber', 'grooming specialist', 'barbershop lead' ],
          level: 2,
          minIncome: 3200,
          maxIncome: 4200,
          isRare: false,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'fireman',
          names: [ 'hose operator', 'brigade rookie', 'station tender' ],
          level: 1,
          minIncome: 3000,
          maxIncome: 3600,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'fireman',
          names: [ 'engine lieutenant', 'rescue captain', 'operations firefighter' ],
          level: 2,
          minIncome: 5200,
          maxIncome: 6800,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'barman',
          names: [ 'taproom server', 'pub attendant', 'draft tender' ],
          level: 1,
          minIncome: 1600,
          maxIncome: 2200,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'barman',
          names: [ 'bar steward', 'lounge barkeep', 'public house manager' ],
          level: 2,
          minIncome: 3000,
          maxIncome: 3800,
          isRare: true,
        },

        {
          group: GROUP_MEDIA,
          type: 'singer',
          names: [ 'lounge vocalist', 'club crooner', 'street busker' ],
          level: 1,
          minIncome: 2600,
          maxIncome: 3400,
          isRare: false,
        },
        {
          group: GROUP_MEDIA,
          type: 'singer',
          names: [ 'recording artist', 'concert performer', 'tour vocalist' ],
          level: 2,
          minIncome: 5200,
          maxIncome: 6600,
          isRare: false,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'bartender',
          names: [ 'tap tender', 'barback', 'cocktail mixer' ],
          level: 1,
          minIncome: 1700,
          maxIncome: 2300,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'bartender',
          names: [ 'mixologist', 'bar manager', 'club barkeep' ],
          level: 2,
          minIncome: 3200,
          maxIncome: 4000,
          isRare: true,
        },

        {
          group: GROUP_CORPORATE,
          type: 'hacker',
          names: [ 'penetration tester', 'junior codebreaker', 'security analyst' ],
          level: 1,
          minIncome: 5200,
          maxIncome: 6800,
          isRare: false,
        },
        {
          group: GROUP_CORPORATE,
          type: 'hacker',
          names: [ 'red team lead', 'cyber intrusion expert', 'black ice engineer' ],
          level: 2,
          minIncome: 9000,
          maxIncome: 12000,
          isRare: false,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'scientist',
          names: [ 'lab technician', 'research assistant', 'specimen handler' ],
          level: 1,
          minIncome: 3200,
          maxIncome: 3800,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'scientist',
          names: [ 'research scientist', 'principal investigator', 'systems researcher' ],
          level: 2,
          minIncome: 7200,
          maxIncome: 8500,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'scientist',
          names: [ 'institute director', 'chief scientist', 'research chair' ],
          level: 3,
          minIncome: 50000,
          maxIncome: 65000,
          isRare: false,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'prostitute',
          names: [ 'street worker', 'corner hustler', 'nightwalker' ],
          level: 1,
          minIncome: 900,
          maxIncome: 1200,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'prostitute',
          names: [ 'independent escort', 'courtesan', 'private companion' ],
          level: 2,
          minIncome: 2600,
          maxIncome: 3200,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'prostitute',
          names: [ 'club proprietor', 'club matriarch', 'velvet room owner' ],
          level: 3,
          minIncome: 16000,
          maxIncome: 20000,
          isRare: false,
        },

        {
          group: GROUP_MEDIA,
          type: 'civilian',
          names: [ 'journalist', 'field reporter', 'news stringer' ],
          level: 1,
          minIncome: 2800,
          maxIncome: 3500,
          isRare: false,
        },
        {
          group: GROUP_MEDIA,
          type: 'civilian',
          names: [ 'public relations manager', 'social media strategist', 'medium influencer' ],
          level: 2,
          minIncome: 6500,
          maxIncome: 7800,
          isRare: false,
        },
        {
          group: GROUP_MEDIA,
          type: 'civilian',
          names: [ 'news anchor', 'top influencer', 'network personality' ],
          level: 3,
          minIncome: 42000,
          maxIncome: 52000,
          isRare: false,
        },

        {
          group: GROUP_CORPORATE,
          type: 'corpo',
          names: [ 'office clerk', 'data entry specialist', 'customer service agent' ],
          level: 1,
          minIncome: 2600,
          maxIncome: 3200,
          isRare: false,
        },
        {
          group: GROUP_CORPORATE,
          type: 'corpo',
          names: [ 'sales manager', 'product manager', 'human resources manager' ],
          level: 2,
          minIncome: 9000,
          maxIncome: 11000,
          isRare: false,
        },
        {
          group: GROUP_CORPORATE,
          type: 'corpo',
          names: [ 'marketing director', 'business analyst lead', 'corporate strategist' ],
          level: 3,
          minIncome: 60000,
          maxIncome: 80000,
          isRare: false,
        },

        {
          group: GROUP_CORPORATE,
          type: 'smiler',
          names: [ 'public relations associate', 'social media manager', 'audience curator' ],
          level: 1,
          minIncome: 3000,
          maxIncome: 3600,
          isRare: false,
        },
        {
          group: GROUP_CORPORATE,
          type: 'smiler',
          names: [ 'brand storyteller', 'engagement architect', 'activation planner' ],
          level: 2,
          minIncome: 7600,
          maxIncome: 9000,
          isRare: false,
        },
        {
          group: GROUP_CORPORATE,
          type: 'smiler',
          names: [ 'campaign visionary', 'broadcast icon', 'global spokesperson' ],
          level: 3,
          minIncome: 52000,
          maxIncome: 68000,
          isRare: false,
        },

        {
          group: GROUP_LAWFARE,
          type: 'civilian',
          names: [ 'court clerk', 'legal assistant', 'docket coordinator' ],
          level: 1,
          minIncome: 3200,
          maxIncome: 3800,
          isRare: false,
        },
        {
          group: GROUP_LAWFARE,
          type: 'civilian',
          names: [ 'attorney', 'prosecutor', 'litigation counsel' ],
          level: 2,
          minIncome: 9000,
          maxIncome: 12000,
          isRare: false,
        },
        {
          group: GROUP_LAWFARE,
          type: 'civilian',
          names: [ 'judge', 'chief prosecutor', 'circuit justice' ],
          level: 3,
          minIncome: 60000,
          maxIncome: 82000,
          isRare: false,
        },

        {
          group: GROUP_POLITICAL,
          type: 'civilian',
          names: [ 'public servant', 'bureaucrat', 'constituency aide' ],
          level: 1,
          minIncome: 2400,
          maxIncome: 3200,
          isRare: false,
        },
        {
          group: GROUP_POLITICAL,
          type: 'civilian',
          names: [ 'lobbyist', 'councilor', 'policy advocate' ],
          level: 2,
          minIncome: 7000,
          maxIncome: 9000,
          isRare: false,
        },
        {
          group: GROUP_POLITICAL,
          type: 'civilian',
          names: [ 'politician', 'representative', 'cabinet powerbroker' ],
          level: 3,
          minIncome: 50000,
          maxIncome: 65000,
          isRare: false,
        },

        {
          group: GROUP_COMBAT,
          type: 'police',
          names: [ 'beat cop', 'patrol officer', 'street sergeant' ],
          level: 1,
          minIncome: 3000,
          maxIncome: 3500,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'police',
          names: [ 'detective', 'investigations officer', 'case analyst' ],
          level: 2,
          minIncome: 6000,
          maxIncome: 7000,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'police',
          names: [ 'police chief', 'commissioner', 'public safety director' ],
          level: 3,
          minIncome: 40000,
          maxIncome: 45000,
          isRare: false,
        },

        {
          group: GROUP_COMBAT,
          type: 'security',
          names: [ 'mall guard', 'patrol guard', 'floor sentry' ],
          level: 1,
          minIncome: 1800,
          maxIncome: 2300,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'security',
          names: [ 'security supervisor', 'shift commander', 'watch captain' ],
          level: 2,
          minIncome: 3600,
          maxIncome: 4200,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'security',
          names: [ 'corporate security director', 'director of protection', 'security strategist' ],
          level: 3,
          minIncome: 20000,
          maxIncome: 26000,
          isRare: false,
        },

        {
          group: GROUP_COMBAT,
          type: 'agent',
          names: [ 'field observer', 'case scout', 'liaison operative' ],
          level: 1,
          minIncome: 4800,
          maxIncome: 5400,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'agent',
          names: [ 'case officer', 'handler', 'ops coordinator' ],
          level: 2,
          minIncome: 9200,
          maxIncome: 11000,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'agent',
          names: [ 'station chief', 'regional controller', 'intelligence director' ],
          level: 3,
          minIncome: 70000,
          maxIncome: 90000,
          isRare: false,
        },

        {
          group: GROUP_COMBAT,
          type: 'thug',
          names: [ 'gang member', 'street enforcer', 'corner muscle' ],
          level: 1,
          minIncome: 800,
          maxIncome: 1200,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'thug',
          names: [ 'gang lieutenant', 'crew captain', 'operations lieutenant' ],
          level: 2,
          minIncome: 2000,
          maxIncome: 2600,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'thug',
          names: [ 'gang boss', 'crime lord', 'block kingpin' ],
          level: 3,
          minIncome: 15000,
          maxIncome: 20000,
          isRare: false,
        },

        {
          group: GROUP_COMBAT,
          type: 'soldier',
          names: [ 'infantry trooper', 'line rifleman', 'field specialist' ],
          level: 1,
          minIncome: 2800,
          maxIncome: 3200,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'soldier',
          names: [ 'platoon sergeant', 'unit leader', 'operations sergeant' ],
          level: 2,
          minIncome: 4500,
          maxIncome: 5200,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'soldier',
          names: [ 'battalion commander', 'field commander', 'operations colonel' ],
          level: 3,
          minIncome: 28000,
          maxIncome: 34000,
          isRare: false,
        },

        {
          group: GROUP_COMBAT,
          type: 'blackops',
          names: [ 'covert operator', 'shadow operative', 'clandestine agent' ],
          level: 1,
          minIncome: 6200,
          maxIncome: 7000,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'blackops',
          names: [ 'strike leader', 'mission commander', 'assault lead' ],
          level: 2,
          minIncome: 12000,
          maxIncome: 15000,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'blackops',
          names: [ 'mission architect', 'strategic mastermind', 'black budget director' ],
          level: 3,
          minIncome: 90000,
          maxIncome: 120000,
          isRare: false,
        },
      ];

      for (info in infos)
        {
          // mark rare civilian jobs (default: rare), except a few common types
          if (info.group == GROUP_CIVILIAN)
            {
              var common = info.type == 'formalCivilian' ||
                info.type == 'casualCivilian' ||
                info.type == 'prostitute' ||
                info.type == 'scientist';
              info.isRare = !common;
            }
          else info.isRare = false;

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
  public function getRandom(type: String): { name: String, income: Int, isRare: Bool }
    {
      var infos = jobsByType.get(type);
      if (infos == null || infos.length == 0)
        return { name: 'unemployed', income: 0, isRare: false };

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

      return { name: pickedName, income: income, isRare: picked.isRare };
    }
}
