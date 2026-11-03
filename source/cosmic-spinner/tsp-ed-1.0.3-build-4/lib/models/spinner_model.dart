// ////Block One//////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

class SpinnerModel {
  SpinnerModel({
    required this.id,
    required this.title,
    required List<String> slices,
    required this.colorValue,
    this.isTemplate = false,
    this.scheme = WheelScheme.classic,
    this.category = '',
  }) : slices = List<String>.unmodifiable(slices) {
    if (id.trim().isEmpty ||
        slices.length < 2 ||
        slices.length > 20 ||
        colorValue < 0 ||
        colorValue > 0xFFFFFFFF) {
      throw const FormatException("Invalid spinner");
    }
  }

  final String id;
  final String title;
  final List<String> slices;
  final int colorValue;
  final bool isTemplate;
  final WheelScheme scheme;
  final String category;

  Color get color => Color(colorValue);

  Color sliceColor(int index) {
    final colors = scheme.colors;
    if (colors.isNotEmpty) {
      var slot = index % colors.length;
      // Avoid matching colors where the last wedge meets the first.
      if (index == slices.length - 1 && slot == 0) slot = 1;
      return Color(colors[slot]);
    }
    final hsl = HSLColor.fromColor(color);
    const adjustments = [-0.09, 0.04, -0.03, 0.10];
    return hsl
        .withLightness(
          (hsl.lightness + adjustments[index % adjustments.length]).clamp(
            0.22,
            0.78,
          ),
        )
        .toColor();
  }

  Color sliceTextColor(int index) =>
      sliceColor(index).computeLuminance() > 0.179
      ? Colors.black
      : Colors.white;

  SpinnerModel copyWith({
    String? id,
    String? title,
    List<String>? slices,
    int? colorValue,
    bool? isTemplate,
    WheelScheme? scheme,
    String? category,
  }) {
    return SpinnerModel(
      id: id ?? this.id,
      title: title ?? this.title,
      slices: slices ?? List<String>.from(this.slices),
      colorValue: colorValue ?? this.colorValue,
      isTemplate: isTemplate ?? this.isTemplate,
      scheme: scheme ?? this.scheme,
      category: category ?? this.category,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'slices': slices,
    'colorValue': colorValue,
    'isTemplate': isTemplate,
    'scheme': scheme.name,
    'category': category,
  };

  factory SpinnerModel.fromJson(Map<String, Object?> json) {
    return SpinnerModel(
      id: json['id']! as String,
      title: json['title']! as String,
      slices: (json['slices']! as List<Object?>).cast<String>(),
      colorValue: json['colorValue']! as int,
      isTemplate: json['isTemplate'] as bool? ?? false,
      category: json['category'] as String? ?? '',
      scheme:
          WheelScheme.values
              .where((value) => value.name == json['scheme'])
              .firstOrNull ??
          WheelScheme.classic,
    );
  }
}

enum WheelScheme {
  cosmic('Cosmic', [
    0xFF7354C2,
    0xFF167D8D,
    0xFFB83F73,
    0xFF4657B0,
    0xFF237A62,
    0xFFB9582D,
  ]),
  ocean('Ocean', [
    0xFF235789,
    0xFF168C9A,
    0xFF536FAD,
    0xFF77C5C4,
    0xFF254C67,
    0xFF439BBA,
  ]),
  sunset('Sunset', [
    0xFFB94D32,
    0xFFF5AF64,
    0xFFB83F73,
    0xFF70479B,
    0xFFE97C68,
    0xFF973B60,
  ]),
  forest('Forest', [
    0xFF28634B,
    0xFF97B878,
    0xFF96643D,
    0xFFD7AB55,
    0xFF547B42,
    0xFF638F85,
  ]),
  classic('Classic', []);

  const WheelScheme(this.label, this.colors);
  final String label;
  final List<int> colors;
}

// ////Block Two//////////////////////////////////////////////////////////////
const List<Color> spinnerPalette = <Color>[
  Color(0xFFF04444),
  Color(0xFFFF8C32),
  Color(0xFFFFD23F),
  Color(0xFF42D66B),
  Color(0xFF19C6B3),
  Color(0xFF37A7FF),
  Color(0xFF7667F5),
  Color(0xFFC85CFF),
  Color(0xFFF05AA6),
  Color(0xFF8B5A3C),
];

final List<SpinnerModel> spinnerTemplates = <SpinnerModel>[
  SpinnerModel(
    id: 'template-eat',
    scheme: WheelScheme.cosmic,
    title: 'Places to Eat',
    slices: const <String>[
      'Pizza',
      'Tacos',
      'Burgers',
      'Sushi',
      'Italian',
      'Surprise me',
    ],
    colorValue: spinnerPalette[0].toARGB32(),
    isTemplate: true,
  ),
  SpinnerModel(
    id: 'template-movie',
    scheme: WheelScheme.sunset,
    title: 'Movie Night',
    slices: const <String>[
      'Comedy',
      'Action',
      'Sci-fi',
      'Drama',
      'Animation',
      'Documentary',
    ],
    colorValue: spinnerPalette[6].toARGB32(),
    isTemplate: true,
  ),
  SpinnerModel(
    id: 'template-weekend',
    scheme: WheelScheme.forest,
    title: 'What Should We Do?',
    slices: const <String>[
      'Go outside',
      'Game night',
      'Try a recipe',
      'Call a friend',
      'Read',
      'Nap',
    ],
    colorValue: spinnerPalette[3].toARGB32(),
    isTemplate: true,
  ),
];
