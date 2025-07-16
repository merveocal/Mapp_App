import 'package:latlong2/latlong.dart';

bool isSamePosition(LatLng a, LatLng b) =>
    a.latitude.toStringAsFixed(6) == b.latitude.toStringAsFixed(6) &&
    a.longitude.toStringAsFixed(6) == b.longitude.toStringAsFixed(6);

bool latLngEquals(LatLng a, LatLng b) =>
    a.latitude == b.latitude && a.longitude == b.longitude;