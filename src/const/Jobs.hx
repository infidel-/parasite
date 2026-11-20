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
  @:optional var init: Game -> ai.AI -> Void;
};

class Jobs
{
  var game: Game;
  var jobsByType: Map<String, Array<_JobInfo>>;
  var jobsByName: Map<String, _JobInfo>;
  var jobsByGroup: Map<_AIJobGroup, Array<_JobInfo>>;

  // sets up jobs helper with game reference
  public function new(g: Game)
    {
      game = g;
      jobsByType = new Map<String, Array<_JobInfo>>();
      jobsByName = new Map<String, _JobInfo>();
      jobsByGroup = new Map<_AIJobGroup, Array<_JobInfo>>();
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
          names: [ N('customer service rep'), N('call center agent'), N('support desk associate') ],
          level: 1,
          minIncome: 1800,
          maxIncome: 2300,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'callCenter',
          names: [ N('contact center supervisor'), N('client support manager'), N('customer experience lead') ],
          level: 2,
          minIncome: 3600,
          maxIncome: 4400,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'teacher',
          names: [ N('classroom teacher'), N('school instructor'), N('faculty mentor') ],
          level: 1,
          minIncome: 2600,
          maxIncome: 3200,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'teacher',
          names: [ N('department chair'), N('curriculum director'), N('senior educator') ],
          level: 2,
          minIncome: 4800,
          maxIncome: 6000,
          isRare: false,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'nurse',
          names: [ N('ward nurse'), N('triage nurse'), N('clinic nurse') ],
          level: 1,
          minIncome: 3200,
          maxIncome: 3800,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'nurse',
          names: [ N('charge nurse'), N('care coordinator'), N('nurse supervisor') ],
          level: 2,
          minIncome: 5400,
          maxIncome: 6800,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'doctor',
          names: [ N('clinic resident'), N('ward physician'), N('medical internist') ],
          level: 1,
          minIncome: 7800,
          maxIncome: 9200,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'doctor',
          names: [ N('chief surgeon'), N('hospitalist'), N('medical director') ],
          level: 2,
          minIncome: 13500,
          maxIncome: 16500,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'worker',
          names: [ N('construction laborer'), N('factory hand'), N('warehouse porter') ],
          level: 1,
          minIncome: 1600,
          maxIncome: 2100,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'worker',
          names: [ N('site foreman'), N('maintenance supervisor'), N('plant coordinator') ],
          level: 2,
          minIncome: 2800,
          maxIncome: 3400,
          isRare: false,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'casualCivilian',
          names: [
            N('cashier'),
            N('fast food worker'),
            N('dishwasher'),
            N('janitor'),
            N('housekeeper'),
            N('farm worker'),
            N('food worker'),
            N('laundry worker'),
            N('retail salesperson'),
            N('waiter'),
            N('waitress'),
            N('bartender'),
            N('hotel clerk'),
            N('childcare worker'),
            N('home health aide'),
            N('personal care aide'),
            N('cashier'),
            N('stocker'),
            N('packer'),
            N('meat packer'),
            N('clothier'),
            N('telemarketer'),
            N('data entry clerk'),
            N('receptionist'),
            N('teacher\'s aide'),
            N('delivery driver'),
            N('gardener'),
            N('maid'),
            N('cleaner'),
            N('cafeteria attendant'),
            N('car wash attendant'),
            N('gas station attendant'),
            N('store clerk'),
            N('toll collector'),
            N('usher'),
            N('lifeguard'),
            N('barista'),
            N('sandwich artist'),
            N('grocery bagger'),
            N('nursery worker'),
            N('factory assembler'),
            N('warehouse worker'),
            N('order picker'),
            N('packager'),
            N('laborer'),
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
            N('teacher'),
            N('nurse'),
            N('plumber'),
            N('electrician'),
            N('carpenter'),
            N('hvac technician'),
            N('welder'),
            N('machinist'),
            N('automotive technician'),
            N('dental hygienist'),
            N('medical sonographer'),
            N('radiologic technologist'),
            N('retail manager'),
            N('logistics coordinator'),
            N('heavy truck driver'),
            N('bus driver'),
            N('postal service worker'),
            N('massage therapist'),
            N('chef'),
            N('social worker'),
            N('quality control inspector'),
            N('cosmetologist'),
            N('fitness trainer'),
            N('surveyor'),
            N('aircraft mechanic'),
            N('machinery mechanic'),
            N('comms equipment installer'),
          ],
          level: 2,
          minIncome: 2500,
          maxIncome: 3200,
          isRare: false,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'barista',
          names: [ N('coffee runner'), N('espresso maker'), N('cafe attendant') ],
          level: 1,
          minIncome: 1400,
          maxIncome: 1900,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'barista',
          names: [ N('lead barista'), N('beverage supervisor'), N('cafe manager') ],
          level: 2,
          minIncome: 2600,
          maxIncome: 3200,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'stewardess',
          names: [ N('cabin attendant'), N('flight hostess'), N('sky steward') ],
          level: 1,
          minIncome: 2800,
          maxIncome: 3400,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'stewardess',
          names: [ N('senior flight attendant'), N('cabin supervisor'), N('inflight concierge') ],
          level: 2,
          minIncome: 5200,
          maxIncome: 6600,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'housewife',
          names: [ N('community homemaker'), N('house steward'), N('family caretaker') ],
          level: 1,
          minIncome: 1200,
          maxIncome: 1600,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'housewife',
          names: [ N('neighborhood matron'), N('household manager'), N('family coordinator') ],
          level: 2,
          minIncome: 2400,
          maxIncome: 3200,
          isRare: false,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'waiter',
          names: [ N('diner server'), N('table attendant'), N('waitstaff') ],
          level: 1,
          minIncome: 1500,
          maxIncome: 2000,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'waiter',
          names: [ N('head server'), N('shift captain'), N('dining supervisor') ],
          level: 2,
          minIncome: 2600,
          maxIncome: 3200,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'supportSpecialist',
          names: [ N('help desk agent'), N('technical concierge'), N('service desk rep') ],
          level: 1,
          minIncome: 2100,
          maxIncome: 2700,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'supportSpecialist',
          names: [ N('support lead'), N('systems support analyst'), N('customer support engineer') ],
          level: 2,
          minIncome: 4200,
          maxIncome: 5200,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'nun',
          names: [ N('novice sister'), N('choir nun'), N('cloister attendant') ],
          level: 1,
          minIncome: 1800,
          maxIncome: 2300,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'nun',
          names: [ N('mother superior'), N('abbey caretaker'), N('convent director') ],
          level: 2,
          minIncome: 3200,
          maxIncome: 4200,
          isRare: false,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'student',
          names: [ N('community college student'), N('night class attendee'), N('academy pupil') ],
          level: 1,
          minIncome: 500,
          maxIncome: 900,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'student',
          names: [ N('graduate student'), N('research assistant'), N('academy fellow') ],
          level: 2,
          minIncome: 900,
          maxIncome: 1500,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'courier',
          names: [ N('bike courier'), N('parcel runner'), N('express messenger') ],
          level: 1,
          minIncome: 2200,
          maxIncome: 2800,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'courier',
          names: [ N('route supervisor'), N('logistics dispatcher'), N('fleet coordinator') ],
          level: 2,
          minIncome: 4200,
          maxIncome: 5200,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'captain',
          names: [ N('patrol captain'), N('harbor skipper'), N('transit pilot') ],
          level: 1,
          minIncome: 5200,
          maxIncome: 6500,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'captain',
          names: [ N('operations captain'), N('fleet master'), N('port commander') ],
          level: 2,
          minIncome: 9000,
          maxIncome: 11500,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'fireman',
          names: [
            N('engine operator'),
            N('ladder specialist'),
            N('station responder'),
            N('hose operator'),
            N('brigade rookie'),
            N('station tender')
          ],
          level: 1,
          minIncome: 3000,
          maxIncome: 3900,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'fireman',
          names: [
            N('fire captain'),
            N('incident commander'),
            N('rescue coordinator'),
            N('engine lieutenant'),
            N('rescue captain'),
            N('operations firefighter')
          ],
          level: 2,
          minIncome: 5200,
          maxIncome: 7200,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'cook',
          names: [ N('line cook'), N('short-order cook'), N('commis chef') ],
          level: 1,
          minIncome: 1800,
          maxIncome: 2400,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'cook',
          names: [ N('head cook'), N('culinary supervisor'), N('executive chef') ],
          level: 2,
          minIncome: 3200,
          maxIncome: 7600,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'painter',
          names: [ N('house painter'), N('wall finisher'), N('decorative sprayer') ],
          level: 1,
          minIncome: 1500,
          maxIncome: 2100,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'painter',
          names: [ N('project painter'), N('finish specialist'), N('restoration artist') ],
          level: 2,
          minIncome: 2600,
          maxIncome: 3400,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'formalCivilian',
          names: [
            N('atrium concierge'),
            N('ballroom usher'),
            N('museum docent'),
            N('event planner'),
            N('auction caller'),
            N('embassy greeter'),
            N('train steward'),
            N('civic volunteer'),
            N('opera guide'),
            N('heritage archivist'),
            N('botanical host'),
            N('charity runner'),
            N('museum guide'),
            N('ferry aide'),
            N('planetarium presenter'),
            N('fashion dresser'),
            N('auction spotter'),
            N('diplomatic driver'),
            N('club attendant'),
            N('lounge singer'),
            N('hall coordinator')
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
            N('executive aide'),
            N('corporate liaison'),
            N('conference planner'),
            N('accountant'),
            N('admin assistant'),
            N('paralegal'),
            N('insurance agent'),
            N('loan officer'),
            N('web developer'),
            N('support specialist'),
            N('legal secretary'),
            N('executive assistant'),
            N('sales rep'),
            N('marketing specialist'),
            N('real estate broker'),
            N('claims adjuster'),
            N('bookkeeper'),
            N('graphic designer'),
            N('funeral director')
          ],
          level: 2,
          minIncome: 3600,
          maxIncome: 4500,
          isRare: false,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'preacher',
          names: [ N('youth minister'), N('street preacher'), N('community chaplain') ],
          level: 1,
          minIncome: 2200,
          maxIncome: 2800,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'preacher',
          names: [ N('senior pastor'), N('cathedral preacher'), N('civic reverend') ],
          level: 2,
          minIncome: 4600,
          maxIncome: 5800,
          isRare: false,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'hotelWorker',
          names: [ N('front desk clerk'), N('bellhop'), N('concierge assistant') ],
          level: 1,
          minIncome: 1800,
          maxIncome: 2400,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'hotelWorker',
          names: [ N('guest services manager'), N('hospitality supervisor'), N('concierge manager') ],
          level: 2,
          minIncome: 3400,
          maxIncome: 4200,
          isRare: true,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'foreman',
          names: [ N('crew foreman'), N('shift lead'), N('site supervisor') ],
          level: 1,
          minIncome: 2800,
          maxIncome: 3600,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'foreman',
          names: [ N('operations foreman'), N('construction superintendent'), N('plant foreman') ],
          level: 2,
          minIncome: 5200,
          maxIncome: 6800,
          isRare: false,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'barber',
          names: [ N('apprentice barber'), N('shop stylist'), N('chair clipper') ],
          level: 1,
          minIncome: 1900,
          maxIncome: 2500,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'barber',
          names: [ N('master barber'), N('grooming specialist'), N('barbershop lead') ],
          level: 2,
          minIncome: 3200,
          maxIncome: 4200,
          isRare: false,
        },


