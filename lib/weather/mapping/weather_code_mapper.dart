class WeatherCodeMapper {
  const WeatherCodeMapper._();

  static String description(int code) => switch (code) {
    0 => 'Ciel dégagé',
    1 => 'Peu nuageux',
    2 => 'Partiellement nuageux',
    3 => 'Couvert',
    45 || 48 => 'Brouillard',
    51 || 53 || 55 => 'Bruine',
    56 || 57 => 'Bruine verglaçante',
    61 || 63 || 65 => 'Pluie',
    66 || 67 => 'Pluie verglaçante',
    71 || 73 || 75 || 77 => 'Neige',
    80 || 81 || 82 => 'Averses',
    85 || 86 => 'Averses de neige',
    95 || 96 || 99 => 'Orage',
    _ => 'Condition inconnue',
  };
}
