import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ReviewsRatingsPage extends StatefulWidget {
  const ReviewsRatingsPage({this.tripLabel, super.key});

  final String? tripLabel;

  @override
  State<ReviewsRatingsPage> createState() => _ReviewsRatingsState();
}

class _ReviewsRatingsState extends State<ReviewsRatingsPage> {
  static const navy = Color(0xFF3472CA);
  static const teal = Color(0xFF1E93B8);
  static const ice = Color(0xFFEAF4F8);
  static const gold = Color(0xFFE8B45A);

  int selectedStars = 0;
  final _commentController = TextEditingController();
  bool _submitted = false;
  final List<XFile> _attachedPhotos = [];
  final ImagePicker _picker = ImagePicker();

  final List<Map<String, dynamic>> pastReviews = const [
    {'name': 'Aiman', 'stars': 5, 'comment': 'Smooth ride, right on time.', 'date': '20 Jul 2026, 08:30'},
    {'name': 'Ravi', 'stars': 4, 'comment': 'Good service, boarding was a bit slow.', 'date': '18 Jul 2026, 17:45'},
    {'name': 'Mei Ling', 'stars': 5, 'comment': 'Loved the QR ticket, very convenient.', 'date': '15 Jul 2026, 09:10'},
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitReview() {
    if (selectedStars == 0) return;
    setState(() => _submitted = true);
  }

  Future<void> _addPhoto() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _attachedPhotos.add(picked));
    }
  }

  void _removePhoto(int index) {
    setState(() => _attachedPhotos.removeAt(index));
  }

  Widget _buildPhotoRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._attachedPhotos.asMap().entries.map((entry) {
          final index = entry.key;
          final photo = entry.value;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(photo.path),
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () => _removePhoto(index),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          );
        }),
        GestureDetector(
          onTap: _addPhoto,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: teal, width: 1.2),
            ),
            child: const Icon(Icons.add_a_photo_outlined, color: teal, size: 22),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navy,
        title: const Text('Reviews & Ratings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: ice, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.tripLabel != null ? 'Rate your trip: ${widget.tripLabel}' : 'Rate your trip',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: navy),
                ),
                const SizedBox(height: 12),
                if (_submitted)
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: teal, size: 20),
                      SizedBox(width: 8),
                      Text('Thanks for your feedback!', style: TextStyle(color: navy, fontSize: 13)),
                    ],
                  )
                else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final filled = i < selectedStars;
                      return IconButton(
                        onPressed: () => setState(() => selectedStars = i + 1),
                        icon: Icon(
                          filled ? Icons.star : Icons.star_border,
                          color: gold,
                          size: 32,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Tell us about your trip (optional)',
                      hintStyle: const TextStyle(fontSize: 12.5, color: Colors.black38),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPhotoRow(),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedStars == 0 ? null : _submitReview,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: teal,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('Submit Review',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('What other riders say',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: navy)),
          const SizedBox(height: 12),
          ...pastReviews.map(_buildReviewTile),
        ],
      ),
    );
  }

  Widget _buildReviewTile(Map<String, dynamic> review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ice, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(review['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: navy)),
              const Spacer(),
              Row(
                children: List.generate(
                  5,
                      (i) => Icon(
                    i < (review['stars'] as int) ? Icons.star : Icons.star_border,
                    color: gold,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(review['comment'] as String, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(review['date'] as String,
              style: const TextStyle(fontSize: 10, color: Colors.black38, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