        {
          group: GROUP_CIVILIAN,
          type: 'barman',
          names: [ N('taproom server'), N('pub attendant'), N('draft tender') ],
          level: 1,
          minIncome: 1600,
          maxIncome: 2200,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'barman',
          names: [ N('bar steward'), N('lounge barkeep'), N('public house manager') ],
          level: 2,
          minIncome: 3000,
          maxIncome: 3800,
          isRare: true,
        },

        {
          group: GROUP_MEDIA,
          type: 'singer',
          names: [
            N('lounge vocalist'),
            N('club crooner'),
            N('street busker'),
            N('backup singer'),
            N('choir performer'),
            N('wedding singer'),
            N('karaoke host'),
            N('open mic artist'),
            N('session vocalist'),
            N('jingle singer')
          ],
          level: 1,
          minIncome: 2600,
          maxIncome: 3400,
          isRare: false,
        },
        {
          group: GROUP_MEDIA,
          type: 'singer',
          names: [
            N('recording artist'),
            N('concert performer'),
            N('tour vocalist'),
            N('lead singer'),
            N('solo artist'),
            N('studio vocalist'),
            N('festival headliner'),
            N('band frontman'),
            N('musical theater lead'),
            N('voice actor')
          ],
          level: 2,
          minIncome: 5200,
          maxIncome: 6600,
          isRare: false,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'bartender',
          names: [ N('tap tender'), N('barback'), N('cocktail mixer') ],
          level: 1,
          minIncome: 1700,
          maxIncome: 2300,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'bartender',
          names: [ N('mixologist'), N('bar manager'), N('club barkeep') ],
          level: 2,
          minIncome: 3200,
          maxIncome: 4000,
          isRare: true,
        },

