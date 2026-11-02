// Block One ////////////////////////////////////////////////////////////////
// Unit definitions, labels, and normalization

const Map<String, List<String>> unitsByCategory = {
  'length': [
    'mm',
    'cm',
    'm',
    'km',
    'in',
    'ft',
    'yd',
    'mi',
    'lightyear',
    'planck_length',
  ],
  'weight': ['g', 'kg', 'oz', 'lb', 'us_ton', 'metric_ton', 'planck_mass'],
  'volume': ['mL', 'L', 'tsp', 'tbsp', 'fl_oz', 'cup', 'pt', 'qt', 'gal'],
  'temperature': ['celsius', 'fahrenheit', 'kelvin', 'planck_temperature'],
  'speed': [
    'mps',
    'kmh',
    'mph',
    'speed_of_light',
    'speed_of_sound',
    'lightyears_per_second',
    'lightyears_per_hour',
  ],
  'time': [
    'ms',
    's',
    'min',
    'hr',
    'day',
    'week',
    'month',
    'year',
    'lightyear_time',
    'planck_time',
  ],
  'digital_storage': ['b', 'B', 'KB', 'MB', 'GB', 'TB'],
};

const List<String> categories = [
  'length',
  'weight',
  'volume',
  'weight_volume',
  'temperature',
  'speed',
  'time',
  'digital_storage',
];

const Map<String, String> unitCategoryMap = {
  // Length
  'm': 'length',
  'ft': 'length',
  'km': 'length',
  'mi': 'length',
  'cm': 'length',
  'mm': 'length',
  'in': 'length',
  'yd': 'length',
  'lightyear': 'length',
  'planck_length': 'length',

  // Weight
  'g': 'weight',
  'kg': 'weight',
  'lb': 'weight',
  'oz': 'weight',
  'us_ton': 'weight',
  'metric_ton': 'weight',
  'planck_mass': 'weight',

  // Volume
  'l': 'volume',
  'ml': 'volume',
  'fl_oz': 'volume',
  'fl oz': 'volume',
  'floz': 'volume',
  'tsp': 'volume',
  'teaspoon': 'volume',
  'teaspoons': 'volume',
  'tbsp': 'volume',
  'tablespoon': 'volume',
  'tablespoons': 'volume',
  'gal': 'volume',
  'qt': 'volume',
  'pt': 'volume',
  'cup': 'volume',

  // Temperature
  'celsius': 'temperature',
  'fahrenheit': 'temperature',
  'kelvin': 'temperature',
  'planck_temperature': 'temperature',

  // Speed
  'mps': 'speed',
  'kmh': 'speed',
  'mph': 'speed',
  'speed_of_light': 'speed',
  'speed_of_sound': 'speed',
  'lightyears_per_second': 'speed',
  'lightyears_per_hour': 'speed',

  // Time
  's': 'time',
  'ms': 'time',
  'min': 'time',
  'hr': 'time',
  'day': 'time',
  'week': 'time',
  'month': 'time',
  'year': 'time',
  'lightyear_time': 'time',
  'planck_time': 'time',

  // Digital storage
  'b': 'digital_storage',
  'byte': 'digital_storage',
  'kb': 'digital_storage',
  'mb': 'digital_storage',
  'gb': 'digital_storage',
  'tb': 'digital_storage',
};

String canonicalizeUnit(String unit) {
  // Uppercase B means byte, while lowercase b means bit.
  if (unit.trim() == 'B') {
    return 'B';
  }

  final normalized = unit.trim().toLowerCase();

  const canonicalUnits = {
    // Volume
    'ml': 'mL',
    'l': 'L',
    'fl_oz': 'fl_oz',
    'fl oz': 'fl_oz',
    'floz': 'fl_oz',
    'tsp': 'tsp',
    'teaspoon': 'tsp',
    'teaspoons': 'tsp',
    'tbsp': 'tbsp',
    'tablespoon': 'tbsp',
    'tablespoons': 'tbsp',
    'cup': 'cup',
    'pt': 'pt',
    'qt': 'qt',
    'gal': 'gal',

    // Weight
    'g': 'g',
    'kg': 'kg',
    'oz': 'oz',
    'lb': 'lb',
    'us_ton': 'us_ton',
    'metric_ton': 'metric_ton',
    'ton': 'metric_ton',

    // Digital storage
    'kb': 'KB',
    'mb': 'MB',
    'gb': 'GB',
    'tb': 'TB',
    'b': 'b',
    'byte': 'B',
  };

  final explicitlyCanonical = canonicalUnits[normalized];
  if (explicitlyCanonical != null) return explicitlyCanonical;

  // Most canonical identifiers are lowercase. Accept case-insensitive input
  // for those identifiers while preserving the meaningful b/B distinction.
  if (unitCategoryMap.containsKey(normalized)) return normalized;

  return unit.trim();
}

