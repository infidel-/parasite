// name generator constants

package const;

class NameConst
{
  // available types
  public static var types = [
    'greek', 'tree', 'geo', 'lab', 'baseA', 'baseB'
    ];

  // greek letters
  public static var greek = [
    'Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon',
    'Zeta', 'Eta', 'Theta', 'Iota', 'Kappa', 'Lambda',
    'Mu', 'Nu', 'Xi', 'Omicron',
    'Pi', 'Rho', 'Sigma', 'Tau', 'Upsilon', 'Phi', 'Chi', 'Psi', 'Omega'
    ];

  // military base parts
  public static var baseA = [
    'Trueman', 'Howard', 'Russell', 'Stewart', 'Riley', 'Foster',
    'James', 'Stokes', 'Morris', 'Dillon', 'Laurens', 'Gordon',
    'Raleigh'
    ];

  public static var baseB = [
    'Fort', 'Battery', 'Armory', 'Camp',
    'Air Force Base',
    'Medical Depot',
    'Army Air Field',
    'Air Force Station',
    ];

  // geographical features
  public static var geo = [
    'Hill', 'Ridge', 'Bed', 'Basin', 'Valley', 'Hills', 'Mountain',
    'Heights', 'Terrace', 'Woods', 'Range', 'Hollow', 'Grove',
    ];

  // trees
  public static var tree = [
    'Oak', 'Pine', 'Redwood', 'Elm', 'Magnolia', 'Dogwood', 'Cottonwood',
    'Pinyon', 'Birch', 'Maple', 'Hemlock', 'Aspen', 'Hemlock',
    ];

  // laboratories
  public static var lab = [
    'Test Center',
    'Testing Bureau',
    'Defense Lab',
    'Laboratory',
    'Testing Grounds',
    'Research Center',
    'Research Lab',
    ];


// generates a name by its components
  public static function generate(name: String)
    {
      // %num?% => random numbers
      if (name.indexOf('%num') >= 0)
        for (i in 0...9)
          name = StringTools.replace(name, '%num' + i + '%', '' + Std.random(10));

      // %letter?% => random letter A-Z
      if (name.indexOf('%letter') >= 0)
        for (i in 0...9)
          name = StringTools.replace(name, '%letter' + i + '%',
            String.fromCharCode(65 + Std.random(26)));

      // %[type]?% => random word out of dictionary for this type
      for (t in NameConst.types)
        if (name.indexOf('%' + t) >= 0)
          for (i in 0...9)
            {
              var arr: Array<String> = Reflect.field(NameConst, t);
              if (arr == null)
                {
                  trace('No such NameConst field: ' + t);
                  arr = [ 'BUG' ];
                }
              var item = arr[Std.random(arr.length)];

              name = StringTools.replace(name, '%' + t + i + '%', item);
            }

      return name;
    }
}