        {
          group: GROUP_CORPORATE,
          type: 'hacker',
          names: [ N('penetration tester'), N('junior codebreaker'), N('security analyst') ],
          level: 1,
          minIncome: 5200,
          maxIncome: 6800,
          isRare: false,
          init: function(game: Game, ai: ai.AI) {
            ai.skills.addID(SKILL_COMPUTER, 30 + Std.random(20));
            if (game.player.vars.searchEnabled)
              ai.inventory.addID('laptop');
          },
        },
        {
          group: GROUP_CORPORATE,
          type: 'hacker',
          names: [ N('red team lead'), N('cyber intrusion expert'), N('black ice engineer') ],
          level: 2,
          minIncome: 9000,
          maxIncome: 12000,
          isRare: false,
          init: function(game: Game, ai: ai.AI) {
            ai.skills.addID(SKILL_COMPUTER, 50 + Std.random(20));
            if (game.player.vars.searchEnabled)
              ai.inventory.addID('laptop');
          },
        },

        {
          group: GROUP_CIVILIAN,
          type: 'librarian',
          names: [
            N('head librarian'),
            N('archive keeper'),
            N('special collections curator'),
            N('university archivist')
          ],
          level: 2,
          minIncome: 4200,
          maxIncome: 5200,
          isRare: true,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'scientist',
          names: [
            N('lab technician'),
            N('research assistant'),
            N('specimen handler'),
            N('data analyst'),
            N('field researcher'),
            N('laboratory aide'),
            N('sample processor'),
            N('test coordinator'),
            N('clinical assistant'),
            N('research associate')
          ],
          level: 1,
          minIncome: 3200,
          maxIncome: 3800,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'scientist',
          names: [
            N('research scientist'),
            N('principal investigator'),
            N('systems researcher'),
            N('senior scientist'),
            N('project lead'),
            N('biochemist'),
            N('microbiologist'),
            N('geneticist'),
            N('laboratory manager'),
            N('clinical researcher')
          ],
          level: 2,
          minIncome: 7200,
          maxIncome: 8500,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'scientist',
          names: [
            N('institute director'),
            N('chief scientist'),
            N('research chair'),
            N('department head'),
            N('chief research officer'),
            N('scientific director'),
            N('laboratory director'),
            N('research dean'),
            N('senior fellow'),
            N('program director')
          ],
          level: 3,
          minIncome: 50000,
          maxIncome: 65000,
          isRare: false,
        },