String detectCategory(String unit) {
  final normalized = canonicalizeUnit(unit).toLowerCase();
  return unitCategoryMap[normalized] ?? 'unknown';
}

List<String> availableUnitsForCategory(String? category) {
  if (category == null) return [];

  // Only the combined category cross-converts using water density.
  if (category == 'weight_volume') {
    return [...unitsByCategory['weight']!, ...unitsByCategory['volume']!];
  }

  return unitsByCategory[category] ?? const [];
}

String displayCategory(String category) {
  switch (category) {
    case 'weight':
      return 'WEIGHT';
    case 'volume':
      return 'VOLUME';
    case 'weight_volume':
      return 'WEIGHT ↔ VOLUME';
    default:
      return category.toUpperCase();
  }
}

bool isWeightVolumeCategory(String? category) => category == 'weight_volume';

bool usesFixedThirtyDayMonth(String? from, String? to) =>
    canonicalizeUnit(from ?? '') == 'month' ||
    canonicalizeUnit(to ?? '') == 'month';

String displayUnit(String unit) {
  const displayUnits = {
    // Length
    'lightyear': 'light-year',
    'planck_length': 'Planck length',

    // Weight
    'us_ton': 'US ton',
    'metric_ton': 'metric ton',
    'planck_mass': 'Planck mass',

    // Volume
    'tsp': 'tsp (US)',
    'tbsp': 'tbsp (US)',
    'fl_oz': 'fl oz (US)',

    // Temperature
    'celsius': '°C (Celsius)',
    'fahrenheit': '°F (Fahrenheit)',
    'kelvin': 'K (Kelvin)',
    'planck_temperature': 'Planck temperature',

    // Speed
    'mps': 'm/s',
    'kmh': 'km/h',
    'mph': 'mph',
    'speed_of_light': 'speed of light',
    'speed_of_sound': 'speed of sound',
    'lightyears_per_second': 'light-years/second',
    'lightyears_per_hour': 'light-years/hour',

    // Time
    'ms': 'ms',
    's': 'sec',
    'min': 'min',
    'hr': 'hr',
    'day': 'day',
    'week': 'week',
    'month': 'month',
    'year': 'year',
    'lightyear_time': 'light-year time',
    'planck_time': 'Planck time',

    // Digital storage
    'b': 'b (bit)',
    'B': 'B (byte)',
  };

  return displayUnits[unit] ?? unit;
}

const Map<String, double> _gramsPerWeightUnit = {
  'g': 1.0,
  'kg': 1000.0,
  'lb': 453.59237,
  'oz': 28.349523125,
  'us_ton': 907_184.74,
  'metric_ton': 1_000_000.0,
  'planck_mass': 2.176434e-5,
};

const Map<String, double> _litersPerVolumeUnit = {
  'L': 1.0,
  'mL': 0.001,
  'tsp': 0.00492892159375,
  'tbsp': 0.01478676478125,
  'fl_oz': 0.0295735295625,
  'cup': 0.2365882365,
  'pt': 0.473176473,
  'qt': 0.946352946,
  'gal': 3.785411784,
};

// Block Two ////////////////////////////////////////////////////////////////
// Conversion calculations

