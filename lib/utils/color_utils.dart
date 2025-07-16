import 'package:flutter/material.dart';

Color getMarkerColor(int userId) {
  switch (userId) {
    case 1:
      return Colors.red;
    case 2:
      return Colors.green;
    case 3:
      return Colors.blue;
    default:
      return Colors.grey;
  }
}