        {
          group: GROUP_CIVILIAN,
          type: 'prostitute',
          names: [ N('street worker'), N('corner hustler'), N('nightwalker') ],
          level: 1,
          minIncome: 900,
          maxIncome: 1200,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'prostitute',
          names: [ N('independent escort'), N('courtesan'), N('private companion') ],
          level: 2,
          minIncome: 2600,
          maxIncome: 3200,
          isRare: false,
        },
        {
          group: GROUP_CIVILIAN,
          type: 'prostitute',
          names: [ N('club proprietor'), N('club matriarch'), N('velvet room owner') ],
          level: 3,
          minIncome: 16000,
          maxIncome: 20000,
          isRare: false,
        },

        {
          group: GROUP_MEDIA,
          type: 'civilian',
          names: [
            N('journalist'),
            N('field reporter'),
            N('news stringer'),
            N('content writer'),
            N('freelance blogger'),
            N('copy editor'),
            N('community manager'),
            N('podcast producer'),
            N('video editor'),
            N('digital content creator')
          ],
          level: 1,
          minIncome: 2800,
          maxIncome: 3500,
          isRare: false,
        },
        {
          group: GROUP_MEDIA,
          type: 'civilian',
          names: [
            N('public relations manager'),
            N('social media strategist'),
            N('medium influencer'),
            N('news producer'),
            N('broadcast journalist'),
            N('communications director'),
            N('media consultant'),
            N('brand manager'),
            N('creative director'),
            N('investigative reporter')
          ],
          level: 2,
          minIncome: 6500,
          maxIncome: 7800,
          isRare: false,
        },
        {
          group: GROUP_MEDIA,
          type: 'civilian',
          names: [
            N('news anchor'),
            N('top influencer'),
            N('network personality'),
            N('media mogul'),
            N('television executive'),
            N('publishing director'),
            N('chief editor'),
            N('network president'),
            N('media conglomerate head'),
            N('broadcast executive')
          ],
          level: 3,
          minIncome: 42000,
          maxIncome: 52000,
          isRare: false,
        },

