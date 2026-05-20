// console tab-completion + redis-style inline hints
package console;

import mods.ModRegistry;

// one grammar node: either a literal token (lit) or a value slot (slot).
// next = alternatives for the following token position.
typedef CompNode =
{
  ?lit: String,                    // literal keyword token
  ?slot: String,                   // value-slot placeholder display (e.g. "[index]")
  ?values: Void -> Array<String>,  // candidate provider for completing this slot
  ?next: Array<CompNode>,          // following-position alternatives
}

// result of a completion attempt
typedef CompResult =
{
  value: String,         // new input text (unchanged if nothing to complete)
  list: Array<String>,   // candidate list to display when ambiguous (empty otherwise)
}

class ConsoleCompletion
{
  var console: Console;
  var root: CompNode;

// builds the command grammar tree
  public function new(c: Console)
    {
      console = c;
      // value providers pulling live entry/name lists
      var effect = function() return console.giveConsole.names('effect');
      var item = function() return console.giveConsole.names('item');
      var organ = function() return console.giveConsole.names('organ');
      var skill = function() return console.giveConsole.names('skill');
      var trait = function() return console.giveConsole.names('trait');
      var improv = function() return console.giveConsole.names('evolution');
      var modIDs = function()
        {
          var out = [];
          for (m in ModRegistry.all)
            out.push(m.id);
          return out;
        };
      var goalIDs = function()
        {
          var out = [];
          for (g in const.Goals.map.keys())
            out.push(Goal.displayID(g));
          return out;
        };
      // only the player's current (active) goals — the completable set
      var currentGoalIDs = function()
        {
          var out = [];
          for (g in console.game.goals.iteratorCurrent())
            out.push(Goal.displayID(g));
          return out;
        };

      var debugSubs: Array<CompNode> = [
        { lit: 'renderstats' },
        { lit: 'ai' },
        { lit: 'sound' },
        { lit: 'lights' },
#if mydebug
        { lit: 'alert' },
        { lit: 'demo' },
        { lit: 'leave' },
        { lit: 'throw' },
#end
      ];

      root = { next: [
        { lit: 'give', next: [
          { lit: 'effect', next: [ { slot: '[effect]', values: effect } ] },
          { lit: 'item', next: [ { slot: '[item]', values: item } ] },
          { lit: 'organ', next: [ { slot: '[organ]', values: organ } ] },
          { lit: 'skill', next: [ { slot: '[skill]', values: skill, next: [ { slot: '[amount]' } ] } ] },
          { lit: 'trait', next: [ { slot: '[trait]', values: trait } ] },
          { lit: 'evolution', next: [ { slot: '[name]', values: improv, next: [ { slot: '[level]' } ] } ] },
        ] },
        { lit: 'go', next: [
          { lit: 'area', next: [ { slot: '[x]', next: [ { slot: '[y]' } ] } ] },
          { lit: 'event', next: [ { slot: '[index]' } ] },
          { lit: 'xy', next: [ { slot: '[x]', next: [ { slot: '[y]' } ] } ] },
        ] },
        { lit: 'goal', next: [
          { lit: 'complete', next: [ { slot: '<id>', values: currentGoalIDs } ] },
          { lit: 'receive', next: [ { slot: '<id>', values: goalIDs } ] },
        ] },
        { lit: 'learn', next: [
          { lit: 'clues' },
          { lit: 'event', next: [ { slot: '[index]' } ] },
          { lit: 'improvements', next: [ { slot: '[level]' } ] },
          { lit: 'region' },
          { lit: 'timeline' },
        ] },
        { lit: 'debug', next: debugSubs },
        { lit: 'mods', next: [
          { lit: 'list' },
          { lit: 'enable', next: [ { slot: '<id>', values: modIDs } ] },
          { lit: 'disable', next: [ { slot: '<id>', values: modIDs } ] },
          { lit: 'errors' },
        ] },
      ] };
    }

// splits input into non-empty tokens
  function tokens(text: String): Array<String>
    {
      var out = [];
      for (p in text.split(' '))
        if (p != '')
          out.push(p);
      return out;
    }

// descends the grammar by consuming the given tokens; null if no path matches
  function walk(toks: Array<String>): CompNode
    {
      var cur = root;
      for (t in toks)
        {
          var nextNode = matchChild(cur, t);
          if (nextNode == null)
            return null;
          cur = nextNode;
        }
      return cur;
    }

// finds the child matching a token: exact literal, else a value slot (consumes any value)
  function matchChild(node: CompNode, t: String): CompNode
    {
      if (node.next == null)
        return null;
      for (c in node.next)
        if (c.lit == t)
          return c;
      for (c in node.next)
        if (c.slot != null)
          return c;
      return null;
    }

// collects completion candidates available at a node's next position
  function candidates(node: CompNode): Array<String>
    {
      var out = [];
      if (node.next == null)
        return out;
      for (c in node.next)
        {
          if (c.lit != null)
            out.push(c.lit);
          else if (c.slot != null && c.values != null)
            for (v in c.values())
              out.push(v);
        }
      return out;
    }

// builds the remaining-argument template string for a node's next position
  function template(node: CompNode): String
    {
      if (node.next == null || node.next.length == 0)
        return '';
      var lits = [];
      var slotKid: CompNode = null;
      for (c in node.next)
        if (c.lit != null)
          lits.push(c.lit);
        else
          slotKid = c;
      // alternatives of literal keywords: list them and stop
      if (lits.length > 0)
        return '[' + lits.join('|') + ']';
      // value slot: show its placeholder, then recurse for further slots
      if (slotKid != null)
        {
          var rest = template(slotKid);
          return rest == '' ? slotKid.slot : slotKid.slot + ' ' + rest;
        }
      return '';
    }

// computes the longest common prefix of a candidate list
  function commonPrefix(list: Array<String>): String
    {
      if (list.length == 0)
        return '';
      var prefix = list[0];
      for (i in 1...list.length)
        {
          var s = list[i];
          var n = 0;
          while (n < prefix.length
            && n < s.length
            && prefix.charAt(n) == s.charAt(n))
            n++;
          prefix = prefix.substr(0, n);
          if (prefix == '')
            break;
        }
      return prefix;
    }

// returns the gray inline hint (remaining argument template) for the current input
  public function hint(text: String): String
    {
      var toks = tokens(text);
      var node = walk(toks);
      if (node == null)
        return '';
      var tmpl = template(node);
      if (tmpl == '')
        return '';
      var endsWithSpace = (text.length > 0 && text.charAt(text.length - 1) == ' ');
      var lead = (endsWithSpace || text == '') ? '' : ' ';
      return lead + tmpl;
    }

// completes the token under the cursor: fills longest common prefix,
// returns ambiguous candidates for display
  public function complete(text: String): CompResult
    {
      var toks = tokens(text);
      var endsWithSpace = (text.length > 0 && text.charAt(text.length - 1) == ' ');
      // index/prefix of the token being edited
      var prefix = endsWithSpace || toks.length == 0 ? '' : toks[toks.length - 1];
      var preceding = (endsWithSpace || toks.length == 0) ? toks : toks.slice(0, toks.length - 1);
      var node = walk(preceding);
      if (node == null)
        return { value: text, list: [] };
      var cands = [];
      for (c in candidates(node))
        if (StringTools.startsWith(c, prefix))
          cands.push(c);
      if (cands.length == 0)
        return { value: text, list: [] };
      var common = commonPrefix(cands);
      var newToken = common.length > prefix.length ? common : prefix;
      var base = preceding.join(' ');
      var newText = (base == '' ? '' : base + ' ') + newToken;
      // unique match: append a trailing space so the next slot can be typed
      if (cands.length == 1)
        newText += ' ';
      return { value: newText, list: cands.length > 1 ? cands : [] };
    }
}
