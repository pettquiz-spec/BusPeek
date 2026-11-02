import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Real road geometry for bus routes.
///
/// Uses the OSRM routing service (OpenStreetMap road data) to turn a list of
/// stop coordinates into the actual road path a bus follows. Results are
/// cached in memory, so each route is only requested once per app run.
///
/// The public demo server (router.project-osrm.org) is fine for testing.
/// For production, host your own OSRM or use a paid routing provider and
/// change [kOsrmBase].
const String kOsrmBase = 'https://router.project-osrm.org';

class RoadRoutes {
  static final Map<String, List<LatLng>> _cache = {};
  static final Map<String, Future<List<LatLng>>> _pending = {};
  static const Distance _dist = Distance();

  /// Road path through [waypoints] (in order). Falls back to straight lines
  /// between the stops if the routing service cannot be reached; the fallback
  /// is not cached, so the next call tries again.
  static Future<List<LatLng>> fetch(String key, List<LatLng> waypoints) {
    final hit = _cache[key];
    if (hit != null) return Future.value(hit);
    return _pending[key] ??=
        _load(key, waypoints).whenComplete(() => _pending.remove(key));
  }

  static bool isCached(String key) => _cache.containsKey(key);

  static Future<List<LatLng>> _load(String key, List<LatLng> pts) async {
    if (pts.length < 2) return pts;
    try {
      final coords = pts.map((p) => '${p.longitude},${p.latitude}').join(';');
      final uri = Uri.parse(
        '$kOsrmBase/route/v1/driving/$coords'
        '?overview=full&geometries=geojson&continue_straight=false',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return pts;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final routes = j['routes'] as List?;
      if (routes == null || routes.isEmpty) return pts;
      final coordsJson =
          (routes.first['geometry']['coordinates'] as List).cast<List>();
      final line = coordsJson
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      if (line.length < 2) return pts;
      _cache[key] = line;
      return line;
    } catch (_) {
      return pts;
    }
  }

  /// Index of the polyline point closest to [p].
  static int nearestIndex(List<LatLng> line, LatLng p) {
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < line.length; i++) {
      final dLat = line[i].latitude - p.latitude;
      final dLng = line[i].longitude - p.longitude;
      final d = dLat * dLat + dLng * dLng;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  /// Kilometres along the road from [from] to [to] (both snapped to the line).
  static double kmAlong(List<LatLng> line, LatLng from, LatLng to) {
    if (line.length < 2) return _dist.as(LengthUnit.Kilometer, from, to);
    var a = nearestIndex(line, from);
    var b = nearestIndex(line, to);
    if (a > b) {
      final t = a;
      a = b;
      b = t;
    }
    var m = 0.0;
    for (var i = a; i < b; i++) {
      m += _dist.as(LengthUnit.Meter, line[i], line[i + 1]);
    }
    return m / 1000;
  }

  /// Total length of the polyline in km.
  static double totalKm(List<LatLng> line) {
    var m = 0.0;
    for (var i = 0; i < line.length - 1; i++) {
      m += _dist.as(LengthUnit.Meter, line[i], line[i + 1]);
    }
    return m / 1000;
  }
}
