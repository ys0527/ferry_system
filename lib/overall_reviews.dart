import 'package:flutter/material.dart';
import 'supabase_config.dart';

class _ReviewEntry {
  _ReviewEntry({
    required this.id,
    required this.route,
    required this.rating,
    required this.comment,
    required this.reviewerName,
    required this.createdAt,
    required this.photoUrls,
  });

  final String id;
  final String route;
  final int rating;
  final String? comment;
  final String reviewerName;
  final DateTime createdAt;
  final List<String> photoUrls;
}

class OverallReviewsPage extends StatefulWidget {
  const OverallReviewsPage({super.key});

  @override
  State<OverallReviewsPage> createState() => _OverallReviewsState();
}

class _OverallReviewsState extends State<OverallReviewsPage> {
  static const navy = Color(0xFF3472CA);
  static const teal = Color(0xFF1E93B8);
  static const ice = Color(0xFFEAF4F8);
  static const gold = Color(0xFFE8B45A);

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  bool _isLoading = true;
  String? _error;
  List<_ReviewEntry> _reviews = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await supabase
          .from('review')
          .select('*, booking!inner(schedule!inner(departure, destination))')
          .order('created_at', ascending: false);

      final rows = (response as List).cast<Map<String, dynamic>>();

      if (rows.isEmpty) {
        if (!mounted) return;
        setState(() {
          _reviews = [];
          _isLoading = false;
        });
        return;
      }

      final userIds = rows.map((r) => r['user_id'].toString()).toSet().toList();
      final reviewIds = rows.map((r) => r['review_id'].toString()).toList();

      final results = await Future.wait([
        supabase.rpc('get_display_names', params: {'uids': userIds}),
        supabase.from('review_photo').select('review_id, file_name').inFilter('review_id', reviewIds),
      ]);

      final usersData = results[0] as List;
      final photosData = results[1] as List;

      final nameByUserId = {
        for (final u in usersData) u['user_id'].toString(): u['name'] as String? ?? 'Rider',
      };

      final photosByReviewId = <String, List<String>>{};
      for (final p in photosData) {
        final reviewId = p['review_id'].toString();
        final url = supabase.storage.from('review-photos').getPublicUrl(p['file_name'] as String);
        photosByReviewId.putIfAbsent(reviewId, () => []).add(url);
      }

      final entries = rows.map((row) {
        final reviewId = row['review_id'].toString();
        final booking = row['booking'] as Map<String, dynamic>? ?? {};
        final schedule = booking['schedule'] as Map<String, dynamic>? ?? {};
        final departure = schedule['departure'] as String? ?? '?';
        final destination = schedule['destination'] as String? ?? '?';
        return _ReviewEntry(
          id: reviewId,
          route: '$departure → $destination',
          rating: row['rating'] as int,
          comment: row['comment'] as String?,
          reviewerName: nameByUserId[row['user_id'].toString()] ?? 'Rider',
          createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
          photoUrls: photosByReviewId[reviewId] ?? const [],
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _reviews = entries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load reviews: $e';
        _isLoading = false;
      });
    }
  }

  double get _averageRating => _reviews.isEmpty
      ? 0
      : _reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length;

  Map<int, int> get _distribution {
    final counts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in _reviews) {
      counts[r.rating] = (counts[r.rating] ?? 0) + 1;
    }
    return counts;
  }

  String _formatDate(DateTime dt) {
    return '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navy,
        title: const Text('All Reviews'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildError()
            : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 20),
            if (_reviews.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No reviews yet.', style: TextStyle(color: Colors.black45)),
                ),
              )
            else
              ..._reviews.map(_buildReviewTile),
          ],
        ),
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
        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
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

  Widget _buildSummaryCard() {
    final dist = _distribution;
    final total = _reviews.length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [navy, teal]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_averageRating.toStringAsFixed(1),
                  style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
              Row(
                children: List.generate(5, (i) {
                  final filled = i < _averageRating.round();
                  return Icon(filled ? Icons.star : Icons.star_border, color: gold, size: 16);
                }),
              ),
              const SizedBox(height: 4),
              Text('$total review${total == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [5, 4, 3, 2, 1].map((star) {
                final count = dist[star] ?? 0;
                final fraction = total == 0 ? 0.0 : count / total;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text('$star', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 6,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation(gold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('$count', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewTile(_ReviewEntry review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ice, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.reviewerName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: navy)),
                    Text(review.route, style: const TextStyle(fontSize: 10.5, color: Colors.black45)),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                      (i) => Icon(i < review.rating ? Icons.star : Icons.star_border, color: gold, size: 14),
                ),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(review.comment!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
          if (review.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.photoUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    review.photoUrls[index],
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.broken_image, size: 18, color: Colors.black38),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(_formatDate(review.createdAt),
              style: const TextStyle(fontSize: 10, color: Colors.black38, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}