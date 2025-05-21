import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:news_lens/presentation/screens/multi_news_chatbot.dart';
import 'package:news_lens/presentation/screens/news_summary_chatbot.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:news_lens/models/news_class.dart';
import 'package:news_lens/presentation/screens/details/news_details.dart';
import 'package:news_lens/providers/news_provider.dart';


class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final NewsProvider _newsProvider = NewsProvider();
  List<News> _newsList = [];
  bool _isLoading = true;
  String? _error;
  String _userId = '';
  List<String> _userInterests = [];
  String? _selectedCategory = 'all'; // Imposta 'all' come categoria predefinita
  final TextEditingController _searchController = TextEditingController();
  List<String> _suggestions = [];
  
  
  List<News> _selectedNews = [];
  bool _isSelectionMode = false;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
      await _loadUserInterests();
      _loadNews();
    } else {
      _loadNews(); 
    }
  }
  
  Future<void> _loadUserInterests() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // Carica gli interessi da Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        
        if (userData['interests'] != null && (userData['interests'] as List).isNotEmpty) {
          // Converte da List<dynamic> a List<String>
          final List<String> interests = (userData['interests'] as List)
              .map((item) => item.toString())
              .toList();
          
          setState(() {
            _userInterests = interests;
          });
        } else {
          setState(() {
            // Se non ci sono interessi salvati, imposta una lista vuota
            _userInterests = [];
          });
        }
      } else {
        setState(() {
          _userInterests = [];
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user interests: $e');
      }
      // In caso di errore, usa un array vuoto
      setState(() {
        _userInterests = [];
      });
    }
  }

  Future<void> _loadNews({String? category}) async {
    try {
      // Reset dello stato
      setState(() {
        _isLoading = true;
        _error = null;
        _selectedCategory = category ?? 'all';
        _selectedNews = [];
        _isSelectionMode = false;
        _searchController.clear(); 
        _suggestions = []; 
      });

      final news = await _newsProvider.getNews(
        category: category == 'all' ? null : category
      );
      
      if (mounted) { 
        setState(() {
          _newsList = news;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) { 
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'all':
        return Icons.view_headline; 
      case 'politics':
        return Icons.account_balance;
      case 'sports':
        return Icons.sports_soccer;
      case 'science':
        return Icons.science;
      case 'technology':
        return Icons.computer;
      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor(String category, BuildContext context) {
    if (_selectedCategory == category) {
      return Theme.of(context).colorScheme.primaryContainer;
    }
    
    switch (category.toLowerCase()) {
      case 'all':
        return Theme.of(context).colorScheme.surfaceContainerLow; 
      case 'politics':
        return Colors.blue.withOpacity(0.2);
      case 'sports':
        return Colors.green.withOpacity(0.2);
      case 'science':
        return Colors.purple.withOpacity(0.2);
      case 'technology':
        return Colors.orange.withOpacity(0.2);
      default:
        return Theme.of(context).colorScheme.surfaceContainerHighest;
    }
  }

  // Metodo per aprire il MultiNewsChatbot con le notizie selezionate
  void _openMultiNewsChat() {
    if (_selectedNews.isEmpty) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiNewsChatbot(
          selectedNews: _selectedNews,
        ),
      ),
    );
  }
  
  void _toggleNewsSelection(News news) {
    setState(() {
      if (_selectedNews.contains(news)) {
        _selectedNews.remove(news);
        if (_selectedNews.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedNews.add(news);
        _isSelectionMode = true;
      }
    });
  }
  
  void _cancelSelection() {
    setState(() {
      _selectedNews.clear();
      _isSelectionMode = false;
    });
  }

  // Metodo per tradurre una categoria
  String _getCategoryTranslation(String category, AppLocalizations l10n) {
    switch (category.toLowerCase()) {
      case 'all':
        return l10n.all;
      case 'politics':
        return l10n.politics;
      case 'sports':
        return l10n.sports;
      case 'science':
        return l10n.science;
      case 'technology':
        return l10n.technology;
      default:
        return category; // Fallback al nome originale se non c'è traduzione
    }
  }

  // Metodo per costruire una categoria di interesse con traduzione
  Widget _buildCategoryItem(String category, {required AppLocalizations l10n}) {
    // Usa la funzione di traduzione per ottenere il nome localizzato
    final displayName = _getCategoryTranslation(category, l10n);
    final isSelected = _selectedCategory == category;
    
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () => _handleCategoryTap(category),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _getCategoryColor(category, context),
                borderRadius: BorderRadius.circular(16),
                border: isSelected 
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2)
                  : null,
              ),
              child: Icon(
                _getCategoryIcon(category),
                size: 30,
                color: isSelected 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    // Lista completa di categorie (all + interessi utente)
    final allCategories = ['all', ..._userInterests];
    
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: _isSelectionMode 
          ? Text('${_selectedNews.length} Selected') 
          : Text(_selectedCategory == 'all' 
              ? l10n.news 
              : '${_getCategoryTranslation(_selectedCategory!, l10n)} ${l10n.news}'),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _cancelSelection,
              tooltip: l10n.cancel,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadNews(category: _selectedCategory),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: _selectedNews.isNotEmpty 
        ? FloatingActionButton.extended(
            onPressed: _openMultiNewsChat,
            label: const Text('GPTChat'),
            icon: const Icon(Icons.chat),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          )
        : null,
      body: Column(
        children: [
          Container(
            height: 110,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: allCategories.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                final category = allCategories[index];
                return _buildCategoryItem(
                  category,
                  l10n: l10n // Passa l10n al builder della categoria
                );
              },
            ),
          ),
            
          Tooltip(
            message: 'Search',
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                onTap: () {},
                controller: _searchController,
                onChanged: (query) {
                  _updateSuggestions(query, l10n);
                },
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ),
          ),
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8.0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8.0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  return ListTile(
                    title: Text(
                      suggestion,
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16.0,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onTap: () {
                      _searchController.text = suggestion;
                      _updateSuggestions('', l10n);
                      
                      // Trova la categoria originale corrispondente alla traduzione
                      final originalCategory = _findOriginalCategory(suggestion, l10n);
                      _loadNews(category: originalCategory);
                    },
                  );
                },
              ),
            ),

          Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor),
              
          Expanded(child: _buildNewsContent(l10n)),
        ],
      ),
    );
  }

  // Metodo per trovare la categoria originale dalla traduzione
  String _findOriginalCategory(String translatedCategory, AppLocalizations l10n) {
    // Lista di tutte le categorie
    final categories = ['all', 'politics', 'sports', 'science', 'technology'];
    
    // Cerca la categoria originale che corrisponde alla traduzione
    for (final category in categories) {
      if (_getCategoryTranslation(category, l10n) == translatedCategory) {
        return category;
      }
    }
    
    // Se non trova corrispondenza, restituisce la categoria tradotta
    return translatedCategory;
  }

  Widget _buildNewsContent(AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadNews(category: _selectedCategory),
              child: Text(l10n.save),
            ),
          ],
        ),
      );
    }

    if (_newsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sentiment_dissatisfied, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _selectedCategory != 'all' 
                ? 'No news available for ${_getCategoryTranslation(_selectedCategory!, l10n)}' 
                : 'No news available',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        )
      );
    }
    
    return RefreshIndicator(
      onRefresh: () => _loadNews(category: _selectedCategory),
      child: ListView.builder(
        itemCount: _newsList.length,
        itemBuilder: (context, index) {
          final news = _newsList[index];
          final isSelected = _selectedNews.contains(news);
          
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: isSelected 
                ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                : BorderSide.none,
            ),
            child: InkWell(
              onLongPress: () {
                _toggleNewsSelection(news);
              },
              onTap: () {
                if (_isSelectionMode) {
                  _toggleNewsSelection(news);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NewsDetails(news: news),
                    ),
                  );
                }
              },
              child: ListTile(
                contentPadding: const EdgeInsets.all(8),
                title: Text(
                  news.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected 
                      ? Theme.of(context).colorScheme.primary
                      : null,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    news.source,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
                trailing: _isSelectionMode 
                  ? Checkbox(
                      value: isSelected,
                      onChanged: (bool? value) {
                        _toggleNewsSelection(news);
                      },
                    )
                  : Tooltip(
                      message: 'Riassumi con ChatGPT',
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: IconButton(
                          icon: const Icon(Icons.smart_toy_outlined),
                          color: Colors.green,
                          onPressed: () => _openNewsSummaryChatbot(news),
                        ),
                      ),
                    ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  void _updateSuggestions(String query, AppLocalizations l10n) {
    setState(() {
      if(query.isEmpty){
        _suggestions = [];
      } else {
        // Utilizza una lista completa di categorie
        final allCategories = ['all', ..._userInterests];
        
        _suggestions = allCategories.where((category) {
          // Ottieni la traduzione della categoria
          final translatedCategory = _getCategoryTranslation(category, l10n);
          
          return translatedCategory.toLowerCase().contains(query.toLowerCase()) ||
                 category.toLowerCase().contains(query.toLowerCase());
        }).map((category) => _getCategoryTranslation(category, l10n)).toList();
      }
    });
  }

  void _handleCategoryTap(String category) {
    // Se è già selezionata la stessa categoria, non fa nulla
    if (_selectedCategory == category) return;
    
    _loadNews(category: category);
  }

  void _openNewsSummaryChatbot(News news) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewsSummaryChatbot(news: news, initialSummary: '', isDialog: true),
      ),
    );
  }
}