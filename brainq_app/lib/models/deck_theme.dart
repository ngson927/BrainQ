class DeckTheme {
  final int? id;
  final String? name;
  final String? description;

  final String? fontFamily;
  final String? layoutStyle;

  final String? backgroundColor;
  final String? textColor;
  final String? accentColor;


  final String? cardColor;
  final double? elevation;

  final double? borderRadius;
  final double? cardSpacing;
  final double? fontSize;

  final bool? isDefault;
  final bool? isSystemTheme;

  final String? previewImage;


  DeckTheme({
    this.id,
    this.name,
    this.description,
    this.fontFamily,
    this.layoutStyle,
    this.backgroundColor,
    this.textColor,
    this.accentColor,
    this.cardColor,
    this.elevation,
    this.borderRadius,
    this.cardSpacing,
    this.fontSize,
    this.isDefault,
    this.isSystemTheme,
    this.previewImage,
  });

  // =========================
  // FROM BACKEND JSON
  // =========================

  

  factory DeckTheme.fromJson(Map<String, dynamic> json) {
    return DeckTheme(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      fontFamily: json['font_family'],
      layoutStyle: json['layout_style'],
      backgroundColor: json['background_color'],
      textColor: json['text_color'],
      accentColor: json['accent_color'],
      borderRadius: (json['border_radius'] as num?)?.toDouble(),
      cardSpacing: (json['card_spacing'] as num?)?.toDouble(),
      fontSize: (json['font_size'] as num?)?.toDouble(),
      isDefault: json['is_default'],
      isSystemTheme: json['is_system_theme'],
      previewImage: json['preview_image'],

      cardColor: json['card_color'],
      elevation: (json['elevation'] as num?)?.toDouble(),
    );
  }

  // =========================
  // TO BACKEND (API SEND)
  // =========================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'font_family': fontFamily,
      'layout_style': layoutStyle,
      'background_color': backgroundColor,
      'text_color': textColor,
      'accent_color': accentColor,
      'border_radius': borderRadius,
      'card_spacing': cardSpacing,
      'font_size': fontSize,
      'is_default': isDefault,
      'is_system_theme': isSystemTheme,
      'preview_image': previewImage,
      'card_color': cardColor,
      'elevation': elevation,
    };
  }

  // =========================
  // COPY WITH
  // =========================

  DeckTheme copyWith({
    int? id,
    String? name,
    String? description,
    String? fontFamily,
    String? layoutStyle,
    String? backgroundColor,
    String? textColor,
    String? accentColor,
    String? cardColor,
    double? elevation,
    double? borderRadius,
    double? cardSpacing,
    double? fontSize,
    bool? isDefault,
    bool? isSystemTheme,
    String? previewImage,
  }) {
    return DeckTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      fontFamily: fontFamily ?? this.fontFamily,
      layoutStyle: layoutStyle ?? this.layoutStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      accentColor: accentColor ?? this.accentColor,
      cardColor: cardColor ?? this.cardColor,
      elevation: elevation ?? this.elevation,
      borderRadius: borderRadius ?? this.borderRadius,
      cardSpacing: cardSpacing ?? this.cardSpacing,
      fontSize: fontSize ?? this.fontSize,
      isDefault: isDefault ?? this.isDefault,
      isSystemTheme: isSystemTheme ?? this.isSystemTheme,
      previewImage: previewImage ?? this.previewImage,
    );
  }
  // =========================
  // SYSTEM DEFAULT THEME
  // =========================
  static DeckTheme defaultTheme() {
    return DeckTheme(
      id: 13,
      name: 'System Default Theme',
      description: 'Default theme for all new decks without a theme',
      backgroundColor: '#FFFFFF',
      textColor: '#000000',
      accentColor: '#4F46E5',
      fontFamily: 'Roboto',
      fontSize: 14,
      layoutStyle: 'classic',
      borderRadius: 8,
      cardSpacing: 12,
      isDefault: true,
      isSystemTheme: true,
      previewImage: null,
      elevation: 1,
      cardColor: '#FFFFFF',
    );
  }
}
