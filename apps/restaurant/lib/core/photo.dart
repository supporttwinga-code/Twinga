import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'theme.dart';

/// Firestore ka base64 text -> image bytes. Khali ya galat ho to null.
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

/// Gallery kholta hai, photo chhoti karta hai, aur base64 text deta hai.
/// Cancel karne par null. Photo bahut badi ho to FormatException.
Future<String?> pickPhotoBase64({
  required double maxSide,
  int quality = 60,
  int maxBytes = 200 * 1024,
}) async {
  final XFile? file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: maxSide,
    maxHeight: maxSide,
    imageQuality: quality,
  );
  if (file == null) {
    return null;
  }
  final Uint8List bytes = await file.readAsBytes();
  if (bytes.length > maxBytes) {
    throw const FormatException(
      'This photo is too big. Please choose a smaller photo (a JPG works best).',
    );
  }
  return base64Encode(bytes);
}

/// Photo chunne ka sundar box: preview + Choose / Change / Remove.
class PhotoField extends StatefulWidget {
  const PhotoField({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.circle = false,
    this.height = 170,
    this.maxSide = 900,
    this.quality = 60,
  });

  final String label;
  final String hint;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool circle;
  final double height;
  final double maxSide;
  final int quality;

  @override
  State<PhotoField> createState() => _PhotoFieldState();
}

class _PhotoFieldState extends State<PhotoField> {
  bool _busy = false;

  Future<void> _pick() async {
    setState(() {
      _busy = true;
    });
    try {
      final String? b64 = await pickPhotoBase64(
        maxSide: widget.maxSide,
        quality: widget.quality,
      );
      if (b64 != null) {
        widget.onChanged(b64);
      }
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the gallery.')),
        );
      }
    }
    if (mounted) {
      setState(() {
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes = decodePhoto(widget.value);
    final Widget empty = Container(
      color: const Color(0xFFEAF2FE),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: widget.circle ? 30 : 38,
            color: TwingaColors.blue,
          ),
          if (!widget.circle) ...[
            const SizedBox(height: 6),
            Text(
              widget.hint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: TwingaColors.blue,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
    final Widget content = bytes != null
        ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
        : empty;
    final bool has = bytes != null;
    final Widget frame = widget.circle
        ? SizedBox(
            width: widget.height,
            height: widget.height,
            child: ClipOval(child: content),
          )
        : SizedBox(
            height: widget.height,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: content,
            ),
          );
    return Column(
      crossAxisAlignment: widget.circle
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            widget.label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: TwingaColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(onTap: _busy ? null : _pick, child: frame),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: widget.circle
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _pick,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(has ? 'Change photo' : 'Choose from gallery'),
            ),
            if (has) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: _busy ? null : () => widget.onChanged(null),
                child: const Text('Remove'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