double? convertValue(double value, String from, String to) {
  final canonicalFrom = canonicalizeUnit(from);
  final canonicalTo = canonicalizeUnit(to);
  final fromCat = detectCategory(canonicalFrom);
  final toCat = detectCategory(canonicalTo);

  double? convertUsingFactors(Map<String, double> factors) {
    final fromFactor = factors[canonicalFrom];
    final toFactor = factors[canonicalTo];
    if (fromFactor == null || toFactor == null) return null;
    return value * fromFactor / toFactor;
  }

  if (fromCat == 'length' && toCat == 'length') {
    const meters = {
      'm': 1.0,
      'km': 1000.0,
      'cm': 0.01,
      'mm': 0.001,
      'ft': 0.3048,
      'in': 0.0254,
      'yd': 0.9144,
      'mi': 1609.344,
      'lightyear': 9.4607e15,
      'planck_length': 1.616255e-35,
    };
    return convertUsingFactors(meters);
  }

  if (fromCat == 'weight' && toCat == 'weight') {
    return convertUsingFactors(_gramsPerWeightUnit);
  }

  if (fromCat == 'volume' && toCat == 'volume') {
    return convertUsingFactors(_litersPerVolumeUnit);
  }

  if (fromCat == 'temperature' && toCat == 'temperature') {
    double? toKelvin(double input, String unit) {
      switch (unit) {
        case 'celsius':
          return input + 273.15;
        case 'fahrenheit':
          return (input - 32) * 5 / 9 + 273.15;
        case 'kelvin':
          return input;
        case 'planck_temperature':
          return input * 1.416784e32;
      }
      return null;
    }

    double? fromKelvin(double kelvin, String unit) {
      switch (unit) {
        case 'celsius':
          return kelvin - 273.15;
        case 'fahrenheit':
          return (kelvin - 273.15) * 9 / 5 + 32;
        case 'kelvin':
          return kelvin;
        case 'planck_temperature':
          return kelvin / 1.416784e32;
      }
      return null;
    }

    final kelvin = toKelvin(value, canonicalFrom);
    if (kelvin == null) return null;
    return fromKelvin(kelvin, canonicalTo);
  }

  if (fromCat == 'speed' && toCat == 'speed') {
    const mps = {
      'mps': 1.0,
      'kmh': 1 / 3.6,
      'mph': 0.44704,
      'speed_of_light': 299792458.0,
      'speed_of_sound': 343.0,
      'lightyears_per_second': 9.4607e15,
      'lightyears_per_hour': 9.4607e15 / 3600,
    };
    return convertUsingFactors(mps);
  }

  if (fromCat == 'time' && toCat == 'time') {
    const seconds = {
      's': 1.0,
      'ms': 0.001,
      'min': 60.0,
      'hr': 3600.0,
      'day': 24.0 * 3600,
      'week': 7.0 * 24 * 3600,
      'month': 30.0 * 24 * 3600,
      'year': 365.25 * 24 * 3600,
      'lightyear_time': 365.25 * 24 * 3600,
      'planck_time': 5.391247e-44,
    };
    return convertUsingFactors(seconds);
  }

  if (fromCat == 'digital_storage' && toCat == 'digital_storage') {
    const bytes = {
      'b': 0.125,
      'B': 1.0,
      'KB': 1024.0,
      'MB': 1024.0 * 1024.0,
      'GB': 1024.0 * 1024.0 * 1024.0,
      'TB': 1024.0 * 1024.0 * 1024.0 * 1024.0,
    };
    return convertUsingFactors(bytes);
  }

  final isWaterConversion =
      (fromCat == 'volume' && toCat == 'weight') ||
      (fromCat == 'weight' && toCat == 'volume');

  if (isWaterConversion) {
    if (fromCat == 'volume' && toCat == 'weight') {
      final fromFactor = _litersPerVolumeUnit[canonicalFrom];
      final toFactor = _gramsPerWeightUnit[canonicalTo];
      if (fromFactor == null || toFactor == null) return null;
      final litersValue = value * fromFactor;
      final gramsValue = litersValue * 1000.0;
      return gramsValue / toFactor;
    }

    if (fromCat == 'weight' && toCat == 'volume') {
      final fromFactor = _gramsPerWeightUnit[canonicalFrom];
      final toFactor = _litersPerVolumeUnit[canonicalTo];
      if (fromFactor == null || toFactor == null) return null;
      final gramsValue = value * fromFactor;
      final litersValue = gramsValue / 1000.0;
      return litersValue / toFactor;
    }
  }

  return null;
}
