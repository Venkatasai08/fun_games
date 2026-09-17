// lib/draftclash/models/draft_franchise.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'franchise_category.dart';

class DraftFranchise {
  final String id;
  final String name;
  final String imageUrl;
  final int cardCount;
  final FranchiseCategory category;

  const DraftFranchise({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.cardCount,
    this.category = FranchiseCategory.other,
  });

  factory DraftFranchise.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return DraftFranchise(
      id:        doc.id,
      name:      d['name']      as String? ?? '',
      imageUrl:  d['imageUrl']  as String? ?? '',
      cardCount: (d['cardCount'] as num?)?.toInt() ?? 0,
      category:  FranchiseCategory.fromString(d['category'] as String?),
    );
  }

  Map<String, dynamic> toMap() => {
    'name':      name,
    'imageUrl':  imageUrl,
    'cardCount': cardCount,
    'category':  category.name,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
