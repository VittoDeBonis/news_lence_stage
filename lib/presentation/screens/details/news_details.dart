import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:news_lens/models/news_class.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:news_lens/presentation/screens/news_summary_chatbot.dart'; // Import this

class NewsDetails extends StatefulWidget {
  final News news;
  const NewsDetails({Key? key, required this.news}) : super(key: key);

  @override
  _NewsDetailsState createState() => _NewsDetailsState();
}

class _NewsDetailsState extends State<NewsDetails> {
  bool _showFullArticle = true;
  late String _category;

  @override
  void initState() {
    super.initState();

    _category = _determineCategory(widget.news);
    if (kDebugMode) {
      print('NewsDetails - categoria finale utilizzata: "$_category"');
    }
  }

  String _determineCategory(News news) {
    if (news.category != null && news.category.isNotEmpty) {
      if (kDebugMode) {
        print('NewsDetails - usando categoria esistente: "${news.category}"');
      }
      return news.category;
    }

    final String searchText = '${news.title} ${news.description ?? ''} ${news.content}'.toLowerCase();

    if (searchText.contains('politic') || searchText.contains('govern') ||
        searchText.contains('elect') || searchText.contains('president')) {
      return 'politics';
    } else if (searchText.contains('sport') || searchText.contains('team') ||
              searchText.contains('match') || searchText.contains('player')) {
      return 'sports';
    } else if (searchText.contains('scien') || searchText.contains('research') ||
              searchText.contains('stud') || searchText.contains('discover')) {
      return 'science';
    } else if (searchText.contains('tech') || searchText.contains('software') ||
              searchText.contains('device') || searchText.contains('digital')) {
      return 'technology';
    } else {
      if (kDebugMode) {
        print('NewsDetails - categoria non determinabile, usando default: "general"');
      }
      return 'general';
    }
  }

  // Define openNewsSummaryChatbot method here
  void openNewsSummaryChatbot(News news) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewsSummaryChatbot(news: news, initialSummary: '', isDialog: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 170.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.news.source,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16.0,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              background: widget.news.imageUrl != null &&
                      widget.news.imageUrl!.isNotEmpty
                  ? Image.network(
                      widget.news.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: Icon(
                            Icons.image_not_supported,
                            size: 100,
                            color: Colors.grey[600],
                          ),
                        );
                      },
                    )
                  : Container(color: Colors.grey[300]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  widget.news.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(
                        _formatPublishedDate(widget.news.publishedAt as String),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                      if (widget.news.url != null && widget.news.url!.isNotEmpty)
                      _buildCategoryIcon(_category),
                      IconButton(
                          icon: const Icon(Icons.smart_toy_outlined),
                          color: Colors.green,
                          onPressed: () => openNewsSummaryChatbot(widget.news), // Use widget.news here
                        ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    widget.news.description ?? 'No description available',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    widget.news.content,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(height: 1.5),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: TextButton.icon(
                    onPressed: _openArticle,
                    icon: const Icon(Icons.link, size: 16),
                    label: const Text("Read full article"),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPublishedDate(String dateString) {
    try {
      final DateTime publishedDate = DateTime.parse(dateString);
      return '${publishedDate.day}/${publishedDate.month}/${publishedDate.year}';
    } catch (e) {
      return 'Data Sconosciuta';
    }
  }

  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  Widget _buildCategoryIcon(String category) {
    String normalizedCategory = category.trim().toLowerCase();
    if (kDebugMode) {
      print('NewsDetails - mostrando icona per categoria: "$normalizedCategory"');
    }

    IconData iconData;
    Color bgColor;
    String displayCategory = normalizedCategory.substring(0, 1).toUpperCase() +
                            normalizedCategory.substring(1);

    switch (normalizedCategory) {
      case 'politics':
        iconData = Icons.account_balance;
        bgColor = Colors.blue;
        break;
      case 'sports':
        iconData = Icons.sports_soccer;
        bgColor = Colors.green;
        break;
      case 'science':
        iconData = Icons.science;
        bgColor = Colors.purple;
        break;
      case 'technology':
        iconData = Icons.computer;
        bgColor = Colors.orange;
        break;
      case 'general':
        iconData = Icons.newspaper;
        bgColor = Colors.teal;
        break;
      default:
        iconData = Icons.newspaper;
        bgColor = Colors.grey;
    }

    return Tooltip(
      message: displayCategory,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          iconData,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
  Future<void> _openArticle() async {
    if (widget.news.url != null && widget.news.url!.isNotEmpty) {
      final Uri url = Uri.parse(widget.news.url!);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open the article"))
        );
      }
    }
  }
}