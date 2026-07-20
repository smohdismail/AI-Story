import 'dart:math';

class NameGenerator {
  static final Random _random = Random();

  static const List<String> _fantasyPrefixes = [
    'Ael', 'Aer', 'Af', 'Ah', 'Al', 'Am', 'Ama', 'An', 'Ang', 'Ar', 'Aran', 'Arg', 'Ariel',
    'Bael', 'Bes', 'Bhal', 'Bryn', 'Cal', 'Cael', 'Cer', 'Cy', 'Dae', 'Dal', 'Dar', 'Del',
    'El', 'Elen', 'Er', 'Ery', 'Fael', 'Fae', 'Fara', 'Fen', 'Gae', 'Gal', 'Gar', 'Glyn',
    'Hal', 'Heli', 'Ila', 'Ily', 'Ior', 'Kae', 'Kal', 'Kel', 'Ky', 'La', 'Lari', 'Lor',
    'Ma', 'Mar', 'Mel', 'Na', 'Neri', 'Ny', 'Olo', 'Or', 'Per', 'Quin', 'Rae', 'Re', 'Rh',
    'Sa', 'Sari', 'Sel', 'Syl', 'Ta', 'Tari', 'Thal', 'Ty', 'Ula', 'Uri', 'Vae', 'Val', 'Xy', 'Yl', 'Za'
  ];

  static const List<String> _fantasySuffixes = [
    'a', 'ae', 'aera', 'ai', 'am', 'an', 'ar', 'as', 'ash', 'ath', 'd', 'da', 'dan', 'dar',
    'des', 'dis', 'drim', 'e', 'el', 'en', 'er', 'ess', 'eth', 'ey', 'f', 'fa', 'fel', 'fin',
    'g', 'ga', 'gal', 'gath', 'gen', 'h', 'ha', 'hal', 'har', 'hel', 'i', 'ia', 'ian', 'ias',
    'iel', 'ien', 'il', 'in', 'ir', 'is', 'ith', 'k', 'ka', 'kan', 'kar', 'l', 'la', 'lan',
    'las', 'len', 'lin', 'lis', 'm', 'ma', 'man', 'mar', 'men', 'min', 'n', 'na', 'nan', 'nar',
    'nen', 'nia', 'nin', 'o', 'on', 'or', 'os', 'oth', 'r', 'ra', 'ran', 'ras', 'ren', 'ria',
    'rin', 'ris', 'roth', 's', 'sa', 'san', 'sar', 'sen', 'sia', 'sin', 'th', 'tha', 'than',
    'thar', 'then', 'thia', 'thin', 'u', 'us', 'v', 'va', 'van', 'var', 'ven', 'via', 'vin',
    'w', 'wa', 'wan', 'war', 'wen', 'win', 'y', 'ya', 'yan', 'yar', 'yen', 'yin', 'z', 'za', 'zan'
  ];

  static const List<String> _sciFiFirsts = [
    'Axi', 'Cyr', 'Dax', 'Eos', 'Fy', 'Gal', 'Hux', 'Iro', 'Jex', 'Kael', 'Lum', 'Myx',
    'Nyx', 'Ony', 'Pyr', 'Qor', 'Ryx', 'Syl', 'Tyx', 'Urx', 'Vex', 'Wyx', 'Xan', 'Yro', 'Zor',
    'Zeta', 'Nova', 'Orion', 'Lyra', 'Cass', 'Vega', 'Alta', 'Rigel', 'Sirius', 'Bell'
  ];

  static const List<String> _sciFiLasts = [
    'Prime', 'Vanguard', 'Apex', 'Core', 'Stark', 'Flux', 'Void', 'Sol', 'Ion', 'Zenith',
    'Vortex', 'Cypher', 'Nebula', 'Pulsar', 'Quasar', 'Tachyon', 'Matrix', 'Vector', 'Nexus',
    'Helios', 'Ares', 'Atlas', 'Chronos', 'Hyperion', 'Kratos', 'Titan', 'Valkyrie', 'Odin'
  ];

  static const List<String> _modernFirsts = [
    'James', 'Mary', 'John', 'Patricia', 'Robert', 'Jennifer', 'Michael', 'Linda', 'William',
    'Elizabeth', 'David', 'Barbara', 'Richard', 'Susan', 'Joseph', 'Jessica', 'Thomas', 'Sarah',
    'Charles', 'Karen', 'Christopher', 'Nancy', 'Daniel', 'Lisa', 'Matthew', 'Betty', 'Anthony',
    'Margaret', 'Mark', 'Sandra', 'Donald', 'Ashley', 'Steven', 'Kimberly', 'Paul', 'Emily',
    'Andrew', 'Donna', 'Joshua', 'Michelle', 'Kenneth', 'Dorothy', 'Kevin', 'Carol', 'Brian',
    'Amanda', 'George', 'Melissa', 'Edward', 'Deborah', 'Emma', 'Olivia', 'Ava', 'Isabella',
    'Sophia', 'Mia', 'Charlotte', 'Amelia', 'Harper', 'Evelyn', 'Abigail', 'Liam', 'Noah',
    'Oliver', 'Elijah', 'William', 'James', 'Benjamin', 'Lucas', 'Henry', 'Alexander', 'Mason'
  ];

  static const List<String> _modernLasts = [
    'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez',
    'Martinez', 'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson', 'Thomas', 'Taylor',
    'Moore', 'Jackson', 'Martin', 'Lee', 'Perez', 'Thompson', 'White', 'Harris', 'Sanchez',
    'Clark', 'Ramirez', 'Lewis', 'Robinson', 'Walker', 'Young', 'Allen', 'King', 'Wright',
    'Scott', 'Torres', 'Nguyen', 'Hill', 'Flores', 'Green', 'Adams', 'Nelson', 'Baker', 'Hall',
    'Rivera', 'Campbell', 'Mitchell', 'Carter', 'Roberts', 'Gomez', 'Phillips', 'Evans',
    'Turner', 'Diaz', 'Parker', 'Cruz', 'Edwards', 'Collins', 'Reyes', 'Stewart', 'Morris'
  ];

  static String generateFantasyName() {
    String name = _fantasyPrefixes[_random.nextInt(_fantasyPrefixes.length)] +
        _fantasySuffixes[_random.nextInt(_fantasySuffixes.length)];
    // 30% chance for a multi-syllable or title
    if (_random.nextDouble() < 0.3) {
      name += _fantasySuffixes[_random.nextInt(_fantasySuffixes.length)];
    }
    // 20% chance for a last name
    if (_random.nextDouble() < 0.2) {
      name += " " + _fantasyPrefixes[_random.nextInt(_fantasyPrefixes.length)] + _fantasySuffixes[_random.nextInt(_fantasySuffixes.length)];
    }
    // Capitalize properly
    return name.split(' ').map((e) => e.substring(0, 1).toUpperCase() + e.substring(1).toLowerCase()).join(' ');
  }

  static String generateSciFiName() {
    String first = _sciFiFirsts[_random.nextInt(_sciFiFirsts.length)];
    if (_random.nextDouble() < 0.5) {
      first += ['a', 'on', 'en', 'is', 'us', 'ex', 'or'][_random.nextInt(7)];
    }
    String last = _sciFiLasts[_random.nextInt(_sciFiLasts.length)];
    return "$first $last";
  }

  static String generateModernName() {
    return "${_modernFirsts[_random.nextInt(_modernFirsts.length)]} ${_modernLasts[_random.nextInt(_modernLasts.length)]}";
  }
}
