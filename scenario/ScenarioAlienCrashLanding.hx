package scenario;

import scenario.Scenario;
import const.WorldConst;

class ScenarioAlienCrashLanding extends Scenario
{
  public function new()
    {
      super();
      name = 'Alien Crash Landing';
      startEvent = 'alienMission';
      playerStartEvent = 'parasiteTransportation';
      defaultAlertness = 50;
      defaultInterest = 10;

      names = [
        'facility1' => [ 'Facility 1 TODO' ],
        'facility2' => [ 'Facility 2 TODO' ],
        'facility3' => [ 'Facility 3 TODO' ],
        'shipCode' => [ 'OBJ-%num1%%num2%', 'UFO-%num1%%num2%-%greek1%',
          'SAUCE-%num1%%num1%' ],
        'alienCode' => [ 'ET-%letter1%%num1%%num2%', 'ETO-%num1%%num2%%letter1%',
          'XBO-%num1%%num2%' ],
        'parasiteCode' => [ 'AO-%letter1%%letter2%%num1%%num2%', 'OUO-%num1%%num2%',
          'LF-%greek1%-%greek2%' ],
        ];
      flow = [
        'alienMission' => {
          name: 'alien mission',
          next: 'shipSpottedCiv',
          isHidden: true,
          init: function (timeline: Timeline)
            {
              var tmp = [ 'abduction', 'infiltration', 'research' ];
              timeline.setVar('alienMissionType', tmp[Std.random(tmp.length)]);
            },

          notes: [
            'You have received your mission details in the HQ.'
            ],
          },

        'shipSpottedCiv' => {
          name: 'alien ship spotted by civilians',
          next: 'shipSpottedMil',
          notes: [
            'UFO was spotted by civilian witnesses.',
            'Media has published some reports about UFO sighting.',
            'Ufologists have recorded the information about UFO sighting.',
            'Independent experts and conspiracy theorists may have some knowledge about the events.'
            ],
          location: {
            type: AREA_GROUND,
            },
          npc: [ 
            'civilian' => 20, 
            'reporter:civilian' => 5, 
            'ufologist:civilian' => 5, 
            'conspirologist:civilian' => 3 ],
          },

        'shipSpottedMil' => {
          name: 'alien ship spotted by military',
          next: 'dogfight',
          notes: [
            'Radars from a military base have spotted the moving signature.',
            'Radio requests were left unanswered.',
            'An interceptor was scrambled.'
            ],
          location: {
            type: AREA_MILITARY_BASE,
            near: 'shipSpottedCiv'
            },
          npc: [ 'soldier' => 20 ],
          },

        'dogfight' => {
          name: 'dogfight with alien ship',
          nextOR: [ 'shipLanded' => 30, 'shipShotDown' => 70 ],
          notes: [
            'The interceptor pilot described the dogfight in detail.',
            "A veteran pilot, he said it was unlike anything he's ever seen before.",
            'The plane suffered heavy damage in a fight.',
            'The pilot is on psychic evaluation and extended leave.'
            ],
          npc: [ 'soldier' => 5 ],
          },

        'shipLanded' => {
          name: 'alien ship safely landed',
          next: 'shipLandingInvestigation',
          notes: [
            'The pilot did not manage to shoot UFO down but it was tracked by a second plane until it landed.',
            ],
          location: {
            near: 'shipSpottedCiv',
            interest: 25,
            },
          npc: [ 'soldier' => 10 ],
          },

        'shipShotDown' => {
          name: 'alien ship shot down by military',
          next: 'crashLandingInvestigation',
          notes: [
            'The pilot managed to shoot down the UFO.',
            ],
          location: {
            near: 'shipSpottedCiv',
            interest: 25,
            },
          npc: [ 'soldier' => 10 ],
          },

        'shipLandingInvestigation' => {
          name: 'alien ship landing investigation',
          next: 'alienShipTransportation',
          notes: [
            'The military personnel formed a cordon surrounding the scene.',
            'Agents proceeded to study the landing scene and gather evidence.',
            'The agents made the decision to move all objects on the scene to a secure facility.'
            ],
          location: {
            sameAs: 'shipLanded'
            },
          npc: [ 'soldier' => 20, 'agent' => 5 ],
          },

        'crashLandingInvestigation' => {
          name: 'alien ship crash landing investigation',
          next: 'alienShipTransportation',
          notes: [
            'The military personnel formed a cordon surrounding the scene.',
            'Agents proceeded to study the scene and gather evidence.',
            'The agents made the decision to move all evidence recovered on the scene to a secure facility.'
            ],
          location: {
            sameAs: 'shipShotDown'
            },
          npc: [ 'soldier' => 20, 'agent' => 5 ],
          },

        'alienShipTransportation' => {
          name: 'alien ship transported to secret facility',
          next: 'alienShipStudy',
          notes: [
            'Everything recovered from the scene was successfully transported to %facility1%',
            'The largest object has received a speficic codename for future reference: %shipCode%.'
            ],
          npc: [ 'agent' => 5 ],
          },

        'alienShipStudy' => {
          name: 'study of an alien ship',
          next: 'alienCaptureMission',
          notes: [
            'Studying %shipCode% has proved to be extremely difficult.',
            'The technology that produced %shipCode% is much more advanced than the one available to human civilization.',
            'Strange metallic alloy that forms the outer layer of %shipCode% is unknown to science.',
            'Scientists have been unable to determine if it is indeed a flying vessel.'
            ],
          location: {
            type: AREA_FACILITY,
            name: '%facility1%'
            },
          npc: [ 'researcher:civilian' => 10, 'agent' => 5 ],
          },

        'alienCaptureMission' => {
          name: 'alien capture mission',
          nextOR: [ 'alienCaptured' => 30, 'alienKilled' => 70 ],
          notes: [
            'It was determined that %shipCode% could have pilot and/or crew onboard.',
            'Multiple teams of agents were sent to capture or kill the pilot.',
            'The primary goal of the mission was capturing the pilot alive.'
            ],
          location: {
            near: 'shipSpottedCiv' // cant make it near landing because of branching
            },
          npc: [ 'agent' => 10 ],
          },

        'alienCaptured' => {
          name: 'live alien was captured',
          next: 'liveAlienTransportation',
          notes: [
            'Fortunately, the %shipCode% pilot survived the capture mission.',
            'The pilot was not human.',
            'The pilot was a grey humanoid of unknown origin.'
            ],
          location: {
            sameAs: 'alienCaptureMission'
            },
          npc: [ 'agent' => 5 ],
          },

        'alienKilled' => {
          name: 'alien was killed during capture attempt',
          next: 'deadAlienTransportation',
          notes: [
            'Unfortunately, during the capture attempt the %shipCode% pilot was shot dead.',
            'The pilot was not human.',
            'The pilot was a grey humanoid of unknown origin.'
            ],
          location: {
            sameAs: 'alienCaptureMission'
            },
          npc: [ 'agent' => 5 ],
          },

        'liveAlienTransportation' => {
          name: 'live alien was tranported to secret facility',
          next: 'liveAlienStudy',
          init: function (timeline: Timeline)
            {
              timeline.setVar('alienIsAlive', 1);
            },
          notes: [
            'The captured organism was transported to %facility2% for further study.',
            'Captured organism has received a special Code: %alienCode%',
            ],
          npc: [ 'agent' => 2 ],
          },

        'deadAlienTransportation' => {
          name: 'alien remains were transported to secret facility',
          next: 'deadAlienStudy',
          init: function (timeline: Timeline)
            {
              timeline.setVar('alienIsDead', 1);
            },
          notes: [
            'The acquired cadaver was transported to %facility2% for further study.',
            'The body of possibly alien origins has received a special Code: %alienCode%.',
            ],
          npc: [ 'agent' => 2 ],
          },

        'liveAlienStudy' => {
          name: 'study of a live alien',
          next: 'parasiteRemoval',
          notes: [
            'Preliminary examinations confirmed the alien origins of %alienCode% organism.',
            'Studies have shown that %alienCode% actually consists of two separate organisms.',
            'One of the organisms is parasitic in nature. It has received a unique codename: %parasiteCode%.',
            'It is unclear whether the host organism of %alienCode% has any intelligence.'
            ],
          location: {
            id: 'facility2',
            type: AREA_FACILITY,
            name: '%facility2%'
            },
          npc: [ 'researcher:civilian' => 10, 'agent' => 2 ],
          },

        'deadAlienStudy' => {
          name: 'study of alien remains',
          next: 'parasiteRemoval',
          notes: [
            'Preliminary examinations confirmed the alien origins of %alienCode% cadaver.',
            'Studies have shown that %alienCode% remains actually consist of two separate organisms.',
            'One of the organisms is still functioning and is parasitic in nature.',
            'The parasite organism has received a unique codename: %parasiteCode%.',
            'It is unclear whether the host organism of %alienCode% had any intelligence.'
            ],
          location: {
            id: 'facility2',
            type: AREA_FACILITY,
            name: '%facility2%'
            },
          npc: [ 'researcher:civilian' => 5 ],
          },

        'parasiteRemoval' => {
          name: 'parasite removal',
          next: 'parasiteTransportation',
          notes: [
            'The decision has been made to try to separate organisms surgically.',
            'Separation was successful and %parasiteCode% was scheduled for transportation to %facility3%.',
            'The specialist performing the operation speculated that separation was a violent shock for both %alienCode% and %parasiteCode% nervous systems and mental capacity.',
            ],
          location: { // cannot use sameAs due to branching but it should smartly check if location with this id exists 
            id: 'facility2',
            type: AREA_FACILITY,
            name: '%facility2%'
            },
          npc: [ 'researcher:civilian' => 5 ],
          },

        'parasiteTransportation' => {
          name: 'parasite transportation',
          notes: [
            'During %parasiteCode% transportation to facility %facility3% the containment protocol has been breached and the specimen managed to escape.',
            'Current location of %parasiteCode% specimen is unknown.',
            'Teams of field specialists have been scrambled to the area.'
            ],
          location: {
            interest: 50 
            },
          npc: [ 'agent' => 2 ],
          },
/*

        '' => {
          name: '',
          },
*/        
        ];
    }
}
