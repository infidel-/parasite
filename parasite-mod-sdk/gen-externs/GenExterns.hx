// auto-generates Haxe externs for the engine surface from a `haxe --xml` dump.
// emits one `@:native('window.parasiteHx[...]')` extern
// class per engine class + a typedef per engine anonymous typedef, mirroring
// the engine package layout under <outDir>. std/electron/haxelib types and any
// reference the generator does not include resolve to Dynamic.
//
// run: haxe -cp parasite-mod-sdk/gen-externs --run GenExterns \
//        bin/types.xml parasite-mod-sdk/externs-generated

import haxe.rtti.CType;
import sys.io.File;
import sys.FileSystem;

class GenExterns
{
  // dotted paths of every type we emit; used to decide whether a referenced
  // type resolves to a real extern or falls back to Dynamic
  static var included: Map<String, Bool> = new Map();
  // dotted paths of hand-curated externs to skip during generation
  static var curated: Map<String, Bool> = new Map();
  // per-source-file line cache for scraping `//` doc comments above decls
  static var srcLines: Map<String, Array<String>> = new Map();
  // dir the engine `--xml` was compiled from; rtti `file` paths are relative
  // to it, so doc-scraping resolves sources under here
  static var srcRoot: String = 'src';
  // paths/packages mods never need externs for (internal engine machinery).
  // 'pkg.*' = whole package recursive, 'Name*' = root name-prefix, else exact.
  // blacklisted types are not emitted and resolve to Dynamic when referenced
  static var blacklist: Array<String> = [
    'aPath.*',
    'console.*',
    'cult.missions.*',
    'cult.ordeals.*',
    'cult.events.*',
    'cult.effects.*',
    'cult.ArriveCultistParams',
    'cult.UpgradeFollowerEvents',
    'lighting.*',
    'map.*',
    'mods.*',
    'AreaLighting*',
    'HostBridge',
    'Version',
  ];
  // std/basic type names passed through untouched (everything else → Dynamic)
  static var passthrough: Map<String, Bool> = [
    'String' => true, 'Int' => true, 'Float' => true, 'Bool' => true,
    'Void' => true, 'Dynamic' => true, 'Any' => true, 'Array' => true,
    'Null' => true, 'Map' => true, 'haxe.ds.Map' => true,
    'haxe.ds.StringMap' => true, 'haxe.ds.IntMap' => true, 'Date' => true,
    'EReg' => true, 'List' => true, 'haxe.ds.List' => true,
  ];

