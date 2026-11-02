import 'package:flutter_test/flutter_test.dart';
import 'package:unit_converter/conversion_engine.dart';

void main() {
  group('category unit lists', () {
    test('weight contains only weight units', () {
      final units = availableUnitsForCategory('weight');

      expect(units, unitsByCategory['weight']);
      expect(units, isNot(contains('L')));
      expect(units, isNot(contains('fl_oz')));
    });

    test('volume contains only volume units including US kitchen measures', () {
      final units = availableUnitsForCategory('volume');

      expect(units, unitsByCategory['volume']);
      expect(units, containsAll(['tsp', 'tbsp']));
      expect(units, contains('fl_oz'));
      expect(units, isNot(contains('kg')));
    });

    test('there is one combined weight and volume category', () {
      expect(
        categories.where((category) => category == 'weight_volume'),
        hasLength(1),
      );
      expect(availableUnitsForCategory('weight_volume'), [
        ...unitsByCategory['weight']!,
        ...unitsByCategory['volume']!,
      ]);
    });
  });

  group('US fluid ounce conversions', () {
    test('one fluid ounce equals the exact milliliter conversion', () {
      expect(convertValue(1, 'fl_oz', 'mL'), closeTo(29.5735295625, 1e-10));
    });

    test('128 fluid ounces equals one US gallon', () {
      expect(convertValue(128, 'fl_oz', 'gal'), closeTo(1, 1e-12));
    });

    test('fluid ounces cross-convert to water weight', () {
      expect(convertValue(1, 'fl_oz', 'g'), closeTo(29.5735295625, 1e-10));
    });
  });

  group('US teaspoon and tablespoon conversions', () {
    test('three teaspoons equal one tablespoon', () {
      expect(convertValue(3, 'tsp', 'tbsp'), closeTo(1, 1e-12));
    });

    test('two tablespoons equal one fluid ounce', () {
      expect(convertValue(2, 'tbsp', 'fl_oz'), closeTo(1, 1e-12));
    });

    test('sixteen tablespoons equal one US cup', () {
      expect(convertValue(16, 'tbsp', 'cup'), closeTo(1, 1e-12));
    });

    test('full-name aliases canonicalize before conversion', () {
      expect(convertValue(3, 'Teaspoons', 'Tablespoon'), closeTo(1, 1e-12));
    });

    test('kitchen measures cross-convert to water weight', () {
      expect(convertValue(1, 'tbsp', 'g'), closeTo(14.78676478125, 1e-10));
      expect(convertValue(1, 'tsp', 'g'), closeTo(4.92892159375, 1e-10));
    });
  });

  group('conversion entry-point canonicalization', () {
    test('normalizes casing before length and volume lookup', () {
      expect(convertValue(1, 'KM', 'M'), closeTo(1000, 1e-12));
      expect(convertValue(1, 'ML', 'l'), closeTo(0.001, 1e-12));
    });

    test('normalizes aliases before volume and storage lookup', () {
      expect(convertValue(1, 'Fl Oz', 'ML'), closeTo(29.5735295625, 1e-10));
      expect(convertValue(1, 'byte', 'b'), closeTo(8, 1e-12));
    });

    test('normalizes units before water cross-conversion', () {
      expect(convertValue(1, 'L', 'KG'), closeTo(1, 1e-12));
      expect(convertValue(1000, 'G', 'l'), closeTo(1, 1e-12));
    });

    test('unknown and incompatible units fail safely', () {
      expect(convertValue(1, 'not_a_unit', 'm'), isNull);
      expect(convertValue(1, 'm', 'kg'), isNull);
      expect(availableUnitsForCategory('not_a_category'), isEmpty);
    });
  });

  group('representative conversion regression coverage', () {
    test('length', () {
      expect(convertValue(1, 'mi', 'km'), closeTo(1.609344, 1e-12));
    });

    test('weight', () {
      expect(convertValue(1, 'kg', 'lb'), closeTo(2.20462262185, 1e-10));
    });

    test('temperature', () {
      expect(convertValue(32, 'fahrenheit', 'celsius'), closeTo(0, 1e-12));
    });

    test('speed', () {
      expect(convertValue(36, 'kmh', 'mps'), closeTo(10, 1e-12));
    });

    test('time', () {
      expect(convertValue(2, 'hr', 'min'), closeTo(120, 1e-12));
    });

    test('digital storage', () {
      expect(convertValue(1, 'KB', 'B'), closeTo(1024, 1e-12));
    });

    test('water weight and volume in both directions', () {
      expect(convertValue(1, 'L', 'kg'), closeTo(1, 1e-12));
      expect(convertValue(1, 'kg', 'L'), closeTo(1, 1e-12));
    });
  });
}
