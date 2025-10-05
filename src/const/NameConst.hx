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

  // thug rapper prefix list
  public static var thugPrefixes = [
    'Lil', 'Kid', 'Ya', 'Big', 'Ice', 'Madd', 'Yung',
    'MC', 'DJ', 'OG', 'JJ', 'J.R.',
    'Count', 'Baby', 'Boss', 'Dirty', 'Flai', 'Ace', 'King',
    'Hard', 'Hevy'
    ];

  // thug rapper word suffix list
  public static var thugWords = [
    'Dolla', 'Buck', 'Nite', 'DumDum', 'Boi', 'Stax',
    'Juce', 'Rydah', 'Bleyz', 'Razur', 'Nok', 'Shade',
    'Monsta', 'Killa', 'Gangsta', 'Gorilla', 'Gucci',
    'Flexx', 'Flow', 'Yaboi', 'Gudda', 'Guru', 'Hittman',
    'Honey', 'Foxx', 'Jamal', 'Jay', 'Bada$$', 'Kardinal',
    'Kokane', 'Wil', 'Peep', 'Dickbleed', 'Masta', 'Doom',
    'Dawg', 'Dogg', 'Needlz', 'Necro', 'Malice', 'Nutty',
    'Tempah', 'Mofo',
    ];

  // thug rapper jewelry suffix list
  public static var thugJewelry = [
    'Chain', 'Bling', 'Ice', 'Jool', 'Jule', 'Jules', 'Gold', 'Dymond', 'Purl', 'Rring', 'Kraun',
    'Grilz',
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


// generates a random thug name
  public static function getThugName(isMale: Bool): String
    {
      var prefix = NameConst.thugPrefixes[Std.random(NameConst.thugPrefixes.length)];

      var suffix: String;
      var suffixChoice = Std.random(4);
      switch (suffixChoice)
        {
          // single letter
          case 0:
            suffix = String.fromCharCode(65 + Std.random(26));
          // word
          case 1:
            suffix = NameConst.thugWords[Std.random(NameConst.thugWords.length)];

          // name
          case 2:
            var firstPool = isMale ? NameConst.maleFirst : NameConst.femaleThugFirst;
            suffix = firstPool[Std.random(firstPool.length)];

          // jewelry
          default:
            suffix = NameConst.thugJewelry[Std.random(NameConst.thugJewelry.length)];
        }

      return prefix + ' ' + suffix;
    }


// returns a random human name
  public static function getHumanName(isMale: Bool)
    {
      return
        (isMale ?
         NameConst.maleFirst[Std.random(NameConst.maleFirst.length)] :
         NameConst.femaleFirst[Std.random(NameConst.femaleFirst.length)]) +
        ' ' +
        NameConst.last[Std.random(NameConst.last.length)];
    }


  // male first names
  public static var maleFirst = [
    "Aaron", "Adam", "Alan", "Albert", "Alex", "Alexander", "Alfred",
    "Allen", "Alvin", "Andrew", "Anthony", "Antonio", "Arthur", "Barry",
    "Benjamin", "Bernard", "Bill", "Billy", "Bobby", "Bradley", "Brandon",
    "Brent", "Brian", "Bruce", "Bryan", "Calvin", "Carl", "Carlos", "Chad",
    "Charles", "Charlie", "Chris", "Christopher", "Clarence", "Clifford",
    "Clyde", "Corey", "Craig", "Curtis", "Dale", "Dan", "Daniel", "Danny",
    "Darrell", "David", "Dean", "Dennis", "Derek", "Derrick", "Don", "Donald",
    "Douglas", "Dustin", "Earl", "Eddie", "Edward", "Edwin", "Eric", "Ernest",
    "Eugene", "Floyd", "Francis", "Francisco", "Frank", "Fred", "Frederick",
    "Gary", "Gene", "George", "Gerald", "Gilbert", "Glen", "Glenn", "Gordon",
    "Greg", "Gregory", "Harold", "Harry", "Hector", "Henry", "Herbert",
    "Herman", "Howard", "Jack", "Jacob", "James", "Jason", "Jay", "Jeff",
    "Jeffery", "Jeffrey", "Jeremy", "Jerome", "Jerry", "Jesse", "Jesus",
    "Jim", "Jimmy", "Joe", "Joel", "John", "Johnny", "Jon", "Jonathan",
    "Jorge", "Jose", "Joseph", "Joshua", "Juan", "Justin", "Keith", "Kenneth",
    "Kevin", "Kyle", "Larry", "Lawrence", "Lee", "Leo", "Leon", "Leonard",
    "Leroy", "Lester", "Lewis", "Lloyd", "Louis", "Luis", "Manuel", "Marcus",
    "Mario", "Mark", "Martin", "Marvin", "Matthew", "Maurice", "Melvin",
    "Michael", "Micheal", "Miguel", "Mike", "Nathan", "Nicholas", "Norman",
    "Oscar", "Patrick", "Paul", "Pedro", "Peter", "Philip", "Phillip",
    "Ralph", "Ramon", "Randall", "Randy", "Ray", "Raymond", "Ricardo",
    "Richard", "Rick", "Ricky", "Robert", "Roberto", "Rodney", "Roger",
    "Ronald", "Ronnie", "Roy", "Russell", "Ryan", "Sam", "Samuel", "Scott",
    "Sean", "Shane", "Shawn", "Stanley", "Stephen", "Steve", "Steven",
    "Terry", "Theodore", "Thomas", "Tim", "Timothy", "Todd", "Tom", "Tommy",
    "Tony", "Travis", "Troy", "Tyler", "Vernon", "Victor", "Vincent",
    "Walter", "Warren", "Wayne", "Wesley", "William", "Willie", "Zachary",
    ];

  // female first names
  public static var femaleFirst = [
    "Alice", "Alicia", "Alma", "Amanda", "Amber", "Amy", "Ana", "Andrea",
    "Angela", "Anita", "Ann", "Anna", "Anne", "Annette", "Annie", "April",
    "Ashley", "Audrey", "Barbara", "Beatrice", "Bernice", "Bertha",
    "Beth", "Betty", "Beverly", "Bonnie", "Brenda", "Brittany", "Carmen",
    "Carol", "Carolyn", "Carrie", "Catherine", "Cathy", "Charlotte",
    "Cheryl", "Christina", "Christine", "Cindy", "Clara", "Connie",
    "Crystal", "Cynthia", "Dana", "Danielle", "Darlene", "Dawn", "Debbie",
    "Deborah", "Debra", "Denise", "Diana", "Diane", "Dolores", "Donna",
    "Doris", "Dorothy", "Edith", "Edna", "Elaine", "Eleanor", "Elizabeth",
    "Ellen", "Elsie", "Emily", "Emma", "Erica", "Erin", "Esther", "Ethel",
    "Eva", "Evelyn", "Florence", "Frances", "Gail", "Geraldine", "Gladys",
    "Gloria", "Grace", "Hazel", "Heather", "Helen", "Holly", "Ida",
    "Irene", "Jacqueline", "Jamie", "Jane", "Janet", "Janice", "Jean",
    "Jeanette", "Jeanne", "Jennifer", "Jessica", "Jill", "Joan", "Joann",
    "Joanne", "Josephine", "Joyce", "Juanita", "Judith", "Judy", "Julia",
    "Julie", "June", "Karen", "Katherine", "Kathleen", "Kathryn", "Kathy",
    "Katie", "Kelly", "Kim", "Kimberly", "Kristen", "Laura", "Lauren",
    "Laurie", "Leslie", "Lillian", "Linda", "Lisa", "Lois", "Loretta",
    "Lori", "Lorraine", "Louise", "Lucille", "Lynn", "Margaret", "Maria",
    "Marie", "Marilyn", "Marion", "Marjorie", "Martha", "Mary", "Megan",
    "Melanie", "Melissa", "Michele", "Michelle", "Mildred", "Monica",
    "Nancy", "Nicole", "Norma", "Pamela", "Patricia", "Paula", "Pauline",
    "Peggy", "Phyllis", "Rachel", "Rebecca", "Regina", "Renee", "Rhonda",
    "Rita", "Roberta", "Robin", "Rosa", "Rose", "Ruby", "Ruth", "Sally",
    "Samantha", "Sandra", "Sara", "Sarah", "Shannon", "Sharon", "Sheila",
    "Sherry", "Shirley", "Stacy", "Stephanie", "Sue", "Susan", "Suzanne",
    "Sylvia", "Tammy", "Teresa", "Thelma", "Theresa", "Tiffany", "Tina",
    "Tracy", "Valerie", "Vanessa", "Veronica", "Victoria", "Virginia",
    "Vivian", "Wanda", "Wendy", "Yolanda", "Yvonne",
    ];

  // female thug first names
  public static var femaleThugFirst = [
    "Alice", "Lisha", "Alma", "Mandy", "Amber", "Amy", "Ana",
    "Angela", "Neeta", "Ann", "Annie", "April",
    "Bo", "Bernice",
    "Betty", "Beverly", "Bonnie", "Brenda", "Carmen",
    "Kery", "Candy", "Lotte",
    "Sheryl", "Cindy",
    "Crystal", "Dana", "Dani", "Darlene", "Dawn", "Debbie",
    "Dolores", "Donna",
    "Doris", "Elaine",
    "Emma", "Rica",
    "Eva", "Flo", "Frances", "Gail",
    "Gloria", "Hazel", "Helen", "Holly",
    "Jackie", "Jamie", "Jane", "Janet", "Jean",
    "Jen", "Jesse", "Jill", "Jo",
    "Juanita", "Judy",
    "June", "Karen", "Kat",
    "Katie", "Kelly", "Kim", "Kristy", "Lara",
    "Lily", "Lisa", "Lois",
    "Lori", "Lucy", "Lynn", "Margo",
    "Marj", "Meg",
    "Michele",
    "Nancy", "Nico", "Pam", "Pat", "Paula",
    "Peg", "Gina", "Renee", "Rho",
    "Rita", "Rosa", "Rose", "Ruby",
    "Sam", "Sandra", "Sheila",
    "Sherry", "Stacy", "Sue",
    "Tammy", "Tina",
    "Tracy", "Val", "Nessa", "Vicky",
    "Wanda", "Yolanda",
    ];

  // last names
  public static var last = [
    "Adams", "Alexander", "Allen", "Anderson", "Andrews", "Armstrong",
    "Arnold", "Bailey", "Baker", "Barnes", "Bell", "Bennett", "Berry",
    "Bishop", "Black", "Boyd", "Bradley", "Brooks", "Brown", "Bryant",
    "Burke", "Burns", "Butler", "Campbell", "Carlson", "Carpenter",
    "Carr", "Carroll", "Carter", "Chapman", "Clark", "Cole", "Coleman",
    "Collins", "Cook", "Cooper", "Cox", "Crawford", "Cunningham",
    "Davidson", "Davis", "Day", "Dean", "Dixon", "Duncan", "Dunn",
    "Edwards", "Elliott", "Ellis", "Evans", "Ferguson", "Fisher",
    "Ford", "Foster", "Fox", "Freeman", "Gardner", "Gibson", "Gilbert",
    "Gordon", "Graham", "Gray", "Green", "Griffin", "Hall", "Hamilton",
    "Hansen", "Hanson", "Harris", "Harrison", "Hart", "Hayes", "Henderson",
    "Henry", "Hicks", "Hill", "Hoffman", "Holmes", "Howard", "Howell",
    "Hudson", "Hughes", "Hunt", "Hunter", "Jackson", "Jacobs", "James",
    "Jenkins", "Jensen", "Johnson", "Johnston", "Jones", "Jordan",
    "Keller", "Kelley", "Kelly", "Kennedy", "King", "Knight", "Lane",
    "Larson", "Lawrence", "Lawson", "Lee", "Lewis", "Long", "Lynch",
    "Marshall", "Martin", "Mason", "May", "Mcdonald", "Meyer", "Miller",
    "Mills", "Mitchell", "Moore", "Morgan", "Morris", "Morrison", "Murphy",
    "Murray", "Myers", "Nelson", "Nichols", "Obrien", "Olson", "Owens",
    "Palmer", "Parker", "Patterson", "Payne", "Perkins", "Perry", "Peters",
    "Peterson", "Phillips", "Pierce", "Porter", "Powell", "Price", "Ray",
    "Reed", "Reynolds", "Rice", "Richards", "Richardson", "Riley", "Roberts",
    "Robertson", "Robinson", "Rogers", "Rose", "Ross", "Russell", "Ryan",
    "Sanders", "Schmidt", "Schneider", "Schultz", "Scott", "Shaw", "Simmons",
    "Simpson", "Smith", "Snyder", "Spencer", "Stephens", "Stevens", "Stewart",
    "Stone", "Sullivan", "Taylor", "Thomas", "Thompson", "Tucker", "Turner",
    "Wagner", "Walker", "Wallace", "Walsh", "Walters", "Ward", "Warren",
    "Watson", "Weaver", "Webb", "Weber", "Welch", "Wells", "West", "Wheeler",
    "White", "Williams", "Williamson", "Wilson", "Wood", "Woods", "Wright",
    "Young",
    ];
}
