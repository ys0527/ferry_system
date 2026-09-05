import 'dart:io';
import 'package:ferry_system/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'review_window.dart';
import 'services/current_user_service.dart';
import 'overall_reviews.dart';

class Review {
  final String id;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String userId;
  final String bookingId;
  final String? reviewerName;
  final List<String> photoUrls;

  Review({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.userId,
    required this.bookingId,
    this.reviewerName,
    this.photoUrls = const [],
  });

  Review copyWith({String? reviewerName, List<String>? photoUrls}) {
    return Review(
      id: id,
      rating: rating,
      comment: comment,
      createdAt: createdAt,
      userId: userId,
      bookingId: bookingId,
      reviewerName: reviewerName ?? this.reviewerName,
      photoUrls: photoUrls ?? this.photoUrls,
    );
  }

  //row record in database -> Json -> class object
  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['review_id'].toString(),
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      userId: json['user_id'].toString(),
      bookingId: json['booking_id'].toString(),
    );
  }
}

class ReviewsRatingsPage extends StatefulWidget {
  const ReviewsRatingsPage({
    required this.bookingId,
    this.tripLabel,
    this.tripEndTime,
    super.key,
  });


  final String bookingId;
  final String? tripLabel;
  final DateTime? tripEndTime;

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
  bool _isSubmitting = false;
  final List<XFile> _attachedPhotos = [];
  final ImagePicker _picker = ImagePicker();

  List<Review> _reviews = [];
  bool _isLoading = true;
  bool _alreadyReviewed = false;
  bool _isDeleting = false;

  // Set when the user taps "Edit" on their own existing review -- the form
  // stays the same widget, just pre-filled and routed to _updateReview()
  // instead of _addReview() on submit.
  bool _isEditing = false;
  String? _editingReviewId;

  // The app's own U-code user id (e.g. "U0001"), resolved from the auth
  // UID via services/current_user_service.dart. This is what's actually
  // stored in review.user_id -- NOT the raw Supabase Auth UUID.
  String? _currentUserId;

