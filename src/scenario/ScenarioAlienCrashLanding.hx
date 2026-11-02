// scenario - alien crash landing

package scenario;

import scenario.Scenario;

class ScenarioAlienCrashLanding extends Scenario
{
  public function new()
    {
      super();
      name = N('Alien Crash Landing');
      startEvent = 'alienMission';
      playerStartEvent = 'parasiteTransportation';
      defaultAlertness = 50;
      goals = GoalsAlienCrashLanding.map;
      eventObjectActions = GoalsAlienCrashLanding.eventObjectActions;
      eventObjectActionsFuncs = GoalsAlienCrashLanding.eventObjectActionsFuncs;
      eventObjectActionsHooks = GoalsAlienCrashLanding.eventObjectActionsHooks;
//      onInit = GoalsAlienCrashLanding.onInit;

      names = [
        'facility1' => [ '%tree1% %geo1% %lab1%' ],
        'facility2' => [ '%tree1% %geo1% %lab1%' ],
        'facility3' => [ '%tree1% %geo1% %lab1%' ],
        'shipCode' => [
          'OBJ-%num1%%num2%',
          'UFO-%num1%%num2%-%greek1%',
          'SAUCE-%num1%%num1%',
          'Capricorn',
          'Jellyfish',
          'Manatee',
          'Manta',
          'Mantis',
          'Nautilus',
          'Phantom',
          'Rainbow',
          'Revenant',
          'Swordfish',
        ],
        'alienCode' => [
          'ET-%letter1%%num1%%num2%',
          'ETO-%num1%%num2%%letter1%',
          'XBO-%num1%%num2%',
          'Bearer',
          'Carrier',
          'Envoy',
          'Fiddler',
          'Gray',
          'Sage',
          'Visitor',
        ],
        'parasiteCode' => [
          'AO-%letter1%%letter2%%num1%%num2%',
          'OUO-%num1%%num2%',
          'LF-%greek1%-%greek2%',
          'Cuckoo',
          'Gecko',
          'Jumper',
          'Junior',
        ],
        'projectCode' => [
          'Antares',
          'Aurora',
          'Canopus',
          'Chimera',
          'Eclipse',
          'Mercury',
          'Mirage',
          'Monolith',
          'Nighthawk',
          'Saturn',
          'Unity',
          'Vega',
          'Xenon',
        ],
      ];
      flow = [
        'alienMission' => {
          name: 'alien mission',
          next: 'shipSpottedCiv',
          isHidden: true,
          init: function (timeline: scenario.Timeline)
            {
              var tmp = [ 'abduction', 'liquidation', 'intel' ];
              var type = tmp[Std.random(tmp.length)];
              timeline.setVar('alienMissionType', type);
              timeline.setVar('alienLanguageID', 1 + Std.random(4));
            },

          notes: [
            // tr: {alienMissionType} is a timeline variable: abduction, liquidation or intel
            N('You have received your mission details at the HQ. The mission type was {alienMissionType, select, abduction{abduction} liquidation{liquidation} other{intelligence collection}}.')
            ],
          },

        'shipSpottedCiv' => {
          name: 'alien ship spotted by civilians',
          next: 'shipSpottedMil',
          notes: [
            N('UFO was spotted by civilian witnesses.'),
            N('Media has published some reports about UFO sighting.'),
            N('Ufologists have recorded the information about UFO sighting.'),
            N('Independent experts and conspiracy theorists may have some knowledge about the events.')
            ],
          location: {
            type: AREA_GROUND,
            },
          npc: [
            N('civilian') => 20,
            N('reporter') + ':civilian' => 5,
            N('ufologist') + ':civilian' => 5,
            N('conspirologist') + ':civilian' => 3 ],
          },

        'shipSpottedMil' => {
          name: 'alien ship spotted by military',
          next: 'dogfight',
          notes: [
            N('Radars from a military base have spotted a moving signature.'),
            N('Radio requests were left unanswered.'),
            N('An interceptor was scrambled.')
            ],
          location: {
            type: AREA_MILITARY_BASE,
            id: 'base1',
            near: 'shipSpottedCiv'
            },
          npc: [ N('soldier') => 20 ],
          },

        'dogfight' => {
          name: 'dogfight with alien ship',
          nextOR: [ 'shipLanded' => 30, 'shipShotDown' => 70 ],
          notes: [
            N('The interceptor pilot described the dogfight in detail.'),
            "A veteran pilot, he said it was unlike anything he's ever seen before.",
            N('The plane suffered heavy damage in a fight.'),
            N('The pilot is on psychic evaluation and extended leave.')
            ],
          npc: [ N('soldier') => 5 ],
          },

        'shipLanded' => {
          name: 'alien ship safely landed',
          next: 'shipLandingInvestigation',
          init: function (timeline)
            {
              timeline.setVar('shipLanded', true);
            },
          notes: [
            N('The pilot did not manage to shoot UFO down but it was tracked by a second plane until it landed.'),
            ],
          location: {
            near: 'shipSpottedCiv',
            },
          npc: [ N('soldier') => 10 ],
          },

        'shipShotDown' => {
          name: 'alien ship shot down by military',
          next: 'crashLandingInvestigation',
          init: function (timeline)
            {
              timeline.setVar('shipShotDown', true);
            },
          notes: [
            N('The pilot managed to shoot down the object.'),
            ],
          location: {
            near: 'shipSpottedCiv',
            },
          npc: [ N('soldier') => 10 ],
          },

        'shipLandingInvestigation' => {
          name: 'alien ship landing investigation',
          next: 'alienShipTransportation',
          notes: [
            N('The military personnel formed a cordon surrounding the scene.'),
            N('Agents proceeded to study the landing scene and gather evidence.'),
            N('The agents made the decision to move all objects on the scene to a secure facility.')
            ],
          location: {
            sameAs: 'shipLanded'
            },
          npc: [ N('soldier') => 20, N('agent') => 5 ],
          },

        'crashLandingInvestigation' => {
          name: 'alien ship crash landing investigation',
          next: 'alienShipTransportation',
          notes: [
            N('The military personnel formed a cordon surrounding the scene.'),
            N('Agents proceeded to study the scene and gather evidence.'),
            N('The agents made the decision to move all evidence recovered on the scene to a secure facility.')
            ],
          location: {
            sameAs: 'shipShotDown'
            },
          npc: [ N('soldier') => 20, N('agent') => 5 ],
          },

        'alienShipTransportation' => {
          name: 'alien ship transported to secret facility',
          next: 'alienShipStudy',
          notes: [
            N('Everything recovered from the scene was successfully transported to %facility1%.'),
            N('The largest object has received a speficic codename for future reference: %shipCode%.')
            ],
          npc: [ N('agent') => 5 ],
        },

        'alienShipStudy' => {
          name: 'study of an alien ship',
          next: 'alienCaptureMission',
          notes: [
            N('Studying %shipCode% has proved to be extremely difficult.'),
            N('The technology that produced %shipCode% is much more advanced than the one available to human civilization.'),
            N('Strange metallic alloy that forms the outer layer of %shipCode% is unknown to science.'),
            N('Scientists have been unable to determine if it is indeed a flying vessel.')
          ],
          location: {
            type: AREA_FACILITY,
            name: '%facility1%'
          },
          npc: [ N('researcher') + ':scientist' => 10, N('agent') => 5 ],
          onLearnLocation: function (game) {
            game.goals.receive(SCENARIO_ALIEN_FIND_SHIP);
            game.goals.complete(SCENARIO_ALIEN_FIND_SHIP);
          },
        },

        'alienCaptureMission' => {
          name: 'alien capture mission',
          nextOR: [ 'alienCaptured' => 30, 'alienKilled' => 70 ],
          notes: [
            N('It was determined that %shipCode% could have pilot and/or crew onboard.'),
            N('Multiple teams of agents were sent to capture or kill the pilot.'),
            N('The primary goal of the mission was capturing the pilot alive.')
            ],
          location: {
            near: 'shipSpottedCiv' // cant make it near landing because of branching
            },
          npc: [ N('agent') => 10 ],
          },

        'alienCaptured' => {
          name: 'live alien was captured',
          next: 'liveAlienTransportation',
          notes: [
            N('Fortunately, the %shipCode% pilot survived the capture mission.'),
            N('The pilot was not human.'),
            N('The pilot was a grey humanoid of unknown origin.')
            ],
          location: {
            sameAs: 'alienCaptureMission'
            },
          npc: [ N('agent') => 5 ],
          },

        'alienKilled' => {
          name: 'alien was killed during capture attempt',
          next: 'deadAlienTransportation',
          notes: [
            N('Unfortunately, during the capture attempt the %shipCode% pilot was shot dead.'),
            N('The pilot was not human.'),
            N('The pilot was a grey humanoid of unknown origin.')
            ],
          location: {
            sameAs: 'alienCaptureMission'
            },
          npc: [ N('agent') => 5 ],
          },

        'liveAlienTransportation' => {
          name: 'live alien was tranported to secret facility',
          next: 'liveAlienStudy',
          init: function (timeline: Timeline)
            {
              timeline.setVar('alienIsAlive', 1);
            },
          notes: [
            N('The captured organism was transported to %facility2% for further study. Project %projectCode% initiated.'),
            N('Captured organism has received a special code: %alienCode%.'),
            ],
          npc: [ N('agent') => 2 ],
          },

        'deadAlienTransportation' => {
          name: 'alien remains were transported to secret facility',
          next: 'deadAlienStudy',
          init: function (timeline: Timeline)
            {
              timeline.setVar('alienIsDead', 1);
            },
          notes: [
            N('The acquired cadaver was transported to %facility2% for further study. Project %projectCode% initiated.'),
            N('The body of possibly extraterrestrial origins has received a special code: %alienCode%.'),
            ],
          npc: [ N('agent') => 2 ],
          },

        'liveAlienStudy' => {
          name: 'study of a live alien',
          next: 'parasiteRemoval',
          notes: [
            N('Preliminary examinations confirmed the extraterrestrial origins of %alienCode% organism.'),
            N('Studies have shown that %alienCode% actually consists of two separate organisms.'),
            N('One of the organisms is parasitic in nature. It has received a unique codename: %parasiteCode%.'),
            N('It is unclear at this point whether the host organism of %alienCode% has any intelligence.')
            ],
          location: {
            id: 'facility2',
            type: AREA_FACILITY,
            name: '%facility2%'
            },
          npc: [ N('researcher') + ':scientist' => 10, N('agent') => 2 ],
          onLearnNote: function(game, noteID)
            {
              game.goals.complete(GOAL_PROGRESS_TIMELINE);
              game.goals.receive(SCENARIO_ALIEN_FIND_SHIP);

              // alien is alive, save it
//              game.goals.receive(SCENARIO_ALIEN_SAVE_ALIEN);
            },
          },

        'deadAlienStudy' => {
          name: 'study of alien remains',
          next: 'parasiteRemoval',
          notes: [
            N('Preliminary examinations confirmed the extraterrestrial origins of %alienCode% cadaver.'),
            N('Studies have shown that %alienCode% remains actually consist of two separate organisms.'),
            N('One of the organisms is still functioning and is parasitic in nature.'),
            N('The parasite organism has received a unique codename: %parasiteCode%.'),
            N('It is unclear whether the host organism of %alienCode% had any intelligence.')
            ],
          location: {
            id: 'facility2',
            type: AREA_FACILITY,
            name: '%facility2%'
            },
          npc: [ N('researcher') + ':scientist' => 5 ],
          onLearnNote: function(game, noteID)
            {
              game.goals.complete(GOAL_PROGRESS_TIMELINE);
              game.goals.receive(SCENARIO_ALIEN_FIND_SHIP);
            },
          },

        'parasiteRemoval' => {
          name: 'parasite removal',
          next: 'parasiteTransportation',
          notes: [
            N('The decision has been made to try to separate organisms surgically.'),
            N('Separation was successful and %parasiteCode% was scheduled for transportation to %facility3%.'),
            N('The specialist performing the operation speculated that the process was a violent shock for both %alienCode% and %parasiteCode% nervous systems and mental capacity.'),
            ],
          location: { // cannot use sameAs due to branching but it should smartly check if location with this id exists
            id: 'facility2',
            type: AREA_FACILITY,
            name: '%facility2%'
            },
          npc: [ N('researcher') + ':scientist' => 5 ],
          },

        'parasiteTransportation' => {
          name: 'parasite transportation',
          notes: [
            N('During the transportation of %parasiteCode% to %facility3% the containment protocol has been breached and the specimen has managed to escape.'),
            N('Current location of %parasiteCode% specimen is unknown, project %projectCode% is on hold until retrieval.'),
            N('Teams of field specialists have been scrambled to the area.')
            ],
          location: {
            },
          npc: [ N('agent') => 2 ],
          },
/*

        '' => {
          name: '',
          },
*/
        ];
    }
}
