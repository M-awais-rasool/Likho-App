import 'package:flutter/foundation.dart';

import '../mascot/mascot.dart';

enum ShopKind { wear, room }

/// Something the child can buy with stars in the Mascot Room (prototype ITEMS).
@immutable
class ShopItem {
  const ShopItem({required this.id, required this.name, required this.price, required this.kind, this.accessory, this.icon});

  final String id;
  final String name;
  final int price;
  final ShopKind kind;

  /// [MascotAccessory] id Pencil wears (wear items).
  final String? accessory;

  /// Icon name in the icon registry (room items).
  final String? icon;

  bool get isWear => kind == ShopKind.wear;

  static ShopItem? byId(String? id) {
    for (final i in all) {
      if (i.id == id) return i;
    }
    return null;
  }

  /// The prototype's ten wearables mapped onto the ten Gemini accessories.
  /// Where the art differs the name follows the art: the prototype's
  /// "Oon topi" (beanie) is the Gemini cap and its sunglasses are the star
  /// glasses. Pencil wears one accessory at a time.
  static const all = [
    ShopItem(id: 'party', name: 'Party topi', price: 8, kind: ShopKind.wear, accessory: MascotAccessory.partyHat),
    ShopItem(id: 'cap', name: 'Cap', price: 12, kind: ShopKind.wear, accessory: MascotAccessory.cap),
    ShopItem(id: 'wizard', name: 'Lambi topi', price: 20, kind: ShopKind.wear, accessory: MascotAccessory.wizardHat),
    ShopItem(id: 'round', name: 'Gol chashma', price: 10, kind: ShopKind.wear, accessory: MascotAccessory.roundGlasses),
    ShopItem(id: 'stars', name: 'Star chashma', price: 15, kind: ShopKind.wear, accessory: MascotAccessory.starGlasses),
    ShopItem(id: 'scarf', name: 'Muffler', price: 12, kind: ShopKind.wear, accessory: MascotAccessory.scarf),
    ShopItem(id: 'cape', name: 'Cape', price: 25, kind: ShopKind.wear, accessory: MascotAccessory.cape),
    ShopItem(id: 'crown', name: 'Taaj', price: 40, kind: ShopKind.wear, accessory: MascotAccessory.crown),
    ShopItem(id: 'phones', name: 'Headphones', price: 18, kind: ShopKind.wear, accessory: MascotAccessory.headphones),
    ShopItem(id: 'bow', name: 'Bow', price: 6, kind: ShopKind.wear, accessory: MascotAccessory.bow),
    ShopItem(id: 'lamp', name: 'Lamp', price: 10, kind: ShopKind.room, icon: 'emoji_objects'),
    ShopItem(id: 'poster', name: 'Poster', price: 14, kind: ShopKind.room, icon: 'image'),
    ShopItem(id: 'plant', name: 'Paudha', price: 8, kind: ShopKind.room, icon: 'potted_plant'),
    ShopItem(id: 'rug', name: 'Qaleen', price: 16, kind: ShopKind.room, icon: 'blur_circular'),
  ];
}
