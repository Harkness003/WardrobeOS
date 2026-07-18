import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/weather/mapping/weather_code_mapper.dart';

void main() {
  test('convertit les principaux groupes de codes WMO', () {
    expect(WeatherCodeMapper.description(0), 'Ciel dégagé');
    expect(WeatherCodeMapper.description(45), 'Brouillard');
    expect(WeatherCodeMapper.description(63), 'Pluie');
    expect(WeatherCodeMapper.description(75), 'Neige');
    expect(WeatherCodeMapper.description(95), 'Orage');
  });

  test('conserve une description sûre pour un code futur', () {
    expect(WeatherCodeMapper.description(123), 'Condition inconnue');
  });
}
