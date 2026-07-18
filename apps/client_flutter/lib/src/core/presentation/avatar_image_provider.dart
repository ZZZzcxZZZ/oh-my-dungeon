import 'dart:convert';

import 'package:flutter/material.dart';

ImageProvider<Object>? avatarImageProvider(String? source) {
  final value = source?.trim();
  if (value == null || value.isEmpty) return null;

  if (value.startsWith('data:image/')) {
    final separator = value.indexOf(',');
    if (separator < 0) return null;
    try {
      return MemoryImage(base64Decode(value.substring(separator + 1)));
    } on FormatException {
      return null;
    }
  }

  return NetworkImage(value);
}