        {
          group: GROUP_CORPORATE,
          type: 'corpo',
          names: [
            N('office clerk'),
            N('data entry specialist'),
            N('customer service agent'),
            N('junior analyst'),
            N('project coordinator'),
            N('operations assistant'),
            N('business associate'),
            N('account rep'),
            N('client coordinator'),
            N('procurement specialist')
          ],
          level: 1,
          minIncome: 2600,
          maxIncome: 3200,
          isRare: false,
        },
        {
          group: GROUP_CORPORATE,
          type: 'corpo',
          names: [
            N('sales manager'),
            N('product manager'),
            N('human resources manager'),
            N('operations director'),
            N('finance manager'),
            N('supply chain manager'),
            N('compliance officer'),
            N('regional director'),
            N('portfolio manager'),
            N('business development manager')
          ],
          level: 2,
          minIncome: 9000,
          maxIncome: 11000,
          isRare: false,
        },
        {
          group: GROUP_CORPORATE,
          type: 'corpo',
          names: [
            N('marketing director'),
            N('business analyst lead'),
            N('corporate strategist'),
            N('chief financial officer'),
            N('chief operating officer'),
            N('executive vice president'),
            N('division president'),
            N('global operations head'),
            N('chief strategy officer'),
            N('enterprise architect')
          ],
          level: 3,
          minIncome: 60000,
          maxIncome: 80000,
          isRare: false,
        },

        {
          group: GROUP_CORPORATE,
          type: 'smiler',
          names: [
            N('public relations associate'),
            N('social media manager'),
            N('audience curator'),
            N('wellness advocate'),
            N('community builder'),
            N('lifestyle consultant'),
            N('happiness coordinator'),
            N('synergy specialist'),
            N('culture ambassador'),
            N('experience designer')
          ],
          level: 1,
          minIncome: 3000,
          maxIncome: 3600,
          isRare: false,
        },
        {
          group: GROUP_CORPORATE,
          type: 'smiler',
          names: [
            N('brand storyteller'),
            N('engagement architect'),
            N('activation planner'),
            N('transformation coach'),
            N('empowerment director'),
            N('paradigm shifter'),
            N('thought leader'),
            N('visionary facilitator'),
            N('mindfulness evangelist'),
            N('purpose strategist')
          ],
          level: 2,
          minIncome: 7600,
          maxIncome: 9000,
          isRare: false,
        },
        {
          group: GROUP_CORPORATE,
          type: 'smiler',
          names: [
            N('campaign visionary'),
            N('broadcast icon'),
            N('global spokesperson'),
            N('chief inspiration officer'),
            N('movement architect'),
            N('enlightenment director'),
            N('consciousness curator'),
            N('transcendence executive'),
            N('awakening orchestrator'),
            N('ascension facilitator')
          ],
          level: 3,
          minIncome: 52000,
          maxIncome: 68000,
          isRare: false,
        },

        {
          group: GROUP_LAWFARE,
          type: 'civilian',
          names: [
            N('court clerk'),
            N('legal assistant'),
            N('docket coordinator'),
            N('paralegal'),
            N('case researcher'),
            N('file clerk'),
            N('court reporter'),
            N('legal secretary'),
            N('records specialist'),
            N('bailiff assistant')
          ],
          level: 1,
          minIncome: 3200,
          maxIncome: 3800,
          isRare: false,
        },
        {
          group: GROUP_LAWFARE,
          type: 'civilian',
          names: [
            N('attorney'),
            N('prosecutor'),
            N('litigation counsel'),
            N('defense lawyer'),
            N('corporate counsel'),
            N('district attorney'),
            N('public defender'),
            N('legal advisor'),
            N('trial lawyer'),
            N('contract attorney')
          ],
          level: 2,
          minIncome: 9000,
          maxIncome: 12000,
          isRare: false,
        },
        {
          group: GROUP_LAWFARE,
          type: 'civilian',
          names: [
            N('judge'),
            N('chief prosecutor'),
            N('circuit justice'),
            N('magistrate'),
            N('chief counsel'),
            N('attorney general'),
            N('supreme court justice'),
            N('legal director'),
            N('chief judge'),
            N('solicitor general')
          ],
          level: 3,
          minIncome: 60000,
          maxIncome: 82000,
          isRare: false,
        },

        {
          group: GROUP_POLITICAL,
          type: 'civilian',
          names: [
            N('public servant'),
            N('bureaucrat'),
            N('constituency aide'),
            N('government clerk'),
            N('administrative assistant'),
            N('policy analyst'),
            N('city hall worker'),
            N('civil service employee'),
            N('public records officer'),
            N('municipal aide')
          ],
          level: 1,
          minIncome: 2400,
          maxIncome: 3200,
          isRare: false,
        },
        {
          group: GROUP_POLITICAL,
          type: 'civilian',
          names: [
            N('lobbyist'),
            N('councilor'),
            N('policy advocate'),
            N('city council member'),
            N('state representative'),
            N('policy director'),
            N('legislative aide'),
            N('campaign manager'),
            N('political consultant'),
            N('district coordinator')
          ],
          level: 2,
          minIncome: 7000,
          maxIncome: 9000,
          isRare: false,
        },
        {
          group: GROUP_POLITICAL,
          type: 'civilian',
          names: [
            N('politician'),
            N('representative'),
            N('cabinet powerbroker'),
            N('senator'),
            N('governor'),
            N('mayor'),
            N('secretary of state'),
            N('party chairman'),
            N('chief of staff'),
            N('presidential advisor')
          ],
          level: 3,
          minIncome: 50000,
          maxIncome: 65000,
          isRare: false,
        },

