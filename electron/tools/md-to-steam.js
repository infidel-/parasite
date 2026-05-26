// Convert SDK markdown docs to Steam Workshop BBCode (.txt).
// Usage: node md-to-steam.js [in-dir] [out-dir]
//   defaults: parasite-mod-sdk/docs  parasite/docs-steam
// Same-page anchor links (#foo) are stripped entirely; cross-doc
// markdown links keep their label text. Numbered lists become bullets.

const fs = require('fs');
const path = require('path');

const IN  = path.resolve(process.argv[2] || 'parasite-mod-sdk/docs');
const OUT = path.resolve(process.argv[3] || 'parasite/docs-steam');

// split a markdown table row on `|`, ignoring pipes inside backtick spans.
// returns trimmed cell strings without the outer pipes.
function splitRow(line)
{
  const trimmed = line.trim().replace(/^\||\|$/g, '');
  const cells = [];
  let cur = '';
  let inCode = false;
  for (let i = 0; i < trimmed.length; i++)
    {
      const c = trimmed[i];
      if (c === '`') inCode = !inCode;
      if (c === '|' && !inCode) { cells.push(cur); cur = ''; continue; }
      cur += c;
    }
  cells.push(cur);
  return cells.map(s => s.trim());
}

// shared filename -> H1 title map, populated by main() before convert
// runs. Lets cross-doc links whose label IS the bare filename be swapped
// for the target doc's friendly title (e.g. "10-api-reference.md" ->
// "API reference (the externs)").
let titleMap = {};

function inline(s)
{
  const codes = [];
  s = s.replace(/`([^`]+)`/g, (_, x) =>
    {
      codes.push(x);
      return '\x00' + (codes.length - 1) + '\x00';
    });
  // same-page anchor: drop entirely AND eat one leading space so prose
  // doesn't end up with "(see  below)"-style double gaps.
  s = s.replace(/ ?\[[^\]]+\]\(#[^)]*\)/g, '');
  s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, label, href) =>
    {
      // cross-doc markdown link: keep label, drop URL — but if the label
      // is the bare filename (or filename + " §N" suffix), swap the
      // filename part for the target doc's H1 title.
      if (/\.md(#|$)/.test(href))
        {
          const base = href.replace(/#.*$/, '').replace(/^.*\//, '');
          const title = titleMap[base];
          if (title)
            {
              if (label === base) return title;
              // filename + suffix (e.g. "08-publishing.md §1" or
              // "05-monkey-patching.md#event-hooks"). Swap filename for
              // title; drop #anchor slugs (Steam can't navigate them)
              // but keep human suffixes like " §N".
              const m = label.match(/^(\d+-[a-z0-9-]+\.md)(\s.*|#.*)$/i);
              if (m && m[1] === base)
                return title + (m[2].startsWith('#') ? '' : m[2]);
            }
          return label;
        }
      // external URL: real Steam link
      return '[url=' + href + ']' + label + '[/url]';
    });
  // bare-filename mentions in prose: `08-publishing.md` written without
  // markdown link syntax (e.g. "see 08-publishing.md"). Drop any
  // #anchor suffix since Steam can't navigate anchors. Only fires on
  // known docs (in titleMap); unrelated paths like template/README.md
  // are untouched. Fenced [code] blocks bypass inline() so paths there
  // stay verbatim.
  s = s.replace(/(\d+-[a-z0-9-]+\.md)(#[a-z0-9-]+)?/gi, (m, base) =>
    titleMap[base] || m);
  s = s.replace(/\*\*([^*]+)\*\*/g, '[b]$1[/b]');
  s = s.replace(/\*([^*\n]+)\*/g, '[i]$1[/i]');
  // inline backtick spans render as bold (per spec), not [code]. Fenced
  // ``` blocks still emit [code] via the block-pass path.
  s = s.replace(/\x00(\d+)\x00/g, (_, idx) => '[b]' + codes[+idx] + '[/b]');
  return s;
}