  static function main()
    {
      var args = Sys.args();
      var xmlPath = args[0] != null ? args[0] : 'bin/types.xml';
      var outDir = args[1] != null ? args[1] : 'parasite-mod-sdk/externs-generated';
      var curatedDir = args[2] != null ? args[2] : 'parasite-mod-sdk/externs';
      // game version these externs were generated against (mod authors match it
      // to the engine they target); stamped into <outDir>/VERSION
      var version = args[3] != null ? args[3] : 'unknown';
      if (args[4] != null) srcRoot = args[4];

      // wipe stale output so removed/blacklisted types don't linger
      rmRec(outDir);

      // hand-curated externs are documented and authoritative; record their
      // dotted paths so generation skips them (lets both dirs share -cp)
      scanCurated(curatedDir, '');

      var parser = new haxe.rtti.XmlParser();
      parser.process(Xml.parse(File.getContent(xmlPath)).firstElement(), 'js');

      // pass 1: collect every engine type path we will emit
      var decls = [];
      collect(parser.root, decls);
      // pass 2: emit each
      var count = 0;
      for (d in decls)
        {
          var out = switch (d)
            {
              case TClassdecl(c): emitClass(c);
              case TTypedecl(t): emitTypedef(t);
              case TAbstractdecl(a): emitAbstract(a);
              default: null;
            }
          if (out == null)
            continue;
          var path = switch (d) { case TClassdecl(c): c.path; case TTypedecl(t): t.path; case TAbstractdecl(a): a.path; default: ''; }
          writeType(outDir, path, out);
          count++;
        }
      // stamp the game version so authors know which engine these match
      mkdirs(outDir);
      File.saveContent(outDir + '/VERSION', version + '\n');
      Sys.println('generated ' + count + ' externs (v' + version + ') into ' + outDir);
    }

// recursively scans the curated externs dir, recording each .hx as a dotted
// path in both `curated` (skip-on-emit) and `included` (resolve as a real
// extern when referenced, since it ships on the same classpath)
  static function scanCurated(dir: String, pkg: String)
    {
      if (!FileSystem.exists(dir))
        return;
      for (entry in FileSystem.readDirectory(dir))
        {
          var full = dir + '/' + entry;
          if (FileSystem.isDirectory(full))
            scanCurated(full, pkg == '' ? entry : pkg + '.' + entry);
          else if (StringTools.endsWith(entry, '.hx'))
            {
              var name = entry.substr(0, entry.length - 3);
              var path = pkg == '' ? name : pkg + '.' + name;
              curated.set(path, true);
              included.set(path, true);
            }
        }
    }

// recursively walks the rtti tree, recording engine class/typedef decls into
// `out` and marking their paths as included
  static function collect(tree: Array<TypeTree>, out: Array<TypeTree>)
    {
      for (t in tree)
        switch (t)
          {
            case TPackage(_, _, subs):
              collect(subs, out);
            case TClassdecl(c):
              // skip interfaces, abstract-impl artifacts (private _Impl_), and
              // module sub-types (path != module — invalid as own package)
              if (isEngine(c.file)
                  && !c.isInterface
                  && !c.isPrivate
                  && !curated.exists(c.path)
                  && !blacklisted(c.path)
                  && !isSubType(c.path, c.file)
                  && c.path.indexOf('_Impl_') < 0)
                { included.set(c.path, true); out.push(t); }
            case TTypedecl(td):
              // only top-level anonymous-record typedefs become Haxe typedefs;
              // aliases and module sub-types are skipped (→ Dynamic when referenced)
              if (isEngine(td.file)
                  && !curated.exists(td.path)
                  && !blacklisted(td.path)
                  && !isSubType(td.path, td.file)
                  && td.type.match(CAnonymous(_)))
                { included.set(td.path, true); out.push(t); }
            case TAbstractdecl(a):
              // enum-abstracts over a basic base (String/Int) reproduce as real
              // Haxe enum abstracts so mods get the named id constants + casts.
              // non-enum abstracts and abstracts over complex bases → Dynamic
              if (isEngine(a.file)
                  && !curated.exists(a.path)
                  && !blacklisted(a.path)
                  && !isSubType(a.path, a.file)
                  && hasMeta(a.meta, ':enum')
                  && passthrough.exists(ctype(a.athis)))
                { included.set(a.path, true); out.push(t); }
            default:
          }
    }

// true if `path` is a module sub-type (a non-primary type sharing another
// type's .hx file). detected by mismatch between the path's expected file
// (pkg/Name.hx) and the rtti source file: a sub-type's file is named after its
// containing module, not itself. such types are invalid as their own package
// and would redefine the curated module — skipped, resolve to Dynamic
  static function isSubType(path: String, file: Null<String>): Bool
    {
      if (file == null)
        return true;
      var expected = path.split('.').join('/') + '.hx';
      return !StringTools.endsWith(file, expected);
    }

// true if a path matches a blacklist entry: 'pkg.*' = package prefix,
// 'Name*' = name prefix, otherwise an exact path match
  static function blacklisted(path: String): Bool
    {
      for (b in blacklist)
        {
          if (StringTools.endsWith(b, '*'))
            { if (StringTools.startsWith(path, b.substr(0, b.length - 1))) return true; }
          else if (path == b)
            return true;
        }
      return false;
    }

// true if a type's source file belongs to the engine (project src), not the
// haxe std lib, a haxelib, or an absolute extern path
  static function isEngine(file: Null<String>): Bool
    {
      if (file == null)
        return false;
      if (StringTools.startsWith(file, '/'))
        return false;
      if (file.indexOf('std/') >= 0 || file.indexOf('haxelib') >= 0)
        return false;
      return true;
    }

// scrapes the `//` comment block above the source decl of `name` (a var or
// function) in `file`. returns comment lines (markers stripped), or []
  static function docFor(file: Null<String>, name: String): Array<String>
    return scrapeDocAbove(file,
      new EReg('\\b(var|function)\\s+' + name + '([^A-Za-z0-9_]|$)', ''));

// scrapes the `//` comment block above an abstract's decl line in `file`
// (`abstract <name>` / `enum abstract <name>`)
  static function abstractDoc(file: Null<String>, name: String): Array<String>
    return scrapeDocAbove(file, new EReg('\\babstract\\s+' + name + '([^A-Za-z0-9_]|$)', ''));

// shared doc scraper: loads <file>, finds the first line matching `decl`, then
// walks upward over contiguous `//` lines (skipping @meta/#cond lines) and
// returns the comment text with markers stripped, or [] if the file/decl/
// comment is missing. purely textual — a renamed or duplicated decl can
// mis-match, acceptable for doc comments
  static function scrapeDocAbove(file: Null<String>, decl: EReg): Array<String>
    {
      if (file == null || !isEngine(file))
        return [];
      var path = srcRoot + '/' + file;
      if (!FileSystem.exists(path))
        return [];
      var lines = srcLines.get(path);
      if (lines == null)
        {
          lines = File.getContent(path).split('\n');
          srcLines.set(path, lines);
        }
      var at = -1;
      for (i in 0...lines.length)
        if (decl.match(lines[i]))
          { at = i; break; }
      if (at < 0)
        return [];
      var out = [];
      var i = at - 1;
      while (i >= 0)
        {
          var t = StringTools.trim(lines[i]);
          if (StringTools.startsWith(t, '//'))
            { out.unshift(stripComment(t)); i--; continue; }
          // skip annotations and conditional-compilation lines between the
          // comment block and the decl without breaking contiguity
          if (StringTools.startsWith(t, '@') || StringTools.startsWith(t, '#'))
            { i--; continue; }
          break;
        }
      return out;
    }

// strips a leading `//` (and one following space) from a trimmed comment line
  static function stripComment(t: String): String
    {
      var s = t.substr(2);
      if (StringTools.startsWith(s, ' '))
        s = s.substr(1);
      return s;
    }

// emits scraped doc lines at the given indent, if any
  static function emitDoc(sb: StringBuf, doc: Array<String>, indent: String)
    {
      for (d in doc)
        sb.add(indent + '// ' + d + '\n');
    }

// emits one extern class with its public instance + static fields.
// `publicNames` (built per class) lets emitField skip accessor decls when the
// accessor itself is already in the public field list (otherwise the same
// `set_x`/`get_x` would be declared twice and fail to compile in the mod)
  static function emitClass(c: Classdef): String
    {
      var sb = new StringBuf();
      sb.add('// auto-generated — do not edit. source: ' + c.file + '\n');
      sb.add('// resolves to window.parasiteHx at mod load time\n');
      sb.add(nativeMeta(c.path) + '\n');
      sb.add('extern class ' + shortName(c.path) + typeParams(c.params));
      // extends only if the superclass is also an emitted engine type
      if (c.superClass != null && included.exists(c.superClass.path))
        sb.add(' extends ' + c.superClass.path + typeArgs(c.superClass.params));
      sb.add('\n{\n');
      var publicNames = new Map<String, Bool>();
      for (f in c.fields)
        if (f.isPublic)
          publicNames.set(f.name, true);
      var publicStatics = new Map<String, Bool>();
      for (f in c.statics)
        if (f.isPublic)
          publicStatics.set(f.name, true);
      for (f in c.fields)
        emitField(sb, f, false, c.file, publicNames);
      for (f in c.statics)
        emitField(sb, f, true, c.file, publicStatics);
      sb.add('}\n');
      return sb.toString();
    }

// emits one record typedef
  static function emitTypedef(t: Typedef): String
    {
      var sb = new StringBuf();
      sb.add('// auto-generated — do not edit. source: ' + t.file + '\n');
      sb.add('typedef ' + shortName(t.path) + typeParams(t.params) + ' = {\n');
      switch (t.type)
        {
          case CAnonymous(fields):
            for (f in fields)
              emitAnonField(sb, f, t.file);
          default:
        }
      sb.add('}\n');
      return sb.toString();
    }

// emits one enum-abstract (e.g. _Goal): the underlying base type, to/from
// casts, and each named value with its scraped doc comment. plain compile-time
// abstract (no @:native) — values inline into mod code like the engine source
  static function emitAbstract(a: Abstractdef): String
    {
      var base = ctype(a.athis);
      var sb = new StringBuf();
      sb.add('// auto-generated — do not edit. source: ' + a.file + '\n');
      emitDoc(sb, abstractDoc(a.file, shortName(a.path)), '');
      // reproduce the implicit casts the engine declares (all engine
      // enum-abstracts are `to <base> from <base>`)
      var clause = '';
      if (a.to != null && a.to.length > 0)
        clause += ' to ' + base;
      if (a.from != null && a.from.length > 0)
        clause += ' from ' + base;
      sb.add('enum abstract ' + shortName(a.path) + '(' + base + ')' + clause + '\n{\n');
      // each named value is a public inline static on the abstract's impl class,
      // tagged with `:enum`; its constant is in the field expr / `:value` meta
      if (a.impl != null)
        for (f in a.impl.statics)
          {
            if (!f.isPublic || !hasMeta(f.meta, ':enum'))
              continue;
            emitDoc(sb, docFor(a.file, f.name), '  ');
            sb.add('  var ' + safeName(f.name) + ' = ' + abstractValue(f) + ';\n');
          }
      sb.add('}\n');
      return sb.toString();
    }

// extracts an enum-abstract member's constant from its `:value` meta (falling
// back to the field expr), stripping the leading `cast ` the rtti emits
  static function abstractValue(f: ClassField): String
    {
      var e = f.expr;
      for (m in f.meta)
        if (m.name == ':value' && m.params.length > 0)
          { e = m.params[0]; break; }
      if (e == null)
        return 'null';
      e = StringTools.trim(e);
      if (StringTools.startsWith(e, 'cast '))
        e = StringTools.trim(e.substr(5));
      return e;
    }

// true if a metadata list carries an entry named `name`
  static function hasMeta(meta: MetaData, name: String): Bool
    {
      for (m in meta)
        if (m.name == name)
          return true;
      return false;
    }

// writes a single class/static field (var or function) into the buffer,
// prefixed by its scraped source doc comment if one exists.
// for var-properties (e.g. `var x(get, null): Int`) emits the property
// declaration with matching access pair plus declarations for any get_/set_
// accessor methods, so mod code's `inst.x` compiles to `inst.get_x()` (which
// is what exists on the runtime engine class — the plain `.x` is absent).
  static function emitField(sb: StringBuf, f: ClassField, isStatic: Bool, file: Null<String>, publicNames: Map<String, Bool>)
    {
      if (!f.isPublic)
        return;
      emitDoc(sb, docFor(file, f.name), '  ');
      var stat = isStatic ? 'static ' : '';
      switch (f.type)
        {
          case CFunction(args, ret):
            var as = [];
            for (a in args)
              as.push((a.opt ? '?' : '') + safeName(a.name) + ': ' + ctype(a.t));
            sb.add('  public ' + stat + 'function ' + safeName(f.name) +
              typeParams(f.params) + '(' + as.join(', ') + '): ' + ctype(ret) + ';\n');
          default:
            // detect property accessors (RCall/RNo/etc.) vs plain field (RNormal/RNormal)
            var ga = rightsToAccess(f.get, false);
            var sa = rightsToAccess(f.set, true);
            if (ga != 'default' || sa != 'default')
              {
                // property declaration; include type
                sb.add('  public ' + stat + 'var ' + safeName(f.name) +
                  '(' + ga + ', ' + sa + '): ' + ctype(f.type) + ';\n');
                // emit accessor method externs the property declaration calls.
                // haxe rtti XML stores RCall as literal "accessor" (it doesn't
                // preserve the function name), so we reconstruct via convention:
                // get_<field> for read, set_<field> for write. skip if the
                // accessor is itself a public field — emitField will emit it
                // separately in the main loop and we'd double-declare.
                if (f.get.match(RCall(_)) && !publicNames.exists('get_' + f.name))
                  sb.add('  ' + stat + 'function get_' + safeName(f.name) +
                    '(): ' + ctype(f.type) + ';\n');
                if (f.set.match(RCall(_)) && !publicNames.exists('set_' + f.name))
                  sb.add('  ' + stat + 'function set_' + safeName(f.name) +
                    '(v: ' + ctype(f.type) + '): ' + ctype(f.type) + ';\n');
              }
            else
              sb.add('  public ' + stat + 'var ' + safeName(f.name) + ': ' +
                ctype(f.type) + ';\n');
        }
    }

// maps haxe.rtti.Rights to the Haxe property-access keyword used in source.
// isSet picks 'set' vs 'get' for the RCall case (property declarations need
// the side-appropriate keyword)
  static function rightsToAccess(r: Rights, isSet: Bool): String
    {
      return switch (r)
        {
          case RNormal: 'default';
          case RNo: 'null';
          case RCall(_): (isSet ? 'set' : 'get');
          case RMethod: 'default';
          case RDynamic: 'dynamic';
          case RInline: 'default';
        };
    }


// writes a single anonymous-typedef field, honoring the :optional marker,
// prefixed by its scraped source doc comment if one exists
  static function emitAnonField(sb: StringBuf, f: ClassField, file: Null<String>)
    {
      emitDoc(sb, docFor(file, f.name), '  ');
      var opt = false;
      for (m in f.meta)
        if (m.name == ':optional')
          opt = true;
      switch (f.type)
        {
          case CFunction(args, ret):
            var as = [];
            for (a in args)
              as.push(ctype(a.t));
            if (as.length == 0)
              as.push('Void');
            sb.add('  ' + (opt ? '@:optional ' : '') + 'var ' + safeName(f.name) +
              ': ' + as.join(' -> ') + ' -> ' + ctype(ret) + ';\n');
          default:
            sb.add('  ' + (opt ? '@:optional ' : '') + 'var ' + safeName(f.name) +
              ': ' + ctype(f.type) + ';\n');
        }
    }

// renders a CType into extern-safe Haxe source. engine types keep their dotted
// path; std/basic types pass through; anything else collapses to Dynamic
  static function ctype(t: CType): String
    {
      return switch (t)
        {
          case CClass(name, params)
             | CEnum(name, params)
             | CTypedef(name, params)
             | CAbstract(name, params):
            if (name == 'Null' && params.length == 1)
              'Null<' + ctype(params[0]) + '>';
            else if (included.exists(name) || passthrough.exists(name))
              name + typeArgs(params);
            else 'Dynamic';
          case CFunction(args, ret):
            var as = [];
            for (a in args)
              as.push(ctype(a.t));
            if (as.length == 0)
              as.push('Void');
            '(' + as.join(' -> ') + ' -> ' + ctype(ret) + ')';
          case CDynamic(_): 'Dynamic';
          case CAnonymous(_): 'Dynamic';
          case CUnknown: 'Dynamic';
        }
    }

// renders <A, B> type arguments, or '' when there are none
  static function typeArgs(params: Array<CType>): String
    {
      if (params == null || params.length == 0)
        return '';
      var ps = [];
      for (p in params)
        ps.push(ctype(p));
      return '<' + ps.join(', ') + '>';
    }

// renders <T, U> type-parameter declarations, or '' when there are none
  static function typeParams(params: TypeParams): String
    {
      if (params == null || params.length == 0)
        return '';
      return '<' + params.join(', ') + '>';
    }

// @:native target — bracket form for packaged paths, dot form for root
  static function nativeMeta(path: String): String
    {
      if (path.indexOf('.') >= 0)
        return '@:native(\'window.parasiteHx["' + path + '"]\')';
      return '@:native(\'window.parasiteHx.' + path + '\')';
    }

// last dotted segment of a path
  static function shortName(path: String): String
    {
      var i = path.lastIndexOf('.');
      return i < 0 ? path : path.substr(i + 1);
    }

// guards against Haxe keywords leaking in as identifiers
  static function safeName(n: String): String
    {
      return switch (n)
        {
          case 'new': 'new';
          case 'function' | 'class' | 'var' | 'override' | 'in' | 'cast' |
               'default' | 'switch' | 'macro': n + '_';
          default: n;
        }
    }

// writes the extern source to <outDir>/<pkg path>/<Name>.hx with a package decl
  static function writeType(outDir: String, path: String, body: String)
    {
      var i = path.lastIndexOf('.');
      var pkg = i < 0 ? '' : path.substr(0, i);
      var name = shortName(path);
      var dir = outDir + (pkg == '' ? '' : '/' + pkg.split('.').join('/'));
      mkdirs(dir);
      var header = pkg == '' ? '' : 'package ' + pkg + ';\n\n';
      File.saveContent(dir + '/' + name + '.hx', header + body);
    }

// recursively deletes a directory and its contents (rm -rf), no-op if absent
  static function rmRec(dir: String)
    {
      if (!FileSystem.exists(dir))
        return;
      for (entry in FileSystem.readDirectory(dir))
        {
          var full = dir + '/' + entry;
          if (FileSystem.isDirectory(full))
            rmRec(full);
          else
            FileSystem.deleteFile(full);
        }
      FileSystem.deleteDirectory(dir);
    }

// mkdir -p
  static function mkdirs(dir: String)
    {
      if (FileSystem.exists(dir))
        return;
      FileSystem.createDirectory(dir);
    }
}
