import 'package:flutter/foundation.dart';

class News {
  final String id;
  final String title;
  final String description;
  final String content;
  final String source;
  final String imageUrl;
  final String url;
  final String publishedAt;
  final String category;
  

  News({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.source,
    required this.imageUrl,
    required this.url,
    required this.publishedAt,
    required this.category, 
    required String urlToImage,
  });

  factory News.fromJson(Map<String, dynamic> json) {
    return News(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      content: json['content'] ?? '',
      source: json['source'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      url: json['url'] ?? '',
      publishedAt: json['publishedAt'] ?? '',
      category: json['category'] ?? '', 
      urlToImage: '',
    );
  }

  String? get urlToImage => null;
}