import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LocationResult {
  final String displayName;
  final String name;
  final String city;
  final String state;
  final String country;
  final double? latitude;
  final double? longitude;

  const LocationResult({
    required this.displayName,
    required this.name,
    this.city = '',
    this.state = '',
    this.country = '',
    this.latitude,
    this.longitude,
  });

  /// Short, human-friendly label like "Mumbai, Maharashtra" or "Dallas, Texas"
  String get shortLabel {
    final parts = <String>[];
    final primary = city.isNotEmpty ? city : name;
    if (primary.isNotEmpty) parts.add(primary);

    if (state.isNotEmpty && !primary.toLowerCase().contains(state.toLowerCase())) {
      parts.add(state);
    } else if (country.isNotEmpty && parts.length <= 1) {
      parts.add(country);
    }

    if (parts.isEmpty) return displayName;
    return parts.join(', ');
  }

  factory LocationResult.fromNominatim(Map<String, dynamic> json) {
    final address = (json['address'] as Map<String, dynamic>?) ?? {};
    final name = (json['name'] as String?) ?? '';
    final displayName = (json['display_name'] as String?) ?? name;

    final city = address['city'] ??
        address['town'] ??
        address['village'] ??
        address['suburb'] ??
        address['city_district'] ??
        address['county'] ??
        '';

    final state = address['state'] ?? address['state_district'] ?? '';
    final country = address['country'] ?? '';

    final lat = double.tryParse('${json['lat'] ?? ''}');
    final lon = double.tryParse('${json['lon'] ?? ''}');

    return LocationResult(
      displayName: displayName,
      name: name.isNotEmpty ? name : (city.isNotEmpty ? city : displayName),
      city: '$city',
      state: '$state',
      country: '$country',
      latitude: lat,
      longitude: lon,
    );
  }
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const String _baseUrl = 'https://nominatim.openstreetmap.org/search';

  /// Searches locations, cities, stadiums, and venues by keyword query.
  Future<List<LocationResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    try {
      final uri = Uri.parse(
        '$_baseUrl?format=json&addressdetails=1&limit=6&q=${Uri.encodeComponent(trimmed)}',
      );

      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent': 'AtheleosApp/1.0 (contact@atheleos.com)',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          final results = decoded
              .whereType<Map<String, dynamic>>()
              .map(LocationResult.fromNominatim)
              .toList();

          // If results found, return them
          if (results.isNotEmpty) return results;
        }
      }
    } catch (e) {
      debugPrint('[LocationService] Search failed or timed out: $e');
    }

    // Graceful fallback: return user's custom query so they are never blocked
    return [
      LocationResult(
        displayName: trimmed,
        name: trimmed,
        city: trimmed,
      ),
    ];
  }
}
