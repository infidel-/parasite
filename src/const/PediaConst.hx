package const;

class PediaConst
{
  public static var contents: Array<_PediaGroupInfo> = [
    {
      name: 'BASICS',
      articles: [
        {
          name: 'Host: Assimilation',
          text: "Once you evolve the knowledge of microhabitats and create one, you can set up the assimilation cavity habitat growth inside. It allows you to assimilate the hosts making them way more adapted to the parasite's needs. In gameplay terms, assimilated hosts will not lose energy passively on movement, only when you do actions. Plus they will restore the energy while being in a habitat if there is free biomineral energy available. Finally, they gain additional body feature and inventory slots.",
        },
        {
          name: 'Host: Attributes',
          text: "Each host has four base attributes: strength, constitution, intellect and psyche. You can only find out the attributes for the host if you evolve the maximum level of brain probe and use it. Strength is used for calculating maximum health and energy values (so does the constitution). It also increases melee damage and limits the amount of inventory items. Finally, the host strength decreases the grip and paralysis efficiency and increases the speed with which they free from mucus. Constitution limits the amount of body features. Host intellect increases the efficiency with which the parasite learns the skills and human society knowledge when probing their brain. The remaining attribute, psyche, is a measure of their mental will. High host psyche increases the energy needed to probe their brain and reduces the efficiency of reinforcing control.",
        },
        {
          name: 'Host: Expiry',
          text: "Once your host loses all their energy or health, they die. Death of a host is an important part of gameplay and you should plan for it accordingly. The best way to get rid of a dying host lies in the sewers. Their body will not be found and it won't raise any problems. On the other hand, leaving the body lying around in any area will inevitably lead to it being discovered which in turn raises the alert level of the location (which is visible in the region mode map). A body with extra features will also bring the attention of the Group.",
        },
        {
          name: 'Host: Invading',
          text: "Once you attach the parasite to the potential host, you need to subdue them struggling before invading. This is done through the repeated use of \"Harden Grip\" action that takes time and parasite energy. Normally you need to have the grip at full 100 before invading but if your energy is low enough, another action opens up that is called \"Early Invasion\". This makes the parasite to take a risky attempt with the host not fully subdued. In the case of failure the parasite will take damage. Actually, the parasite will take damage even in the case of success but less so.",
        },
        {
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
          name: 'Life of a Parasite',
          text: "You are a parasite of unknown origins. You can only survive for a little while without a host. Every action, every movement you make requires you to spend your energy which is in a short supply. Once it goes down to zero, it's game over. You need to find and gain control of a host you can use as a sort of a battery. The actions will then spend the host energy instead and the energy of the parasite will go up passively until it reaches maximum.",
        },
        {
          name: 'Movement',
          text: "You can use the numpad or mouse for movement. Moving the mouse cursor around the screen you can see the path that you will take. Clicking the LMB on the screen will start the movement if it is possible. Note that you cannot click and move to the black tiles on the screen. Since movement requires energy, be careful or you might end up dead.",
        },
        {
          name: 'NPCs: Alertness',
          text: "No humans or animals react particularly well when they see the parasite. A ? icon appears on top of them that can be either white, yellow or become a red !. This signifies the alertness status of an NPC. They have a limited vision and hearing and will react when their alertness rises. Once it reaches max (the red !), the NPC is fully aware that they witness something weird and reacts accordingly by running away, calling the police or attacking you.",
        },
        {
          name: 'NPCs: Interaction',
          text: "If you stand on the tile next to an NPC, you can use the keyboard to move to the tile they occupy. If the parasite is not attached to a host, then it will attach itself to the NPC at that point and the action menu will show you a list of context actions you can take. If you are already attached to a host and control them, your host will try to push the NPC away from that tile using their strength instead. You can use the mouse to click on the NPC for the same results with one exception. Clicking on the AI that is on the next tile with an active host will attack them with a melee weapon or bare hands (or claws). If your host has a ranged weapon then clicking on the AI at a distance will make an attack with that weapon.",
        },
      ],
    },

    {
      name: 'GAMEPLAY',
      articles: [
        {
          name: 'Event Timeline',
          text: "<p>Once you complete the tutorial, you get to the meat of the game - collecting clues to open up the timeline of events that have led to the present state. You can see the currently known events list in the Timeline window. Each event has a location, a text and NPC participants attached to it. Researching the more recent events through the clues allows you to open up earlier events until you get to the key event which will allow you to progress further into the final part of the game. Note that the events are numbered relatively to the first one known. Every event location is marked with a ? or + icon in the center on the regional map. In the first case, there are clues that you can gather in that area. The + icon means that you have already gathered everything you could.</p>

<p>There are two types of readable clues - short ones like documents and notes, and long ones like journals and books. The first type can be read anywhere while the second one requires being in a habitat but gives more clues.</p>

<p>The other source of event clues are NPCs. They must first be researched themselves (their name, photo and location must be known) through other clues or computer research. Areas that contain known event NPCs are marked with a smiley icon. And once you research the NPC, their icon in the area mode will be marked with a smiley, too. You can find out what the NPC knows through the brain probe once you locate them in the area and invade.<p>

<p>Computer research (more like internet research) is a source of clues on NPCs. Due to it being an action requiring high concentration it can only be done in a habitat. You can leave the computer device lying there and, by the way, laptops are more efficient for research.</p>",
        },
        {
          name: 'Evolution',
          text: "To survive in the hostile world of humanity you will need to evolve new knowledge and improvements through the process of controlled evolution. You receive the starting set of basic improvements during the tutorial but the others you will have to hunt for. The list of available improvements and their cost to research is shown in the Evolution window. You can start and stop evolving at any time (there is even a static keyboard shortcut for it). In addition to spending the host's energy, evolution will slowly degrade the host. When the host is close to dying, you will receive a message: \"Your host degrades to a breaking point and might expire soon.\" It means that if you do not stop the process, the host might die right on the next turn. Whether to stop evolving or not is entirely up to you.",
        },
        {
          name: 'Habitat',
          text: "Once you grow your first body feature, the parasite realizes that this dangerous process is better done inside of the habitat. This fact opens up the microhabitat knowledge improvement. There is a limit to the amount of habitats that the parasite can have active at any moment. There is also a total amount of habitats that can be created during a single game. Habitats can be created in any area of the game in the region mode with a special action. This does not require any resources and the empty habitat will already give you the ability to read journals and use computers to research event NPCs. To have further uses for a habitat, you must evolve and produce various habitat growths. Each growth mold is a body feature that upon activation converts the host into the habitat growth leaving the parasite without a host.",
        },
        {
          name: 'Habitat: Assim. Cavity',
          text: "The assimilation cavity can be used to turn the normal hosts into the assimilated ones. Assimilation is a process that makes the host more compatible with the needs of the parasite. The most important feature of assimilated hosts is that they do not lose the energy passively, only through actions. If the assimilated host is in a habitat with free energy available, their energy will be restored gradually. Also, assimilated hosts have more body features and inventory slots available.",
        },
        {
          name: 'Habitat: Biomineral',
          text: "Biomineral formation serves as a battery for your habitat. You can build multiple of these to gain more energy. Free energy will be used to restore the parasite energy and health, and if your host is assimilated, to restore their energy as well. In addition, free energy is used to increase the speed of organ growth and evolution. All these numbers can be seen in the log if you step on the biomineral.",
        },
        {
          name: 'Habitat: Destruction',
          text: "Habitats are not permanent. Once the active team for the Group gets onto your trail, they can find one of your habitats and put an ambush there. If it happens that you are inside, they might literally fall on top of your head. While it is possible to dispose of the attacking team members, this is not a certainty in any case. Moreover, the habitat will be destroyed even if you are successful. The destruction of the habitat is a highly painful process for the parasite. The most damaging result is that the maximum amount of energy for the parasite will be reduced permanently. The lowest possible amount varies according to the difficulty setting. ",
        },
        {
          name: 'Habitat: Watcher',
          text: "The primary task of the watcher is to notify the parasite about an ambush in the habitat. When the watcher is of the second level, it can also attract the ambush to the habitat that it is located in.",
        },
        {
          name: 'Host: Body Features',
          text: "Some of the improvements you evolve will allow you to grow additional organs and body features on the host. You can see the list of body features and start growing new ones in the Body window. These features each give a unique ingame advantage, whether offensive, defensive or utilitarian. Feature growth like everything else requires host energy and you might end up with a half-dead host after you finish growing the feature you desire (or even with a dead one that has died in the process). Moreover, you cannot stop the growth process once started, unlike evolution. That is why growing is best done in the safety of a habitat. There are limits to the amount of features on a host, too.",
        },
        {
          name: 'Host: Brain Probe',
          text: "One of the earliest and heavily used tools in your arsenal, the brain probe allows the parasite to access the brain of the host gaining access to all sorts of knowledge in return for spending a lot of their energy and some of their health. You can kill your host with enough probes if you're not careful (and, in fact, that is in itself useful at various times). The basic probe of first level returns the name of the host, some human society knowledge and some event timeline clues if the host is involved in the conspiracy. The second level of the probe opens up access to host skills and knowledges. And the last level shows numerical values for host attributes and lists their traits if there are any.",
        },
        {
          name: 'Host: Inventory',
          text: "NPCs possess inventory and when the parasite controls a host, it can be used. The inventory items are visible in the Body window. Each of the items needs to be learned about using the host brain before using. You can drop items to the ground if you wish to. Weapons will be used in the main window, and clues can be read in the Body window, just like the computer devices can be used there for research.",
        },
        {
          name: 'Host: Skills',
          text: "Every host has an assortment of skills and knowledges. You can read their list in the Body window. Some have unique traits that are useful for you. While probing their brains you can learn what the hosts know. Some of the skills and knowledges are situational, others will be used more often. Knowledges are binary but skills are on a 1-100 scale and when used, the success is determined through the percentage roll. There is a special knowledge of human society that every human NPC possesses which will be used in the early part of game.",
        },
        {
          name: 'It Requires Immense Concentration And Time',
          font: 90,
          text: "This message will appear in the log if you try to do something that must be done in a habitat, like access a computer device or read a long readable (a journal or a book of some kind).",
        },
        {
          name: 'Region Mode',
          text: "<p>After you first get into the sewers through the sewers hatch, the game switches into the region mode. Every area you can visit becomes a single tile on a grid. Time passes much faster in this mode, so your host can die quickly leaving you bare. In that case get out of the sewers with the \"Enter Area\" action and find another one. The movement is done the same way as in the area mode, with mouse and keyboard. Note that some areas have a colored ? symbol in the corner (or red ! in some cases). This shows the area alertness. High alertness increases police activity and the amount of armed civilians. If the alertness is close to maximum, you cannot enter this area until it subsides. Every turn the alertness lowers until the area is completely calm.</p>

<p>Some areas might be marked with a ? icon in a gray circle in the middle. This means that the area has clues to the event timeline that you can find. When you gather all the clues in the area, this icon changes to +. If the area has a smiley icon in the upper left corner, it means that there are one or more event NPCs there.</p>",
        },
        {
          name: 'Spoon Mode',
          text: "The spoon mode is hidden in the options menu. It contains various flags and tweaks that can drastically change the gameplay from the intended one. Once it is activated, you cannot turn it off for the current game, it is considered irreversibly spooned. To activate the spoon mode, you need to click the letters in the OPTIONS title of the options window to form the word SPOON. Have fun!",
        },
      ],
    },

    {
      name: 'AREAS',
      articles: [
        {
          name: 'City Area',
          text: "This is a generic city area that can be of low, medium or high density. The density will change the amount of civilians and police wandering around. Entering the high density area will give the parasite an idea...",
        },
        {
          name: 'Habitat',
          text: "Habitats are safe areas for the parasite to rest, regain energy and build up its strength. They can also be used to assimilate hosts and research clues through the use of computer devices or books.",
        },
        {
          name: 'Laboratory',
          text: "The laboratories and research facilities mostly contain lab equipment and scientists with security patrolling around.",
        },
        {
          name: 'Military Base',
          text: "All military bases have soldiers and officers walking around.",
        },
        {
          name: 'Uninhabited Area',
          text: "This type of area only contains greenery. Be careful, there are no hosts wandering around.",
        },
      ],
    },

    {
      name: 'HUD',
      articles: [
        {
          name: 'Actions List',
          text: "This HUD window shows a list of context-appropriate actions with the keyboard shortcuts on the left. Some actions have static keyboard shortcuts that do not change. The others will be attached to 1-9 keys dynamically. Every action can have an energy cost and it will be indicated in the list. If you press and hold the Shift key, you will see that some actions will change their shortcut to S-[number]. This means that this action is repeatable and pressing its number with the Shift key modifier held will repeat it until the special action-related condition will be met. For example, repeating the Harden Grip action will stop when it reaches maximum grip, and so on. Note that the brain probe can kill the host when repeated.",
        },
        {
          name: 'Goals List',
          text: "This HUD window shows a list of currently active goals with the optional ones marked. Some of the goals might feature additional information.",
        },
        {
          name: 'Info: Parasite',
          text: "When the parasite is running around without a host, the information window is shortened to display the common information and its stats. The first line has the following information: turns passed since game start, current sub-turn number in square brackets (1 or 2 since parasite is always twice as fast as the NPCs), and x, y position in the area or region, depending on the current mode. The next line in the region mode shows the name of the area. After the separator the parasite stats begin: energy line, which shows the current and max energy and energy spend/increase per turn in square brackets. The next line shows the current and maximum parasite health. When the parasite is attached to a host but have not yet invaded it, the next line shows the current and maximum grip values.",
        },
        {
          name: 'Info: Host',
          text: "When the parasite is controlling a host, the information window becomes bigger and adds the following information after another separator: the host type or name if it is known, host attributes (if they were brain probed by the maximum level probe), current and maximum host health values, current and maximum control values, and energy values. The energy line has host energy increase or spend and turns left to live with the current spending in the square brackets. If you're currently evolving, the evolution direction and turns left will be shown next. If you're growing a body feature, it will be shown next with turns left to completion.",
        },
        {
          name: 'Log',
          text: "The HUD log window by default shows the last six messages. Don't forget to read the messages, they will give you a lot of background or important information. Especially the lines marked by red color. These are really important and can easily lead to the parasite getting killed so be sure to read them.",
        },
      ],
    },

    {
      name: 'GROUP',
      articles: [
        {
          name: 'Basics',
          text: "So, you've just found out about the existence of group of humans that are actively trying to destroy you. For the simplicity's sake we're gonna call them the group onwards. This concept requires some explanation since the mechanic is complex enough and mostly hidden. Selecting the difficulty level will change the amount of information available to the player in the skills and knowledges section of the Body window. Choosing easy difficulty will show concrete numbers, normal difficulty will use word descriptions and hard difficulty will not show anything at all.",
        },
        {
          name: 'Group Priority',
          text: "The group is a government conspiracy dedicated to protecting the ordinary citizens from all sorts of unconventional threats: extraterrestrial, paranormal, Mythos, etc. The main game parameter of the group is \"priority\". That is the priority of parasite threat. Since there are a lot of other threats that the group has to deal with and its resources are limited (contrary to popular belief ;)), the priority is low at start. Right from the beginning of the game some of the player's actions will raise the priority. The examples of such actions are: someone sees the parasite and alerts the police, body with anomalies was found or the former host runs away and tells everybody that they were possessed by an alien creature. The severity of each action is different but the priority rises.",
        },
        {
          name: 'Team: Ambush',
          text: "Once the team distance is sufficiently low, the team will discover one of your habitats if you have them. At this point the team will hide in an ambush. They will wait for some time and then just burn everything cowboy style. Destruction of the habitat is a deeply traumatic event for the parasite and reduces its maximum energy permanently with more temporary drawbacks. If you walk into an ambush, the fight starts. You need to survive for three turns before you can leave the ambushed habitat. Leaving the habitat will also result in its immediate destruction. The only positive thing about this event is that it will increase the team distance giving you some breathing room. Killing the ambushers, while possible, will still result in the habitat destruction. Note that if you don't have any habitats, the logic stays the same, except that the ambush will spawn right on the city streets and ambush evasion will result in a smaller downtime.",
        },
        {
          name: 'Team: Basics',
          text: "<p>The priority determines the level of the team of agents that the group will task with the parasite problem. At the beginning of the game the player has some downtime until the team is spawned and each team wipe will also result in downtime. Once the team is activated, its members will start investigating the weird phenomena and occurences, and instead of raising the group priority, the described player actions will count towards decreasing the distance between the team and the player. The longer the time the player spends in a given area, the more is the chance of one of the team members spawning around.</p>

<p>Once the team member sees the player, the following message will be shown in a log: \"You feel someone is watching.\" This means that one of the NPCs currently visible on screen is a team member. At this point the best thing to do is to leave the area. If the team member is not alerted after seeing the player and despawns, this counts as evasion. Evading team members raises the distance to the team a little.</p>",
        },
        {
          name: 'Team: Deactivation',
          text: "Once the distance is raised to a large number, the team is deactivated, the group priority is decreased and the downtime starts. Basically, the threat is considered to be low by the group and it stops worrying about the parasite for some time. Then again, you're free to attack the team member or possess them. Be prepared for some blackops backup, though. Killing the team member reduces the active team size but increases the group priority. Wiping the whole team out still gives you some downtime but decreases the starting distance of the next team.",
        },
      ],
    },
  ];
}

typedef _PediaGroupInfo = {
  var name: String;
  var articles: Array<_PediaArticleInfo>;
}

typedef _PediaArticleInfo = {
  var name: String;
  var text: String;
  @:optional var font: Int;
}
