import 'package:flutter/material.dart';
import 'models/forecast.dart';
import 'services/notification_service.dart';


class WeatherSailingPage extends StatefulWidget {
  const WeatherSailingPage({super.key});

  @override
  State<WeatherSailingPage> createState() => _WeatherSailingPageState();
}

class _WeatherSailingPageState extends State<WeatherSailingPage> {
  static const navy = Color(0xFF3472CA);
  static const teal = Color(0xFF1E93B8);
  static const deepBlue = Color(0xFF2458A8);
  static const ice = Color(0xFFEAF4F8);
  static const green = Color(0xFF3CAE6A);
  static const amber = Color(0xFFE3A72E);
  static const red = Color(0xFFE0483C);

  final WeatherService _service = WeatherService();

  bool isLoading = true;
  String? errorMessage;
  SailingConditions? conditions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final result = await _service.fetchSailingConditions();
      setState(() {
        conditions = result;
        isLoading = false;
      });
      if (result.status != SailingStatus.normal) {
        _sendAdvisoryNotification(result);
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Could not load live weather data. Pull down to retry.';
        isLoading = false;
      });
    }
  }

  Future<void> _sendAdvisoryNotification(SailingConditions c) async {
    try {
      final title = _statusLabel(c.status);
      final body = c.warnings.isNotEmpty
          ? c.warnings.first.titleEn
          : 'Wave height ${c.marine.waveHeightM.toStringAsFixed(1)}m, wind ${c.marine.windSpeedKmh.toStringAsFixed(0)}km/h on the Georgetown–Butterworth crossing.';
      await NotificationService().notifyWeatherAdvisoryIfNew(title: title, body: body);
    } catch (_) {

    }
  }

  Color _statusColor(SailingStatus status) {
    switch (status) {
      case SailingStatus.normal:
        return green;
      case SailingStatus.caution:
        return amber;
      case SailingStatus.suspended:
        return red;
    }
  }

  String _statusLabel(SailingStatus status) {
    switch (status) {
      case SailingStatus.normal:
        return 'Normal Sailing';
      case SailingStatus.caution:
        return 'Caution';
      case SailingStatus.suspended:
        return 'Sailing Suspended';
    }
  }

  IconData _statusIcon(SailingStatus status) {
    switch (status) {
      case SailingStatus.normal:
        return Icons.check_circle;
      case SailingStatus.caution:
        return Icons.warning_amber_rounded;
      case SailingStatus.suspended:
        return Icons.dangerous;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navy,
        title: const Text('Weather & Sailing Conditions'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? _buildError()
            : _buildContent(conditions!),
      ),
    );
  }

  Widget _buildError() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.cloud_off, size: 48, color: Colors.black38),
        const SizedBox(height: 16),
        Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(backgroundColor: teal),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(SailingConditions c) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatusCard(c),
        const SizedBox(height: 16),
        _buildForecastCard(c.forecast),
        const SizedBox(height: 16),
        _buildMarineCard(c.marine),
        if (c.warnings.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Active Warnings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: navy)),
          const SizedBox(height: 8),
          ...c.warnings.map(_buildWarningTile),
        ],
        const SizedBox(height: 16),
        const Text(
          'General forecast from MET Malaysia (data.gov.my). Wave height and wind '
              'speed from Open-Meteo, since MET Malaysia\'s open API does not currently '
              'publish marine data.',
          style: TextStyle(fontSize: 10.5, color: Colors.black38, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildStatusCard(SailingConditions c) {
    final color = _statusColor(c.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [deepBlue, teal]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_statusIcon(c.status), color: color, size: 30),
              const SizedBox(width: 10),
              Text(
                _statusLabel(c.status),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Georgetown \u2194 Butterworth crossing',
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastCard(GeneralForecast f) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ice, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.cloud, color: navy, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.locationName, style: const TextStyle(fontWeight: FontWeight.bold, color: navy, fontSize: 13)),
                const SizedBox(height: 2),
                Text(f.summaryForecast, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
          Text('${f.minTemp}\u2013${f.maxTemp}\u00b0C',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: navy)),
        ],
      ),
    );
  }

  Widget _buildMarineCard(MarineConditions m) {
    return Row(
      children: [
        Expanded(child: _buildMetricTile(Icons.waves, 'Wave Height', '${m.waveHeightM.toStringAsFixed(1)} m')),
        const SizedBox(width: 12),
        Expanded(child: _buildMetricTile(Icons.air, 'Wind Speed', '${m.windSpeedKmh.toStringAsFixed(0)} km/h')),
      ],
    );
  }

  Widget _buildMetricTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ice, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: teal, size: 22),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: navy)),
          Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildWarningTile(WeatherWarning w) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: red, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(w.titleEn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: red)),
              ),
            ],
          ),
          if (w.textEn.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(w.textEn, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ],
          if (w.instructionEn.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(w.instructionEn,
                style: const TextStyle(fontSize: 11, color: Colors.black54, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}
