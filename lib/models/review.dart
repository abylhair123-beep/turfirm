class TourReview {
  const TourReview({
    required this.id,
    required this.tourId,
    required this.authorName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String tourId;
  final String authorName;
  final double rating;
  final String comment;
  final DateTime createdAt;

  factory TourReview.fromJson(Map<String, dynamic> json) {
    return TourReview(
      id: json['id'] as String? ?? '',
      tourId: json['tourId'] as String? ?? json['tour_id'] as String? ?? '',
      authorName: json['authorName'] as String? ?? json['author_name'] as String? ?? 'Путешественник',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      comment: json['comment'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tourId': tourId,
      'authorName': authorName,
      'rating': rating,
      'comment': comment,
    };
  }
}