        {
          group: GROUP_COMBAT,
          type: 'police',
          names: [
            N('beat cop'),
            N('patrol officer'),
            N('street sergeant'),
            N('traffic officer'),
            N('parking enforcement'),
            N('community officer'),
            N('dispatch operator'),
            N('crime scene tech'),
            N('evidence custodian'),
            N('police cadet')
          ],
          level: 1,
          minIncome: 3000,
          maxIncome: 3500,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'police',
          names: [
            N('detective'),
            N('investigations officer'),
            N('case analyst'),
            N('homicide detective'),
            N('narcotics officer'),
            N('vice squad member'),
            N('forensics specialist'),
            N('internal affairs investigator'),
            N('gang unit officer'),
            N('swat team member')
          ],
          level: 2,
          minIncome: 6000,
          maxIncome: 7000,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'police',
          names: [
            N('police chief'),
            N('commissioner'),
            N('public safety director'),
            N('deputy chief'),
            N('police captain'),
            N('lieutenant colonel'),
            N('operations commander'),
            N('special operations overseer'),
            N('intelligence chief'),
            N('federal marshal')
          ],
          level: 3,
          minIncome: 40000,
          maxIncome: 45000,
          isRare: false,
        },

        {
          group: GROUP_COMBAT,
          type: 'security',
          names: [
            N('mall guard'),
            N('patrol guard'),
            N('floor sentry'),
            N('night watchman'),
            N('gate guard'),
            N('parking attendant'),
            N('bouncer'),
            N('loss prevention officer'),
            N('access control guard'),
            N('surveillance operator')
          ],
          level: 1,
          minIncome: 1800,
          maxIncome: 2300,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'security',
          names: [
            N('security supervisor'),
            N('shift commander'),
            N('watch captain'),
            N('head of security'),
            N('security manager'),
            N('operations supervisor'),
            N('team leader'),
            N('field supervisor'),
            N('security coordinator'),
            N('site supervisor')
          ],
          level: 2,
          minIncome: 3600,
          maxIncome: 4200,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'security',
          names: [
            N('corporate security director'),
            N('director of protection'),
            N('security strategist'),
            N('chief security officer'),
            N('vice president of security'),
            N('executive protection director'),
            N('risk management director'),
            N('global security head'),
            N('security operations director'),
            N('protective services chief')
          ],
          level: 3,
          minIncome: 20000,
          maxIncome: 26000,
          isRare: false,
        },

        {
          group: GROUP_COMBAT,
          type: 'agent',
          names: [
            N('field observer'),
            N('case scout'),
            N('liaison operative'),
            N('surveillance specialist'),
            N('intelligence analyst'),
            N('field agent'),
            N('covert operative'),
            N('undercover agent'),
            N('counterintelligence officer'),
            N('investigative agent')
          ],
          level: 1,
          minIncome: 4800,
          maxIncome: 5400,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'agent',
          names: [
            N('case officer'),
            N('handler'),
            N('ops coordinator'),
            N('senior field agent'),
            N('operations officer'),
            N('intelligence officer'),
            N('special agent'),
            N('task force leader'),
            N('operations manager'),
            N('field supervisor')
          ],
          level: 2,
          minIncome: 9200,
          maxIncome: 11000,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'agent',
          names: [
            N('station chief'),
            N('regional controller'),
            N('intelligence director'),
            N('deputy director'),
            N('assistant director'),
            N('division chief'),
            N('operations director'),
            N('intelligence chief'),
            N('field operations director'),
            N('executive director')
          ],
          level: 3,
          minIncome: 70000,
          maxIncome: 90000,
          isRare: false,
        },

