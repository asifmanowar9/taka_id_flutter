import 'package:flutter/material.dart';

ImageProvider? localImageProvider(String path) {
  if (path.isEmpty) return null;
  if (path.startsWith('data:image')) {
    return NetworkImage(path);
  }
  return null;
}
