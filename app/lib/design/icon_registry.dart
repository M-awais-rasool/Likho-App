import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Course data names icons as strings (Material Symbols names). Only these
/// are bundled; an unknown name shows [fallback] instead of crashing.
abstract final class IconRegistry {
  static const fallback = Symbols.star_rounded;

  static IconData of(String name) => _icons[name] ?? fallback;

  static const Map<String, IconData> _icons = {
    // worlds
    'grass': Symbols.grass_rounded,
    'waves': Symbols.waves_rounded,
    'forest': Symbols.forest_rounded,
    'location_city': Symbols.location_city_rounded,
    'cloud': Symbols.cloud_rounded,
    'rocket_launch': Symbols.rocket_launch_rounded,
    // levels
    'self_improvement': Symbols.self_improvement_rounded,
    'celebration': Symbols.celebration_rounded,
    'train': Symbols.train_rounded,
    'directions_railway': Symbols.directions_railway_rounded,
    'route': Symbols.route_rounded,
    'phishing': Symbols.phishing_rounded,
    'bedtime': Symbols.bedtime_rounded,
    'spa': Symbols.spa_rounded,
    'beach_access': Symbols.beach_access_rounded,
    'bubble_chart': Symbols.bubble_chart_rounded,
    'shopping_basket': Symbols.shopping_basket_rounded,
    'mail': Symbols.mail_rounded,
    'pets': Symbols.pets_rounded,
    'linear_scale': Symbols.linear_scale_rounded,
    'visibility': Symbols.visibility_rounded,
    'emoji_objects': Symbols.emoji_objects_rounded,
    'format_paint': Symbols.format_paint_rounded,
    'directions_bus': Symbols.directions_bus_rounded,
    'medical_services': Symbols.medical_services_rounded,
    'cake': Symbols.cake_rounded,
    'photo_library': Symbols.photo_library_rounded,
    'air': Symbols.air_rounded,
    'flutter_dash': Symbols.flutter_dash_rounded,
    'looks': Symbols.looks_rounded,
    'edit': Symbols.edit_rounded,
    'public': Symbols.public_rounded,
    'record_voice_over': Symbols.record_voice_over_rounded,
    'view_carousel': Symbols.view_carousel_rounded,
    'auto_awesome': Symbols.auto_awesome_rounded,
    'auto_stories': Symbols.auto_stories_rounded,
    'dark_mode': Symbols.dark_mode_rounded,
    // mascot room items
    'image': Symbols.image_rounded,
    'potted_plant': Symbols.potted_plant_rounded,
    'blur_circular': Symbols.blur_circular_rounded,
  };
}