        {
          group: GROUP_COMBAT,
          type: 'thug',
          names: [
            N('gang member'),
            N('street enforcer'),
            N('corner muscle'),
            N('street thug'),
            N('hoodlum'),
            N('common goon'),
            N('hired muscle'),
            N('street dealer'),
            N('gang lookout'),
            N('enforcer')
          ],
          level: 1,
          minIncome: 800,
          maxIncome: 1200,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'thug',
          names: [
            N('gang lieutenant'),
            N('crew captain'),
            N('mob lieutenant'),
            N('gang sergeant'),
            N('crew leader'),
            N('territory boss'),
            N('street captain'),
            N('hitman'),
            N('crew enforcer'),
            N('gang coordinator')
          ],
          level: 2,
          minIncome: 2000,
          maxIncome: 2600,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'thug',
          names: [
            N('gang boss'),
            N('crime lord'),
            N('block kingpin'),
            N('crime boss'),
            N('syndicate leader'),
            N('underworld kingpin'),
            N('crime family head'),
            N('mob boss'),
            N('cartel leader'),
            N('criminal mastermind')
          ],
          level: 3,
          minIncome: 15000,
          maxIncome: 20000,
          isRare: false,
        },

        {
          group: GROUP_COMBAT,
          type: 'soldier',
          names: [
            N('infantry trooper'),
            N('line rifleman'),
            N('field specialist'),
            N('grunt'),
            N('rifleman'),
            N('combat soldier'),
            N('infantryman'),
            N('foot soldier'),
            N('ground pounder'),
            N('trooper')
          ],
          level: 1,
          minIncome: 2800,
          maxIncome: 3200,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'soldier',
          names: [
            N('platoon sergeant'),
            N('unit leader'),
            N('operations sergeant'),
            N('staff sergeant'),
            N('squad leader'),
            N('platoon leader'),
            N('company sergeant'),
            N('first sergeant'),
            N('master sergeant'),
            N('command sergeant')
          ],
          level: 2,
          minIncome: 4500,
          maxIncome: 5200,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'soldier',
          names: [
            N('battalion commander'),
            N('field commander'),
            N('operations colonel'),
            N('brigade commander'),
            N('division general'),
            N('commanding officer'),
            N('military strategist'),
            N('operations general'),
            N('field marshal'),
            N('chief of staff')
          ],
          level: 3,
          minIncome: 28000,
          maxIncome: 34000,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'officer',
          names: [
            N('lieutenant'),
            N('second lieutenant'),
            N('captain'),
            N('staff officer'),
            N('intelligence officer'),
            N('signals officer'),
            N('logistics officer'),
            N('adjutant')
          ],
          level: 1,
          minIncome: 6000,
          maxIncome: 8000,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'officer',
          names: [
            N('major'),
            N('lieutenant colonel'),
            N('executive officer'),
            N('operations officer')
          ],
          level: 2,
          minIncome: 9000,
          maxIncome: 12000,
          isRare: false,
        },

