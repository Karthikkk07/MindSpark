import 'quote_category.dart';

/// A single motivational quote, with where it came from and its license.
class Quote {
  const Quote({
    required this.id,
    required this.text,
    required this.author,
    required this.category,
    required this.tags,
    required this.source,
    required this.license,
  });

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      id: json['id'] as String,
      text: json['text'] as String,
      author: json['author'] as String,
      category: json['category'] as String,
      tags: ((json['tags'] as List<dynamic>?) ?? const [])
          .map((tag) => tag as String)
          .toList(growable: false),
      source: (json['source'] as String?) ?? '',
      license: (json['license'] as String?) ?? '',
    );
  }

  final String id;
  final String text;
  final String author;
  final String category;
  final List<String> tags;
  final String source;
  final String license;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'author': author,
        'category': category,
        'tags': tags,
        'source': source,
        'license': license,
      };

  String get categoryLabel => QuoteCategory.fromId(category)?.label ?? category;
}