  // The signed-in user's own review for THIS booking specifically -- not
  // just any review they've left on the route, since Edit/Delete apply to
  // one trip at a time.
  Review? get _myReview {
    if (_currentUserId == null) return null;
    for (final r in _reviews) {
      if (r.userId == _currentUserId && r.bookingId == widget.bookingId) return r;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  ReviewWindowStatus get _windowStatus =>
      widget.tripEndTime == null ? ReviewWindowStatus.open : ReviewWindow(widget.tripEndTime!).status;

  Future<void> _fetchReviews() async {
    setState(() => _isLoading = true);

    try {
      // Fix: was `.eq('booking_id', widget.bookingId)` -- but only the
      // booking's owner can ever attach a review to their own booking_id
      // (per the insert RLS policy), so that filter could only ever
      // return the current user's own review, never anyone else's.
      // "What other riders say" needs every review across every booking
      // on the same route. There's no `route` column on `booking` --
      // it's a Dart-side string built from schedule.departure +
      // schedule.destination -- so this splits tripLabel back apart and
      // joins two hops through `schedule` to filter on the real columns.
      final routeParts = widget.tripLabel?.split(' → ');
      final departure = (routeParts != null && routeParts.length == 2) ? routeParts[0] : null;
      final destination = (routeParts != null && routeParts.length == 2) ? routeParts[1] : null;

      final response = (departure != null && destination != null)
          ? await supabase
          .from('review')
          .select('*, booking!inner(schedule!inner(departure, destination))')
          .eq('booking.schedule.departure', departure)
          .eq('booking.schedule.destination', destination)
          .order('created_at', ascending: false)
          : await supabase
          .from('review')
          .select()
          .eq('booking_id', widget.bookingId)
          .order('created_at', ascending: false);

      final rawReviews = (response as List).map((item) => Review.fromJson(item)).toList();
      // Fix: was `supabase.auth.currentUser?.id`, the raw Supabase Auth
      // UUID -- but review.user_id stores the app's own "U0001"-style
      // code from the `users` table, not the auth UID directly.
      final myUserId = await currentUserId();

      if (rawReviews.isEmpty) {
        if (!mounted) return;
        setState(() {
          _reviews = [];
          _alreadyReviewed = false;
          _currentUserId = myUserId;
        });
        return;
      }

      final userIds = rawReviews.map((r) => r.userId).toSet().toList();
      final reviewIds = rawReviews.map((r) => r.id).toList();

      final results = await Future.wait([
        // Uses a security-definer RPC instead of querying `users`
        // directly -- `users` RLS only allows reading your own row, and
        // widening that to all rows would also expose email/phone_num to
        // every signed-in user just to show a display name. This
        // function returns only user_id + name, nothing else.
        supabase.rpc('get_display_names', params: {'uids': userIds}),
        supabase.from('review_photo').select('review_id, file_name').inFilter('review_id', reviewIds),
      ]);

      final usersData = results[0] as List;
      final photosData = results[1] as List;

      final nameByUserId = {
        for (final u in usersData) u['user_id'].toString(): u['name'] as String?,
      };

      final photosByReviewId = <String, List<String>>{};
      for (final p in photosData) {
        final reviewId = p['review_id'].toString();
        final url = supabase.storage.from('review-photos').getPublicUrl(p['file_name'] as String);
        photosByReviewId.putIfAbsent(reviewId, () => []).add(url);
      }

      final reviews = rawReviews
          .map((r) => r.copyWith(
        reviewerName: nameByUserId[r.userId],
        photoUrls: photosByReviewId[r.id] ?? const [],
      )).toList();

      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _currentUserId = myUserId;
        // Fix: was checking any review by this user across the whole
        // route -- must stay scoped to THIS booking, since one user can
        // legitimately review multiple separate trips on the same route.
        _alreadyReviewed = reviews.any((r) => r.userId == myUserId && r.bookingId == widget.bookingId);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch reviews: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addReview() async {
    // Fix: was `supabase.auth.currentUser?.id` (the 36-character auth
    // UUID) inserted directly into a `varchar(5)` column that expects
    // "U0001"-style codes -- caused a Postgres "value too long" error.
    String myUserId;
    try {
      myUserId = _currentUserId ?? await currentUserId();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to leave a review.')),
      );
      return;
    }

    final comment = _commentController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      final response = await supabase.from('review').insert({
        'rating': selectedStars,
        'comment': comment.isEmpty ? null : comment,
        'user_id': myUserId,
        'booking_id': widget.bookingId,
      }).select();

      final newReview = Review.fromJson((response as List).first);

      if (_attachedPhotos.isNotEmpty) {
        await _uploadPhotos(newReview.id);
      }

      if (!mounted) return;
      setState(() {
        _reviews.insert(0, newReview);
        _submitted = true;
        _alreadyReviewed = true;
      });
      _fetchReviews();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add review: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _uploadPhotos(String reviewId) async {
    for (final photo in _attachedPhotos) {
      try {
        final bytes = await photo.readAsBytes();
        final extension = photo.path.contains('.') ? photo.path.split('.').last : 'jpg';
        final fileName = '$reviewId-${DateTime.now().millisecondsSinceEpoch}.$extension';

        await supabase.storage.from('review-photos').uploadBinary(fileName, bytes);

        await supabase.from('review_photo').insert({
          'review_id': reviewId,
          'file_name': fileName,
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('A photo failed to upload: $e')),
          );
        }
      }
    }
  }

  void _startEditing() {
    final review = _myReview;
    if (review == null) return;
    setState(() {
      _isEditing = true;
      _editingReviewId = review.id;
      selectedStars = review.rating;
      _commentController.text = review.comment ?? '';
      _submitted = false;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _editingReviewId = null;
      _commentController.clear();
      _attachedPhotos.clear();
      selectedStars = 0;
    });
  }

  Future<void> _updateReview() async {
    final reviewId = _editingReviewId;
    if (reviewId == null) return;

    final comment = _commentController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      final response = await supabase
          .from('review')
          .update({
        'rating': selectedStars,
        'comment': comment.isEmpty ? null : comment,
      })
          .eq('review_id', reviewId)
          .select();

      final updated = Review.fromJson((response as List).first);

      // Newly attached photos during an edit are additive -- this doesn't
      // remove any photos already uploaded from a previous submission.
      if (_attachedPhotos.isNotEmpty) {
        await _uploadPhotos(reviewId);
      }

      if (!mounted) return;
      setState(() {
        final index = _reviews.indexWhere((r) => r.id == updated.id);
        if (index != -1) {
          // The update response doesn't include reviewerName/photoUrls
          // (those come from the join in _fetchReviews), so carry them
          // over from what's already in state.
          _reviews[index] = updated.copyWith(
            reviewerName: _reviews[index].reviewerName,
            photoUrls: _reviews[index].photoUrls,
          );
        }
        _isEditing = false;
        _editingReviewId = null;
        _attachedPhotos.clear();
      });
      _fetchReviews();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review updated.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update review: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmDelete(String reviewId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete review?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _deleteReview(reviewId);
    }
  }

  Future<void> _deleteReview(String reviewId) async {
    setState(() => _isDeleting = true);
    try {
      // Fetch the file names BEFORE deleting the review -- the
      // review_photo rows cascade-delete along with it (on delete cascade
      // in the schema), so this list would be gone if queried after.
      final photoRows = await supabase
          .from('review_photo')
          .select('file_name')
          .eq('review_id', reviewId);

      final fileNames = (photoRows as List)
          .map((row) => row['file_name'] as String)
          .toList();

      await supabase.from('review').delete().eq('review_id', reviewId);

      // Remove the actual files from Storage now that nothing references
      // them. Best-effort: if this fails, the DB rows are already gone,
      // so surface it but don't treat the whole delete as failed.
      if (fileNames.isNotEmpty) {
        try {
          await supabase.storage.from('review-photos').remove(fileNames);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Review deleted, but some photos could not be removed from storage: $e')),
            );
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _reviews.removeWhere((r) => r.id == reviewId);
        _alreadyReviewed = false;
        _submitted = false;
        _isEditing = false;
        _editingReviewId = null;
        selectedStars = 0;
        _commentController.clear();
        _attachedPhotos.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete review: $e')),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _submitReview() {
    if (selectedStars == 0 || _isSubmitting) return;
    if (_isEditing) {
      _updateReview();
    } else {
      _addReview();
    }
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

  Widget _buildGatedNotice(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ice, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.tripLabel != null ? 'Rate your trip: ${widget.tripLabel}' : 'Rate your trip',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: navy),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(icon, color: Colors.black38, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: const TextStyle(fontSize: 12.5, color: Colors.black54))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyReviewCard(Review review) {
    return Container(
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
          const Row(
            children: [
              Icon(Icons.check_circle, color: teal, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('You already reviewed this trip.', style: TextStyle(color: navy, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(
              5,
                  (i) => Icon(i < review.rating ? Icons.star : Icons.star_border, color: gold, size: 22),
            ),
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment!, style: const TextStyle(fontSize: 12.5, color: Colors.black87)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isDeleting ? null : _startEditing,
                  icon: const Icon(Icons.edit, size: 16, color: teal),
                  label: const Text('Edit', style: TextStyle(color: teal)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: teal)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isDeleting ? null : () => _confirmDelete(review.id),
                  icon: _isDeleting
                      ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2),
                  )
                      : const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                  label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _windowStatus;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navy,
        title: const Text('Reviews & Ratings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'All reviews',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OverallReviewsPage()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (status == ReviewWindowStatus.notYetOpen)
            _buildGatedNotice(
              'Reviews open 1 minute after your trip ends. Please check back shortly.',
              Icons.hourglass_empty,
            )
          else if (status == ReviewWindowStatus.expired)
            _buildGatedNotice(
              'The 24-hour review window for this trip has closed.',
              Icons.lock_clock,
            )
          else if (_myReview != null && !_isEditing)
              _buildMyReviewCard(_myReview!)
            else
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
                      Row(
                        children: [
                          if (_isEditing) ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSubmitting ? null : _cancelEditing,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  side: const BorderSide(color: teal),
                                ),
                                child: const Text('Cancel', style: TextStyle(color: teal)),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: (selectedStars == 0 || _isSubmitting) ? null : _submitReview,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: teal,
                                disabledBackgroundColor: Colors.grey.shade300,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                                  : Text(_isEditing ? 'Update Review' : 'Submit Review',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
          const SizedBox(height: 24),
          const Text('What other riders say',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: navy)),
          const SizedBox(height: 12),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No reviews yet for this trip.', style: TextStyle(fontSize: 12, color: Colors.black45)),
            )
          else
            ..._reviews.map(_buildReviewTile),
        ],
      ),
    );
  }

  Widget _buildReviewTile(Review review) {
    final isOwnReview = review.userId == _currentUserId;
    final displayName = isOwnReview ? 'You' : (review.reviewerName ?? 'Verified Rider');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ice, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: navy)),
              const Spacer(),
              Row(
                children: List.generate(
                  5,
                      (i) => Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    color: gold,
                    size: 14,
                  ),
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
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.photoUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    review.photoUrls[index],
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const SizedBox(width: 64, height: 64),
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 64,
                      height: 64,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.broken_image, size: 20, color: Colors.black38),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
            style: const TextStyle(fontSize: 10, color: Colors.black38, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}