// block-pass state machine: code-fence, table, heading, list (bullets
// and numbered both render as [list]), blockquote, paragraph.
function convert(md)
{
  const lines = md.replace(/\r\n/g, '\n').split('\n');
  const out = [];
  let i = 0;

  // list nesting stack; each entry remembers source indent
  let listStack = [];
  const closeListsTo = (depth) =>
    {
      while (listStack.length > depth)
        {
          out.push('[/list]');
          listStack.pop();
        }
    };
  const closeAllLists = () => closeListsTo(0);

  // blockquote accumulator — collect raw lines, inline once at flush so
  // backtick / link spans that wrap across quote lines stay paired
  let quoteBuf = [];
  const flushQuote = () =>
    {
      if (!quoteBuf.length) return;
      out.push('[quote]');
      out.push(inline(quoteBuf.join(' ')));
      out.push('[/quote]');
      quoteBuf = [];
    };

  // detect anything that ends paragraph soft-wrap accumulation
  const isBlockStart = (l) =>
    l === ''
    || /^#{1,3} /.test(l)
    || /^\s*```/.test(l)
    || /^> /.test(l)
    || /^\s*(?:[-*]|\d+\.)\s+/.test(l)
    || /^\s*\|.*\|\s*$/.test(l);

  while (i < lines.length)
    {
      const line = lines[i];

      // fenced code block — drop language tag, wrap in [code]. Allow
      // leading whitespace (fences indented inside list items); strip
      // that same indent from each body line so the code reads cleanly.
      const fm = line.match(/^(\s*)```/);
      if (fm)
        {
          closeAllLists();
          flushQuote();
          const pad = fm[1].length;
          const strip = new RegExp('^\\s{0,' + pad + '}');
          out.push('[code]');
          i++;
          while (i < lines.length && !/^\s*```/.test(lines[i]))
            {
              out.push(lines[i].replace(strip, ''));
              i++;
            }
          out.push('[/code]');
          i++;
          continue;
        }

      // GFM pipe table: header row followed by |---|---| separator
      if (/^\s*\|.*\|\s*$/.test(line)
          && i + 1 < lines.length
          && /^\s*\|[\s:|-]+\|\s*$/.test(lines[i + 1]))
        {
          closeAllLists();
          flushQuote();
          out.push('[table]');
          const head = splitRow(line).map(c => '[th]' + inline(c) + '[/th]').join('');
          out.push('[tr]' + head + '[/tr]');
          i += 2;
          while (i < lines.length && /^\s*\|.*\|\s*$/.test(lines[i]))
            {
              const body = splitRow(lines[i]).map(c => '[td]' + inline(c) + '[/td]').join('');
              out.push('[tr]' + body + '[/tr]');
              i++;
            }
          out.push('[/table]');
          continue;
        }

      // blockquote — buffer until non-quote line
      const qm = line.match(/^> ?(.*)$/);
      if (qm)
        {
          quoteBuf.push(qm[1]);
          i++;
          continue;
        }
      flushQuote();

      // heading
      const hm = line.match(/^(#{1,3}) +(.*)$/);
      if (hm)
        {
          closeAllLists();
          const lvl = hm[1].length;
          out.push('[h' + lvl + ']' + inline(hm[2]) + '[/h' + lvl + ']');
          i++;
          continue;
        }

      // list item — bullets and numbered both -> [list][*]
      const lm = line.match(/^(\s*)(?:[-*]|\d+\.)\s+(.*)$/);
      if (lm)
        {
          const indent = lm[1].length;
          const depth = Math.floor(indent / 2) + 1;
          while (listStack.length < depth)
            {
              out.push('[list]');
              listStack.push({ indent });
            }
          closeListsTo(depth);
          // soft-wrap continuation: collect raw text first, inline once
          const itemBuf = [lm[2]];
          i++;
          while (i < lines.length)
            {
              const nxt = lines[i];
              if (nxt === '') break;
              if (/^(\s*)(?:[-*]|\d+\.)\s+/.test(nxt)) break;
              if (/^\s*```/.test(nxt)) break;
              const ind = nxt.match(/^(\s*)/)[1].length;
              if (ind <= indent && nxt.trim() !== '') break;
              itemBuf.push(nxt.trim());
              i++;
            }
          out.push('[*]' + inline(itemBuf.join(' ')));
          continue;
        }

      // blank line — close any open lists, paragraph break
      if (line === '')
        {
          closeAllLists();
          out.push('');
          i++;
          continue;
        }

      // paragraph — collect soft-wrapped raw lines, join, THEN inline.
      // joining first preserves backtick/link spans that wrap across lines.
      // strip leading indent on continuation lines (post-list / post-fence
      // prose often inherits the list's indent in source markdown).
      closeAllLists();
      const buf = [line.replace(/^\s+/, '')];
      i++;
      while (i < lines.length && !isBlockStart(lines[i]))
        {
          buf.push(lines[i].replace(/^\s+/, ''));
          i++;
        }
      out.push(inline(buf.join(' ')));
    }
  closeAllLists();
  flushQuote();

  // collapse runs of blank lines down to one
  const collapsed = [];
  for (const l of out)
    {
      if (l === '' && collapsed[collapsed.length - 1] === '') continue;
      collapsed.push(l);
    }
  // drop leading [h1] page title — Steam Workshop carries its own title
  while (collapsed.length && collapsed[0] === '') collapsed.shift();
  if (collapsed.length && /^\[h1\].*\[\/h1\]$/.test(collapsed[0]))
    {
      collapsed.shift();
      while (collapsed.length && collapsed[0] === '') collapsed.shift();
    }
  return collapsed.join('\n').replace(/\n+$/, '') + '\n';
}

function main()
{
  if (!fs.existsSync(IN))
    {
      console.error('input dir missing: ' + IN);
      process.exit(2);
    }
  fs.mkdirSync(OUT, { recursive: true });
  const files = fs.readdirSync(IN).filter(f => f.endsWith('.md')).sort();
  // pre-scan H1s so cross-doc links can substitute friendly titles
  for (const f of files)
    {
      const src = fs.readFileSync(path.join(IN, f), 'utf8');
      const hm = src.match(/^# +(.+)$/m);
      if (hm) titleMap[f] = hm[1].trim();
    }
  for (const f of files)
    {
      const src = fs.readFileSync(path.join(IN, f), 'utf8');
      const dst = convert(src);
      const outName = f.replace(/\.md$/, '.txt');
      fs.writeFileSync(path.join(OUT, outName), dst);
      console.log(outName);
    }
  console.log('wrote ' + files.length + ' files to ' + OUT);
}

main();