        {
          group: GROUP_COMBAT,
          type: 'blackops',
          names: [ N('covert operator'), N('shadow operative'), N('clandestine agent') ],
          level: 1,
          minIncome: 6200,
          maxIncome: 7000,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'blackops',
          names: [ N('strike leader'), N('mission commander'), N('assault lead') ],
          level: 2,
          minIncome: 12000,
          maxIncome: 15000,
          isRare: false,
        },
        {
          group: GROUP_COMBAT,
          type: 'blackops',
          names: [ N('mission architect'), N('strategic mastermind'), N('black budget director') ],
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

          // add all names to jobsByName map
          for (name in info.names)
            {
              jobsByName.set(name, info);
            }
          
          // add to jobsByGroup map
          var groupList = jobsByGroup.get(info.group);
          if (groupList == null)
            {
              groupList = [];
              jobsByGroup.set(info.group, groupList);
            }
          groupList.push(info);
        }
    }

  // get job info by name
  public function getJobInfo(name: String): _JobInfo
    {
      return jobsByName.get(name);
    }

  // convert job group enum to string name
  public function groupToName(group: _AIJobGroup): String
    {
      switch (group)
        {
          case GROUP_COMBAT:
            return 'combat';
          case GROUP_MEDIA:
            return 'media';
          case GROUP_LAWFARE:
            return 'lawfare';
          case GROUP_CORPORATE:
            return 'corporate';
          case GROUP_POLITICAL:
            return 'political';
          default:
            return 'combat';
        }
    }

  // get next level job info for a given group and job name
  // finds job info by group+name pair, then gets job info with same group+type and level+1
  public function getNextJobLevel(group: _AIJobGroup, name: String): _JobInfo
    {
      // find job info that matches group and name
      var currentInfo: _JobInfo = null;
      var groupJobs = jobsByGroup.get(group);
      if (groupJobs == null)
        return null;
      
      for (info in groupJobs)
        {
          for (jobName in info.names)
            {
              if (jobName == name)
                {
                  currentInfo = info;
                  break;
                }
            }
          if (currentInfo != null)
            break;
        }
      
      if (currentInfo == null)
        return null;
      
      // find job info with same group, same type, and level+1
      for (info in groupJobs)
        {
          if (info.group == group &&
              info.type == currentInfo.type &&
              info.level == currentInfo.level + 1)
            {
              return info;
            }
        }
      
      return null;
    }

  // get random job by group and level
  public function getJobByGroupAndLevel(group: _AIJobGroup, level: Int): _JobInfo
    {
      var infos = jobsByGroup.get(group);
      if (infos == null || infos.length == 0)
        return null;
      
      // find jobs with matching level
      var matchingLevel = [];
      for (info in infos)
        {
          if (info.level == level)
            matchingLevel.push(info);
        }
      
      if (matchingLevel.length == 0)
        return null;
      
      // return random job of matching level
      return matchingLevel[Std.random(matchingLevel.length)];
    }

  // common helper to roll job info from a pool of job infos
  public function rollJobInfo(pool: Array<_JobInfo>): { name: String, income: Int, isRare: Bool, jobInfo: _JobInfo }
    {
      // pick random job from pool
      var picked = pool[Std.random(pool.length)];
      var pickedName = picked.names[Std.random(picked.names.length)];
      var income = picked.minIncome;
      if (picked.maxIncome > picked.minIncome)
        income += Std.random(picked.maxIncome - picked.minIncome + 1);
      income = Std.int(income / 100) * 100;
      
      return {
        name: pickedName,
        income: income,
        isRare: picked.isRare,
        jobInfo: picked
      };
    }

  // returns random job info for the provided type
  // this is intended for street spawns
  public function getRandom(type: String): { name: String, income: Int, isRare: Bool, jobInfo: _JobInfo }
    {
      var infos = jobsByType.get(type);
      if (infos == null || infos.length == 0)
        return {
          name: N('unemployed'),
          income: 0,
          isRare: false,
          jobInfo: null
        };

      // level 3 cannot be spawned on the street by chance
      var level1: Array<_JobInfo> = [];
      var level2: Array<_JobInfo> = [];
      for (info in infos)
        {
          switch (info.level)
            {
              case 1:
                level1.push(info);
              case 2:
                level2.push(info);
              default:
            }
        }
      var pool: Array<_JobInfo> = level1;
      // level 2 has 10% chance to spawn
      if (level2.length > 0 && Std.random(100) < 10)
        pool = level2;

      if (pool.length == 0)
        pool = infos;

      return rollJobInfo(pool);
    }

// returns random job info for the provided group string
// NOTE: used in recruit follower ordeal, level limited
  public function getRandomByGroup(type: String): { name: String, income: Int, isRare: Bool, jobInfo: _JobInfo }
    {
      // convert string type to job group
      var group: _AIJobGroup;
      switch (type)
        {
          case 'media':
            group = GROUP_MEDIA;
          case 'lawfare':
            group = GROUP_LAWFARE;
          case 'political':
            group = GROUP_POLITICAL;
          case 'corporate':
            group = GROUP_CORPORATE;
          case 'combat':
            group = GROUP_COMBAT;
          default:
            group = GROUP_CIVILIAN; // fallback
        }
      
      var infos = jobsByGroup.get(group);
      if (infos == null || infos.length == 0)
        return {
          name: N('unemployed'),
          income: 0,
          isRare: false,
          jobInfo: null
        };
      
      // level 3 cannot be spawned by chance (follows street spawn job level logic)
      var level1: Array<_JobInfo> = [];
      var level2: Array<_JobInfo> = [];
      for (info in infos)
        {
          switch (info.level)
            {
              case 1:
                level1.push(info);
              case 2:
                level2.push(info);
              default:
            }
        }
      var pool: Array<_JobInfo> = level1;
      // level 2 has 10% chance to spawn
      if (level2.length > 0 && Std.random(100) < 10)
        pool = level2;
      
      if (pool.length == 0)
        pool = infos;
      
      return rollJobInfo(pool);
    }

  // get sorted and unique list of civilian job types
  public function getCivilianJobTypesList(): Array<String>
    {
      var types = new Map<String, Bool>();
      for (info in jobsByType)
        {
          for (jobInfo in info)
            {
              if (jobInfo.group == GROUP_CIVILIAN)
                types.set(jobInfo.type, true);
            }
        }
      var list = [];
      for (type in types.keys())
        list.push(type);
      list.sort(function(a: String, b: String) {
        if (a > b) return 1;
        else if (a < b) return -1;
        return 0;
      });
      return list;
    }
}
