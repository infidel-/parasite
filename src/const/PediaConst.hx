package const;

class PediaConst
{
  public static var initialArticles = [
    'hudActions',
    'hudGoals',
    'hudInfoParasite',
    'hudLog',
    'keyboardShortcuts',
    'lifeParasite',
    'movement',
    'npcInteraction',
    'sandboxMode',
  ];
  public static var contents: Array<_PediaGroupInfo> = [
    {
      id: 'basics',
      name: 'BASICS',
      articles: [
        {
          id: 'hostAffinity',
          name: 'Host: Affinity',
          img: 'event/goal_tutorial_affinity_complete',
          text: "Spending enough time using the same host will result in raising affinity with it. When you reach high enough affinity, you will open the possibility of conversation and acquiring host consent. Eventually the affinity will reach maximum and you will receive a message about it. The host name will have a green <span class=icon style='color:var(--text-color-symiosis)'>&#127280;</span> icon after it in the HUD in case of the maximum affinity. Leaving a host with full affinity will result in parasite losing some maximum energy. That reduction is small enough. However, if such host dies while the parasite is on it, the loss will be much higher. Therefore if you intend to lose the host, do not kill it. Note also, that hosts that have both full affinity and consent do not get alerted when they see the parasite. In fact, you can quickly hop onto such a host again after leaving them.",
        },
        {
          id: 'hostAssimilation',
          name: 'Host: Assimilation',
          img: 'imp/imp_assimilation',
          text: "Once you evolve the knowledge of microhabitats and create one, you can set up the assimilation cavity habitat growth inside. It allows you to assimilate the hosts making them way more adapted to the parasite's needs. In gameplay terms, assimilated hosts will not lose energy passively on movement, only when you do actions. You will have more control over them after you invade them. Plus they will restore the energy while being in a habitat if there is free biomineral energy available. Finally, they gain additional body feature and inventory slots.",
        },
        {
          id: 'hostAttributes',
          name: 'Host: Attributes',
          img: 'pedia/attributes',
          text: "Each host has four base attributes: strength, constitution, intellect and psyche. You can only find out the attributes for the host if you evolve the maximum level of brain probe and use it. Strength is used for calculating maximum health and energy values (so does the constitution). It also increases melee damage and limits the amount of inventory items. Finally, the host strength decreases the grip and paralysis efficiency and increases the speed with which they free from mucus. Constitution limits the amount of body features. Host intellect increases the efficiency with which the parasite learns the skills and human society knowledge when probing their brain. The remaining attribute, psyche, is a measure of their mental will. High host psyche increases the energy needed to probe their brain and reduces the efficiency of reinforcing control.",
        },
        {
          id: 'hostConversation',
          name: 'Host: Conversation',
          img: 'difficulty/chat',
          text: "<p>Having high affinity with the host opens up the conversation action. The main purpose of the conversation is to gain host consent. Maximum consent is marked with a green &#127282; icon in the HUD near the host name and makes significant changes to the gameplay. Firstly, the agreeable host uses way less energy to do some actions (and movement in region mode). Secondly, passive energy loss in area mode is reduced to zero, which essentially means that movement becomes free. Thirdly, the host control grows by itself every turn for agreeable hosts. Lastly, and most importantly, the host consent gives the parasite an ability to converse with humans using the mouth of the host. The second purpose of the consent is to open up secondary actions. Those include questioning for gathering clues, requesting items, consulting for learning skills, area alert de-escalation for police officers and subversion for the group members to raise the team distance (if you're bold enough to talk to them). Note that group members always have knowledge about some timeline event. Moreover, police officers will always have clues about the event if this area is an event location.</p>

<p>The conversation uses four skills: psychology, and three skills from the manipulation group: coaxing, coercion and deception. Each of the manipulative actions requires a successful roll to be used properly. Psychology is used to roll for Analyze action. This action will report a textual description of the interlocutor state giving hints on how to progress. Each NPC has a basic need and a character aspect. The need changes which actions are treated as positive or negative for gaining consent. The aspect makes further changes into the basic conversation routine.</p>

<p>Every conversation turn the list of actions is re-rolled. Each of the actions bound to the coaxing and deception skills usually increase or lower consent depending on the interlocutor need. For coaxing these are Assure, Discuss and Encourage actions. For deception skill the list is Distort, Flatter and Lie. There are four more actions in the coercion skill: Threaten, Scare and Shock. These do mostly the same thing if successful, they shake the interlocutor out of balance and act as a multiplier for the next manipulative action, whether the result was positive or negative. The remaining coercion action, Provoke, acts to reduce the conversation fatigue.</p>

<p>Some of the actions (especially the coercive ones) risk making the interlocutor emotional. In this case, some manipulative actions can be used to calm them down. If that does not happen, the emotion will become stronger and eventually result in a negative conversation outcome. Emotions behavior almost always depends on character aspects.</p>

<p>You cannot move or save during the conversation and it will be interrupted if something happens nearby putting it on a timeout. Reaching maximum fatigue will do the same thing. Note that during the conversation the AI is alerted using the same rules as before. However, positive and negative manipulative actions will respectively lower or raise the alertness of the interlocutor allowing them not to become alerted in case of successful conversation. The most important bit of knowledge is saved for last: during the conversation the parasite energy is always used instead of the host energy. That means that you can die during the conversation in the worst-case scenario. Have fun!</p>",
        },
        {
          id: 'hostExpiry',
          name: 'Host: Expiry',
          img: 'event/goal_tutorial_body_sewers_complete',
          text: "Once your host loses all their energy or health, they die. Death of a host is an important part of gameplay and you should plan for it accordingly. The best way to get rid of a dying host lies in the sewers. Their body will not be found and it won't raise any problems. On the other hand, leaving the body lying around in any area will inevitably lead to it being discovered which in turn raises the alert level of the location (which is visible in the region mode map). A body with extra features will also bring the attention of the Group.",
        },
        {
          id: 'hostInvading',
          name: 'Host: Invading',
          img: 'event/goal_invade_human_complete',
          text: "Once you attach the parasite to the potential host, you will need to subdue them struggling before invading. This is done through the repeated use of \"Harden Grip\" action that takes time and parasite energy. Normally you need to have the grip at full 100 before invading but if your energy is low enough, another action opens up that is called \"Early Invasion\". This makes the parasite to take a risky attempt with the host not fully subdued. In the case of failure the parasite will take damage. Actually, the parasite will take damage even in the case of success but less so.",
        },
        {
          id: 'keyboardShortcuts',
          name: 'Keyboard shortcuts',
          text: "Space - toggle HUD<br>
ESC/Enter - close any window, including message dialog<br>
NumPad - movement<br>
NumPad5, Z - wait a turn<br>
Alt+0-5 - equals F1-F5<br>
1-3 - pick option in message/difficulty/yes-no dialog. 1 is close/yes, 2 is no, in case of a difficulty choice it's left to right - easy, normal, hard<br>
; - opens console (used mostly for debug purposes), type \"help\" and press enter to see what commands are there in the normal build<br>",
        },
        {
          id: 'lifeParasite',
          name: 'Life of a Parasite',
          img: 'pedia/parasite',
          text: "You are a parasite of unknown origins. You can only survive for a little while without a host. Every action, every movement you make requires you to spend your energy which is in a short supply. Once it goes down to zero, it's game over. You need to find and gain control of a host you can use as a sort of a battery. The actions will then spend the host energy instead and the energy of the parasite will go up passively until it reaches maximum.",
        },
        {
          id: 'movement',
          name: 'Movement',
          text: "You can use the numpad or mouse for movement. Moving the mouse cursor around the screen you can see the path that you will take. Clicking the LMB on the screen will start the movement if it is possible. Note that you cannot click and move to the black tiles on the screen because what is actually on them is not known to you. Since movement requires energy, be careful or you might end up dead.",
        },
        {
          id: 'npcAlertness',
          name: 'NPCs: Alertness',
          img: 'event/goal_tutorial_alert_complete',
          text: "No humans or animals react particularly well when they see the parasite. A ? icon appears on top of them that can be either white, yellow or become a red !. This signifies the alertness status of an NPC. They have a limited vision and hearing and will react when their alertness rises. Once it reaches maximum (the red !), the NPC becomes fully aware that they're witnessing something weird and reacts accordingly by running away, calling the police or attacking you.",
        },
        {
          id: 'npcInteraction',
          name: 'NPCs: Interaction',
          text: "If you stand on the tile next to an NPC, you can use the keyboard to move to the tile they occupy. If the parasite is not attached to a host, then it will attach itself to the NPC at that point and the action menu will show you a list of context actions you can take. If you are already attached to a host and control them, your host will try to push the NPC away from that tile using their strength instead. You can use the mouse to click on the NPC for the same results with one exception. Clicking on the AI that is on the next tile with an active host will attack them with a melee weapon or bare hands (or claws). If your host has a ranged weapon then clicking on the AI at a distance will make an attack with that weapon.",
        },
      ],
    },

    {
      id: 'gameplay',
      name: 'GAMEPLAY',
      articles: [
        {
          id: 'eventTimeline',
          name: 'Event Timeline',
          img: 'pedia/timeline',
          text: "<p>Once you complete the tutorial, you get to the meat of the game - collecting clues to open up the timeline of events that have led to the present state. You can see the currently known events list in the Timeline window. Each event has a location, a text and NPC participants attached to it. Researching the more recent events through the clues allows you to open up earlier events until you get to the key event which will allow you to progress further into the final part of the game. Note that the events are numbered relatively to the first one known. Every event location is marked with a ? or + icon in the center on the regional map. In the first case, there are clues that you can gather in that area. The + icon means that you have already gathered everything you could.</p>

<p>There are two types of readable clues - short ones like documents and notes, and long ones like journals and books. The first type can be read anywhere while the second one requires being in a habitat but gives you more clues.</p>

<p>The other source of event clues are NPCs. They must first be researched themselves (their name, photo and location must be known) through other clues or computer research. Areas that contain known event NPCs are marked with a smiley icon. And once you research the NPC, their icon in the area mode will be marked with a smiley, too. You can find out what the NPC knows through the brain probe once you locate them in the area and invade.<p>

<p>Computer research (more like internet research) is a source of clues on NPCs. Due to it being an action requiring high concentration it can only be done in a habitat. You can leave the computer device lying there and, by the way, laptops are more efficient for research.</p>",
        },
        {
          id: 'evolution',
          name: 'Evolution',
          img: 'pedia/evolution',
          text: "To survive in the hostile world of humanity you will need to evolve new knowledge and improvements through the process of controlled evolution. You receive the starting set of basic improvements during the tutorial but the others you will have to hunt for. The list of available improvements and their cost to research is shown in the Evolution window. You can start and stop evolving at any time (there is even a static keyboard shortcut for it). In addition to spending the host's energy, evolution will slowly degrade the host. When the host is close to dying, you will receive a message: \"Your host degrades to a breaking point and might expire soon.\" It means that if you do not stop the process, the host might die right on the next turn. Whether to stop evolving or not at this point is entirely up to you.",
        },
        {
          id: 'habitat',
          name: 'Habitat',
          img: 'imp/imp_habitat',
          text: "Once you grow your first body feature, the parasite realizes that this dangerous process is better done inside of the habitat. This fact opens up the microhabitat knowledge improvement. There is a limit to the amount of habitats that the parasite can have active at any moment. There is also a total amount of habitats that can be created during a single game. Habitats can be created in any area of the game in the region mode with a special action. This does not require any resources and the empty habitat will already give you the ability to read journals and use computers to research event NPCs. To have further uses for a habitat, you must evolve and produce various habitat growths. Each growth mold is a body feature that upon activation converts the host into the habitat growth leaving the parasite without a host.",
        },
        {
          id: 'habitatCavity',
          name: 'Habitat: Assim. Cavity',
          img: 'imp/imp_assimilation',
          text: "The assimilation cavity can be used to turn the normal hosts into the assimilated ones. Assimilation is a process that makes the host more compatible with the needs of the parasite. The most important feature of assimilated hosts is that they do not lose the energy passively, only through actions. If the assimilated host is in a habitat with free energy available, their energy will be restored gradually. Also, assimilated hosts have more body features and inventory slots available and you will have more control over them after you invade.",
        },
        {
          id: 'habitatBiomineral',
          name: 'Habitat: Biomineral',
          img: 'imp/imp_biomineral',
          text: "Biomineral formation serves as a battery for your habitat. You can build multiple of these to gain more energy. Free energy will be used to restore the parasite energy and health, and if your host is assimilated, to restore their energy as well. In addition, free energy is used to increase the speed of organ growth and evolution. All these numbers can be seen in the log if you step on the biomineral.",
        },
        {
          id: 'habitatDestruction',
          name: 'Habitat: Destruction',
          img: 'pedia/habitat_destruction',
          text: "Habitats are not permanent. Once the active team for the Group gets onto your trail, they can find one of your habitats and put an ambush there. If it happens that you are inside, they might literally fall on top of your head. While it is possible to dispose of the attacking team members, this is not a certainty in any case. Moreover, the habitat will be destroyed even if you are successful. The destruction of the habitat is a highly painful process for the parasite. The most damaging result is that the maximum amount of energy for the parasite will be reduced permanently. The lowest possible amount varies according to the difficulty setting. ",
        },
        {
          id: 'habitatWatcher',
          name: 'Habitat: Watcher',
          img: 'imp/imp_watcher',
          text: "The primary responsibility of the watcher is to alert the parasite to any imminent ambushes within the habitat. Additionally, when the watcher reaches the second level, it gains the capability to actively draw the ambush towards its current location within the habitat, thereby serving a dual function of both detection and strategic diversion.",
        },
        {
          id: 'habitatPreservator',
          name: 'Habitat: Preservator',
          img: 'imp/imp_preservator',
          text: "The preservator growth is used to preserve the hosts in a habitat. The amount of hosts depends on the growth level. To preserve the host, move to any free spot near the growth and use the \"Preserve Host\" action that appears in the action list. Note that re-attaching to preserved hosts is much more smooth than to free ones. In addition, if the host is assimilated, the initial control value will be much higher.",
        },
        {
          id: 'hostOrgans',
          name: 'Host: Body Features',
          img: 'pedia/organs',
          text: "Some of the improvements you evolve will allow you to grow additional organs and body features on the host. You can see the list of body features and start growing new ones in the Body window. These features each give a unique ingame advantage, whether offensive, defensive or utilitarian. Feature growth like everything else requires host energy and you might end up with a half-dead host after you finish growing the feature you desire (or even with a dead one that has died in the process). Moreover, you cannot stop the growth process once started, unlike evolution. That is why growing is best done in the safety of a habitat. There are limits to the amount of features on a host, too.",
        },
        {
          id: 'hostBrainProbe',
          name: 'Host: Brain Probe',
          img: 'imp/imp_brain_probe',
          text: "One of the earliest and heavily used tools in your arsenal, the brain probe allows the parasite to access the brain of the host gaining access to all sorts of knowledge in return for spending a lot of their energy and some of their health. You can kill your host with enough probes if you're not careful (and, in fact, that is in itself useful at various times). The basic probe of first level returns the name of the host, some human society knowledge and some event timeline clues if the host is involved in the conspiracy. The second level of the probe opens up access to host skills and knowledges. And the last level shows numerical values for host attributes and lists their traits if there are any.",
        },
        {
          id: 'hostInventory',
          name: 'Host: Inventory',
          img: 'event/goal_probe_brain_complete',
          text: "NPCs possess inventory and when the parasite controls a host, it can be used. The inventory items are visible in the Body window. Each of the items needs to be learned about using the host brain before using. You can drop items to the ground if you wish to. Weapons will be used in the main window, and clues can be read in the Body window, just like the computer devices can be used there for research.",
        },
        {
          id: 'hostSkills',
          name: 'Host: Skills',
          img: 'event/goal_learn_items_complete',
          text: "Every host has an assortment of skills and knowledges. You can read their list in the Body window. Some have unique traits that are useful for you. While probing their brains you can learn what the hosts know. Some of the skills and knowledges are situational, others will be used more often. Knowledges are binary but skills are on a 1-100 scale and when used, the success is determined through the percentage roll. There is a special knowledge of human society that every human NPC possesses which will be used in the early part of game.",
        },
        {
          id: 'msgConcentration',
          name: '<i>It requires immense concentration and time</i>',
          font: 90,
          text: "This message will appear in the log if you try to do something that must be done in a habitat, like access a computer device or read a long readable (a journal or a book of some kind).",
        },
        {
          id: 'impOvum',
          name: 'Parthenogenesis',
          img: 'imp/imp_ovum',
          text: "<p>After you evolve the Parthenogenesis improvement, the parasite gains access to the rebirth process. Normally, if it dies, it's game over but if you have the rebirth set up, the parasite will just move on to the \"next life\" with some losses. The first thing you need is to create the ovum object in region mode. It is a process similar to the microhabitat spawning. Go to the nearest sewers, pick a good spot on region map and activate the \"Create ovum\" action. Pick the place carefully because you will need to travel there to change settings and the parasite will be reborn there each time. The ovum itself is not in any danger from the antagonists at the moment and you can only build one.</p>

<p>Once the ovum is created, stepping on its tile will show you the info about its level and what improvements are marked for rebirth. There are two actions available. \"Set improvements\" opens the interface to lock and unlock which of the basic improvements you want to be reborn with. The second action, \"Nurture ovum\", allows you to feed your current host to the ovum, adding points to the next level. Each new level requires more points and there is a maximum ovum level. Different types of hosts will give you different amount of points. In general, the more dangerous the host type is, the more points the ovum will receive.</p>

<p>The rebirth process happens automatically on parasite death. At this point a new parasite will appear on the ovum location. The ovum level will be reduced by one. If the current ovum level is zero, it is the final death and game over. The basic improvements that were locked will stay with you, the rest will be discarded and you will receive another set of starting improvements. The basic improvements are the ones that can be received when you first open the evolution process in tutorial. All the ones that you've acquired during the gameplay after that will not be discarded. However, there is a large chance that some of them will degrade by one level to a minimum of one. Any evolution points that you've gained over the current improvement level will also be reset.</p>",
        },
        {
          id: 'regionMode',
          name: 'Region Mode',
          img: 'pedia/region',
          text: "<p>After you first get into the sewers through the sewers hatch, the game switches into the region mode. Every area you can visit becomes a single tile on a grid. Time passes much faster in this mode, so your host can die quickly leaving you bare. In that case get out of the sewers with the \"Enter Area\" action and find another one. The movement is done the same way as in the area mode, with mouse and keyboard. Note that some areas have a colored ? symbol in the corner (or red ! in some cases). This shows the area alertness. High alertness increases police activity and the amount of armed civilians. If the alertness is close to maximum, you cannot enter this area until it subsides. Every turn the alertness lowers until the area is completely calm.</p>

<p>Some areas might be marked with a ? icon in a gray circle in the middle. This means that the area has clues to the event timeline that you can find. When you gather all the clues in the area, this icon changes to +. If the area has a smiley icon in the upper left corner, it means that there are one or more event NPCs there.</p>",
        },
        {
          id: 'sandboxMode',
          name: 'Sandbox Mode',
          text: "You can start the game in sandbox mode instead of the scenario. In this case event timeline is disabled and after you finish the tutorial, you're free to run around the city and do as you will. Clues, clue-related items and event NPCs do not spawn anywhere. There is no defined ending to the game as well. The Group still sends their operatives after you according to normal rules.",
        },
        {
          id: 'spoonMode',
          name: 'Spoon Mode',
          img: 'pedia/spoon',
          text: "The spoon mode is hidden in the options menu. It contains various flags and tweaks that can drastically change the gameplay from the intended one. Once it is activated, you cannot turn it off for the current game, it is considered irreversibly spooned. To activate the spoon mode, you need to click the letters in the OPTIONS title of the options window to form the word SPOON. Have fun!",
        },
        {
          id: 'msgWatching',
          name: '<i>You feel someone is watching</i>',
          font: 90,
          text: "This message appears when you linger too much in one area and the Group is on your trail. You need to get out of there or you risk being ambushed.",
        },
      ],
    },

    {
      id: 'areas',
      name: 'AREAS',
      articles: [
        {
          id: 'areaCity',
          name: 'City Area',
          img: 'pedia/area_city',
          text: "The city is divided into three distinct area types based on density: low, medium, and high. Low-density areas feature minimal civilian presence and limited police patrols, creating a calm and safe environment for the parasite. Medium-density areas exhibit moderate pedestrian traffic and a balanced police presence, ensuring orderly activity. High-density areas are characterized by high pedestrian volumes and frequent police patrols, maintaining security in a bustling urban setting. These are most dangerous and entering the high density area will give the parasite an idea...",
        },
        {
          id: 'areaHighCrime',
          name: 'High Crime Area',
          text: "<p>High-crime blocks are choked with uncollected garbage, broken glass and improvised burn barrels. The air is foul and the inhabitants are the city's undesirables: bums staking out doorways, armed thugs guarding their corners and prostitutes trying to survive another night.</p>

<p>The thugs are aggressive and respond immediately if attacked, escalating to lethal force without hesitation. Police patrols are almost non-existent and even if someone manages to call them, the response rarely materializes.</p>",
        },
        {
          id: 'areaCorp',
          name: 'Corporate HQ',
          img: 'pedia/area_corphq',
          text: "The corporate headquarters floor is a dynamic environment populated by office workers and management. The parasite begins its operations from the elevator, providing a strategic point of entry. Both the elevator and stairs are available for efficient egress, allowing it to navigate the area with agility. Some of the doors might be locked electronically, adding an additional layer of complexity to the environment.",
        },
        {
          id: 'areaMilitary',
          name: 'Military Base',
          img: 'pedia/area_military',
          text: "All military base areas are actively patrolled by soldiers and officers, ensuring a constant state of vigilance and security. The presence of well-trained personnel underscores the importance of maintaining order and readiness at all times. Routine inspections and drills are conducted to ensure that protocols are strictly followed, contributing to the overall efficiency and preparedness of the base. This disciplined environment is crucial for the effective operation and rapid response capabilities of the military.",
        },
        {
          id: 'areaLab',
          name: 'Research Facility',
          img: 'pedia/area_lab',
          text: "The laboratories and research facilities are primarily populated with sophisticated lab equipment and highly skilled scientists, all working diligently on advanced projects. Security personnel maintain a vigilant presence, patrolling the premises to ensure the safety and integrity of the sensitive research being conducted. These facilities are designed to foster innovation while adhering to stringent safety and security protocols.",
        },
        {
          id: 'areaUninhabited',
          name: 'Uninhabited Area',
          img: 'pedia/area_uninhabited',
          text: "The uninhabited area consists solely of greenery, providing a natural space without any residential or commercial development. This area supports various plant species and serves as a crucial part of the local ecosystem. Its preservation is important for maintaining environmental balance and biodiversity. The lack of human activity helps ensure that the area remains undisturbed and protected. Be careful, there are no hosts wandering around.",
        },
      ],
    },

    {
      id: 'hud',
      name: 'HUD',
      articles: [
        {
          id: 'hudActions',
          name: 'Actions List',
          text: "This HUD window shows a list of context-appropriate actions with the keyboard shortcuts on the left. Some actions have static keyboard shortcuts that do not change. The others will be attached to 1-9 keys dynamically. Every action can have an energy cost and it will be indicated in the list. If you press and hold the Shift key, you will see that some actions will change their shortcut to S-[number]. This means that this action is repeatable and pressing its number with the Shift key modifier held will repeat it until the special action-related condition will be met. For example, repeating the Harden Grip action will stop when it reaches maximum grip, and so on. Note that the brain probe can kill the host when repeated.",
        },
        {
          id: 'hudGoals',
          name: 'Goals List',
          text: "This HUD window shows a list of currently active goals with the optional ones marked. Some of the goals might feature additional information.",
        },
        {
          id: 'hudInfoParasite',
          name: 'Info: Parasite',
          text: "When the parasite is running around without a host, the information window is shortened to display the common information and its stats. The first line has the following information: turns passed since game start, current sub-turn number in square brackets (1 or 2 since parasite is always twice as fast as the NPCs), and x, y position in the area or region, depending on the current mode. The next line in the region mode shows the name of the area. After the separator the parasite stats begin: energy line, which shows the current and max energy and energy spend/increase per turn in square brackets. The next line shows the current and maximum parasite health. When the parasite is attached to a host but have not yet invaded it, the next line shows the current and maximum grip values.",
        },
        {
          id: 'hudInfoHost',
          name: 'Info: Host',
          text: "When the parasite is controlling a host, the information window becomes bigger and adds the following information after another separator: the host type or name if it is known, host attributes (if they were brain probed by the maximum level probe), current and maximum host health values, current and maximum control values, and energy values. The energy line has host energy increase or spend and turns left to live with the current spending in the square brackets. If you're currently evolving, the evolution direction and turns left will be shown next. If you're growing a body feature, it will be shown next with turns left to completion.",
        },
        {
          id: 'hudLog',
          name: 'Log',
          text: "The HUD log window by default shows the last six messages. Don't forget to read the messages, they will give you a lot of background or important information. Especially the lines marked by red color. These are really important and can easily lead to the parasite getting killed so be sure to read them.",
        },
      ],
    },

    {
      id: 'group',
      name: 'GROUP',
      articles: [
        {
          id: 'groupBasics',
          groupAddFlag: true,
          name: 'Group: Basics',
          img: 'pedia/group',
          text: "So, you've just found out about the existence of the group of humans that are actively trying to destroy you. For the simplicity's sake we're gonna call them the Group onwards. This concept requires some explanation since the mechanic is complex enough and mostly hidden. Selecting the difficulty level will change the amount of information available to the player in the skills and knowledges section of the Body window. Choosing easy difficulty will show concrete numbers, normal difficulty will use word descriptions and hard difficulty will not show anything at all.",
        },
        {
          id: 'groupPriority',
          groupAddFlag: true,
          name: 'Group: Priority',
          img: 'pedia/group_priority',
          text: "The Group is a government conspiracy dedicated to protecting the ordinary citizens from all sorts of unconventional threats: extraterrestrial, paranormal, Mythos, etc. The main game parameter of the Group is \"priority\". That is the priority of parasite threat. Since there are a lot of other threats that the Group has to deal with and its resources are limited (contrary to popular belief), the priority is low at start. Right from the beginning of the game some of the player's actions will raise the priority. The examples of such actions are: someone sees the parasite and alerts the police, body with anomalies was found or the former host runs away and tells everybody that they were possessed by an alien creature. The severity of each action is different but the priority rises.",
        },
        {
          id: 'teamAmbush',
          groupAddFlag: true,
          name: 'Team: Ambush',
          img: 'pedia/team_ambush',
          text: "<p>Once the team distance is sufficiently low, the team will discover one of your habitats if you have them. At this point the team will hide in an ambush. They will wait for some time and then just burn everything cowboy style. Destruction of the habitat is a deeply traumatic event for the parasite and reduces its maximum energy permanently with more temporary drawbacks. If you walk into an ambush, the fight starts. You need to survive for three turns before you can leave the ambushed habitat. Leaving the habitat will also result in its immediate destruction. The only positive thing about this event is that it will increase the team distance giving you some breathing room.</p>

<p>Killing the ambushers, while possible, is very hard to manage. In this case the habitat will not be destroyed. Instead, the group priority increases but the team timeout restarts. Note that if you don't have any habitats, the logic stays the same, except that the ambush will now happen right on the city street and ambush evasion will result in the same distance increase as when you escape from the habitat ambush.</p>",
        },
        {
          id: 'teamBasics',
          groupAddFlag: true,
          name: 'Team: Basics',
          img: 'pedia/team_basics',
          text: "<p>The priority determines the level of the team of agents that the Group will task with the parasite problem. At the beginning of the game the player has some downtime until the team is spawned and each team wipe will also result in downtime. Once the team is activated, its members will start investigating the weird phenomena and occurences, and instead of raising the Group priority, the described player actions will count towards decreasing the distance between the team and the player. The longer the time the player spends in a given area, the more is the chance of one of the team members spawning around.</p>

<p>Once the team member sees the player, the following message will be shown in a log: \"You feel someone is watching.\" This means that one of the NPCs currently visible on screen is a team member. At this point the best thing to do is to leave the area. If the team member is not alerted after seeing the player and despawns, this counts as evasion. Evading team members raises the distance to the team a little.</p>",
        },
        {
          id: 'teamDeactivation',
          groupAddFlag: true,
          img: 'pedia/team_deactivation',
          name: 'Team: Deactivation',
          text: "Once the distance is raised to a large number, the team is deactivated, the group priority is decreased and the downtime starts. Basically, the threat is considered to be low by the Group and it stops worrying about the parasite for some time. Then again, you're free to attack the team member or possess them. Be prepared for some blackops backup, though. Killing the team member reduces the active team size but increases the group priority. Wiping the whole team out still gives you some downtime but decreases the starting distance of the next team.",
        },
        {
          id: 'impFalseMemories',
          name: 'Pseudocampus',
          img: 'imp/imp_false_memories',
          text: 'Pseudocampus body feature allows the parasite to implant false memories into the host brain and then safely detach from the host confusing them for a short period of time. If you manage to get away before they become alert, it will be the safest option for your survival. In case of the host being a Group team agent, this will also result in a team distance increase. Blackops agents give double the usual bonus. Note that if the rest of the team was wiped at the time of planting false memories, the team timeout increases instead.',
        },
      ],
    },
  ];

// get article name by id
  public static function getName(id: String): String
    {
      for (g in contents)
        for (a in g.articles)
          if (a.id == id)
            return a.name;
      return null;
    }

// get article by id
  public static function getArticle(id: String): _PediaArticleInfo
    {
      for (g in contents)
        for (a in g.articles)
          if (a.id == id)
            return a;
      return null;
    }

// get group by id
  public static function getGroup(id: String): _PediaGroupInfo
    {
      for (g in contents)
        if (g.id == id)
          return g;
      return null;
    }
}

typedef _PediaGroupInfo = {
  var id: String;
  var name: String;
  var articles: Array<_PediaArticleInfo>;
}

typedef _PediaArticleInfo = {
  var id: String;
  var name: String;
  @:optional var img: String;
  var text: String;
  @:optional var groupAddFlag: Bool; // open with all group articles?
  @:optional var font: Int;
}
