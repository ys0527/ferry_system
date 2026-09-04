import 'dart:convert';
import 'package:http/http.dart' as http;

enum SailingStatus { normal, caution, suspended }

class GeneralForecast {
  GeneralForecast({
    required this.locationName,
    required this.summaryForecast,
    required this.minTemp,
    required this.maxTemp,
  });

  final String locationName;
  final String summaryForecast;
  final int minTemp;
  final int maxTemp;

  factory GeneralForecast.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>? ?? {};
    return GeneralForecast(
      locationName: location['location_name'] as String? ?? 'Pulau Pinang',
      summaryForecast: json['summary_forecast'] as String? ?? 'Tiada hujan',
      minTemp: (json['min_temp'] as num?)?.toInt() ?? 0,
      maxTemp: (json['max_temp'] as num?)?.toInt() ?? 0,
    );
  }
}

class WeatherWarning {
  WeatherWarning({
    required this.titleEn,
    required this.textEn,
    required this.instructionEn,
    required this.validTo,
  });

  final String titleEn;
  final String textEn;
  final String instructionEn;
  final DateTime? validTo;

  factory WeatherWarning.fromJson(Map<String, dynamic> json) {
    DateTime? validTo;
    try {
      validTo = DateTime.parse(json['valid_to'] as String);
    } catch (_) {
      validTo = null;
    }
    return WeatherWarning(
      titleEn: json['title_en'] as String? ?? json['heading_en'] as String? ?? 'Weather Warning',
      textEn: json['text_en'] as String? ?? '',
      instructionEn: json['instruction_en'] as String? ?? '',
      validTo: validTo,
    );
  }

  bool get isCurrentlyActive => validTo == null || validTo!.isAfter(DateTime.now());

  bool get isActualHazard {
    final combined = '$titleEn $textEn'.toLowerCase();
    return !combined.contains('no advisory') &&
        !combined.contains('no tropical cyclone') &&
        !combined.contains('not observed');
  }

  static const _relevantAreaKeywords = [
    'pulau pinang', 'penang', 'selat melaka', 'straits of malacca',
    'kedah', 'perlis', 'perak', 'peninsular malaysia',
  ];

  bool get isRelevantToPenangStrait {
    final combined = '$titleEn $textEn'.toLowerCase();
    return _relevantAreaKeywords.any(combined.contains);
  }
}

class MarineConditions {
  MarineConditions({
    required this.waveHeightM,
    required this.windSpeedKmh,
  });

  final double waveHeightM;
  final double windSpeedKmh;
}

class SailingConditions {
  SailingConditions({
    required this.forecast,
    required this.warnings,
    required this.marine,
    required this.status,
  });

  final GeneralForecast forecast;
  final List<WeatherWarning> warnings;
  final MarineConditions marine;
  final SailingStatus status;
}

class WeatherService {
  static const double _lat = 5.41;
  static const double _lon = 100.34;

  Future<GeneralForecast> fetchGeneralForecast() async {
    final uri = Uri.parse(
      'https://api.data.gov.my/weather/forecast'
          '?contains=St@location__location_id'
          '&limit=20',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Failed to load forecast (${response.statusCode})');
    }
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;

    final penangEntry = data.cast<Map<String, dynamic>>().firstWhere(
          (item) {
        final location = item['location'] as Map<String, dynamic>? ?? {};
        final name = (location['location_name'] as String?)?.toLowerCase() ?? '';
        return name.contains('pulau pinang') || name.contains('penang');
      },
      orElse: () => throw Exception('No forecast data found for Pulau Pinang'),
    );

    return GeneralForecast.fromJson(penangEntry);
  }

  Future<List<WeatherWarning>> fetchActiveWarnings() async {
    final uri = Uri.parse('https://api.data.gov.my/weather/warning?limit=20');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Failed to load warnings (${response.statusCode})');
    }
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => WeatherWarning.fromJson(e as Map<String, dynamic>))
        .where((w) => w.isCurrentlyActive && w.isActualHazard && w.isRelevantToPenangStrait)
        .toList();
  }

  Future<MarineConditions> fetchMarineConditions() async {
    final marineUri = Uri.parse(
      'https://marine-api.open-meteo.com/v1/marine'
          '?latitude=$_lat&longitude=$_lon'
          '&current=wave_height',
    );
    final windUri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
          '?latitude=$_lat&longitude=$_lon'
          '&current=wind_speed_10m',
    );

    final responses = await Future.wait([
      http.get(marineUri).timeout(const Duration(seconds: 10)),
      http.get(windUri).timeout(const Duration(seconds: 10)),
    ]);

    final marineResponse = responses[0];
    final windResponse = responses[1];

    if (marineResponse.statusCode != 200) {
      throw Exception('Failed to load marine data (${marineResponse.statusCode})');
    }
    if (windResponse.statusCode != 200) {
      throw Exception('Failed to load wind data (${windResponse.statusCode})');
    }

    final marineJson = jsonDecode(marineResponse.body) as Map<String, dynamic>;
    final windJson = jsonDecode(windResponse.body) as Map<String, dynamic>;

    final waveHeight = (marineJson['current']?['wave_height'] as num?)?.toDouble() ?? 0.0;
    final windSpeed = (windJson['current']?['wind_speed_10m'] as num?)?.toDouble() ?? 0.0;

    return MarineConditions(waveHeightM: waveHeight, windSpeedKmh: windSpeed);
  }

  SailingStatus deriveStatus(MarineConditions marine, List<WeatherWarning> warnings) {
    final hasSevereWarning = warnings.isNotEmpty;
    if (hasSevereWarning || marine.waveHeightM >= 1.5) {
      return SailingStatus.suspended;
    }
    if (marine.waveHeightM >= 0.8 || marine.windSpeedKmh >= 30) {
      return SailingStatus.caution;
    }
    return SailingStatus.normal;
  }

  Future<SailingConditions> fetchSailingConditions() async {
    final results = await Future.wait([
      fetchGeneralForecast(),
      fetchActiveWarnings(),
      fetchMarineConditions(),
    ]);

    final forecast = results[0] as GeneralForecast;
    final warnings = results[1] as List<WeatherWarning>;
    final marine = results[2] as MarineConditions;
    final status = deriveStatus(marine, warnings);

    return SailingConditions(
      forecast: forecast,
      warnings: warnings,
      marine: marine,
      status: status,
    );
  }
}