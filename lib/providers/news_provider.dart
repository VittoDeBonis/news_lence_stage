import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:news_lens/models/news_class.dart';

class NewsProvider {
  static const String _baseUrl = 'https://newsapi.org/v2/everything';
  static const String _apiKey = '91748df2eb004e578428388763d45aa8'; 

  final Map<String, String> _categoryQueries = {
    'Politics': 'politics world government election',
    'Sports': 'sports football soccer tennis basketball',
    'Science': 'science research technology discovery',
    'Technology': 'technology innovation tech startup',
  };

  Future<List<News>> getNews({String? category}) async {
    try {
      final query = category != null 
        ? _categoryQueries[category] ?? category 
        : 'news headlines';

      final response = await http.get(
        Uri.parse('$_baseUrl?apiKey=$_apiKey&q=${Uri.encodeComponent(query)}&sortBy=publishedAt&pageSize=20'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<News> newsList = (data['articles'] as List)
          .map((articleData) => News(
            title: articleData['title'] ?? 'No Title',
            description: articleData['description'] ?? 'No Description',
            content: articleData['content'] ?? 'No Content',
            url: articleData['url'] ?? '',
            urlToImage: articleData['urlToImage'] ?? '',
            publishedAt: articleData['publishedAt'] ?? DateTime.now().toIso8601String(),
            source: articleData['source']['name'] ?? 'Unknown Source', id: '', imageUrl: '', category: '',
          ))
          .toList();

        return newsList;
      } else {
        throw Exception('Failed to load news: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching news: $e');
      }
      rethrow;
    }
  }
}