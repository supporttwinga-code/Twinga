import 'dart:convert';
import 'dart:typed_data';

/// Firestore mein photo base64 text ke roop mein hoti hai.
/// Yeh usse image bytes mein badalta hai. Galat ya khali ho to null.
Uint8List? decodePhoto(dynamic value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  try {
    return base64Decode(value);
  } catch (_) {
    return null;
  }
}
