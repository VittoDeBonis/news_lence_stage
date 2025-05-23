import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:news_lens/providers/locale_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:translator/translator.dart';
import 'package:provider/provider.dart';
import 'package:news_lens/models/news_class.dart';
import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:open_file/open_file.dart'; 
import 'dart:io';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class NewsSummaryChatbot extends StatefulWidget {
  final News news;
  final String initialSummary;
  final bool isDialog;
  const NewsSummaryChatbot({
    super.key,
    required this.news,
    required this.initialSummary,
    required this.isDialog,
  });

  @override
  State<NewsSummaryChatbot> createState() => _NewsSummaryChatbotState();
}

class _NewsSummaryChatbotState extends State<NewsSummaryChatbot> {
  late String _summary;
  late String _displayTitle;
  final _openAi = OpenAI.instance.build(
    token: dotenv.env['OPENAI_API_KEY'],
    baseOption: HttpSetup(receiveTimeout: const Duration(seconds: 30)),
    enableLog: true,
  );
  late FlutterTts flutterTts;
  final GoogleTranslator _translator = GoogleTranslator();
  bool _isSpeaking = false;
  bool _isTranslating = false;
  final double _volume = 1.0;
  final double _pitch = 1.0;
  final double _rate = 0.5;
  String? _language;
  String? _errorMessage;
  String _originalSummary = '';
  String _originalTitle = '';
  bool _isTranslated = false;
  bool _isProcessing = false;
  bool _showLoadingIndicator = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _summary = widget.initialSummary.isNotEmpty ? widget.initialSummary : '';
    _originalSummary = _summary;
    _displayTitle = widget.news.title;
    _originalTitle = widget.news.title;
    _initTts();
    if (widget.initialSummary.isEmpty) {
      setState(() {
        _showLoadingIndicator = true;
      });
      _checkExistingSummaryOrGenerate();
    }
  }

  Future<void> _logSummaryGenerationActivity() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print("Cannot log activity: No user logged in");
        }
        return;
      }
      
      final activityData = {
        'userId': user.uid,
        'activityType': 'summary_generated',
        'newsId': widget.news.id,
        'newsTitle': widget.news.title,
        'description': 'User requested summary generation for news article',
        'timestamp': FieldValue.serverTimestamp(),
      };
      
      await _firestore.collection('activity_logs').add(activityData);
      
      if (kDebugMode) {
        print("Activity logged successfully");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error logging activity: $e");
      }
    }
  }

  void _generateInitialSummary() async {
    if (_isProcessing) return;
    
    // Registra che l'utente ha richiesto una generazione di riepilogo
    await _logSummaryGenerationActivity();
    
    setState(() {
      _isProcessing = true;
      _showLoadingIndicator = true;
    });
    
    try {
      final request = ChatCompleteText(
        model: Gpt4oMiniChatModel(),
        messages: [
          {
            "role": "system",
            "content": "You are a helpful assistant that summarizes news articles.",
          },
          {
            "role": "user",
            "content": "Please summarize this news article in 5-6 sentences in the same language as written. Title: ${widget.news.title}. Content: ${widget.news.content ?? 'No content available'}",
          },
        ],
        maxToken: 300,
      );
      
      final response = await _openAi.onChatCompletion(request: request);
      String responseText;
      
      if (response != null &&
          response.choices.isNotEmpty &&
          response.choices.first.message != null) {
        responseText = response.choices.first.message!.content;
      } else {
        responseText = "Unable to generate a summary for this article.";
      }
      
      if (mounted) {
        setState(() {
          _summary = responseText;
          _originalSummary = responseText;
          _isProcessing = false;
          _showLoadingIndicator = false;
        });
        
        _saveSummaryToFirebase(responseText);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error generating summary: $e");
      }
      
      if (mounted) {
        setState(() {
          _summary = "Sorry, I couldn't summarize this article.";
          _originalSummary = _summary;
          _isProcessing = false;
          _showLoadingIndicator = false;
        });
      }
    }
  }

  Future<void> _checkExistingSummaryOrGenerate() async {
    try {
      final QuerySnapshot summarySnapshot = await _firestore
          .collection('news_summaries')
          .where('newsTitle', isEqualTo: widget.news.title)
          .where('language', isEqualTo: 'original')
          .limit(1)
          .get();
          
      if (summarySnapshot.docs.isNotEmpty) {
        final existingSummary = summarySnapshot.docs.first.data() as Map<String, dynamic>;
        
        if (mounted) {
          setState(() {
            _summary = existingSummary['summary'] as String;
            _originalSummary = _summary;
            _showLoadingIndicator = false;
            _isProcessing = false;
          });
          
          await _logSummaryGenerationActivity();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Using an existing summary"),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        _generateInitialSummary();
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error in checking existing summaries: $e");
      }
      _generateInitialSummary();
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      if (date is DateTime) {
        return DateFormat('dd/MM/yyyy').format(date);
      }
      if (date is String) {
        DateTime? parsedDate;
        try {
          parsedDate = DateTime.parse(date);
          return DateFormat('dd/MM/yyyy').format(parsedDate);
        } catch (_) {}
        try {
          final parts = date.split('/');
          if (parts.length == 3) {
            parsedDate = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
            return DateFormat('dd/MM/yyyy').format(parsedDate);
          }
        } catch (_) {}
        return date;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error formatting date: $e');
      }
    }
    return 'N/A';
  }

  Future<void> _saveSummaryToFirebase(String summary, {bool isRegeneratedSummary = false}) async {
    try{
      final User? user = _auth.currentUser;
      if(user == null){
        print("Cannot save the summary: No user logged in");
        return;
      }
      
      final summaryData = {
        'userId': user.uid,
        'newsId': widget.news.id,        
        'newsTitle': widget.news.title,
        'newsSource': widget.news.source,
        'summary': summary,  
        'language': _isTranslated
          ? Provider.of<LocaleProvider>(context, listen: false)
            .locale 
            .languageCode
          : 'original',
        'publishedAt': widget.news.publishedAt,
        'createdAt': FieldValue.serverTimestamp(),  
        'url': widget.news.url,
        'isRegeneratedSummary': isRegeneratedSummary, 
      };
      
      await _firestore.collection('news_summaries').add(summaryData);
      
      if (kDebugMode) {
        print("Summary saved successfully");
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Summary saved successfully"),
          duration: Duration(seconds: 2),
        )
      );
    } catch(e) {
      if(kDebugMode){
        print("Error saving summary to firebase: $e");
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving summary: ${e.toString()}")),
      );
    }
  }

  Future<void> _initTts() async {
    flutterTts = FlutterTts();
    try {
      var isSupported = await flutterTts.isLanguageAvailable('it-IT');
      print('Italian language supported: $isSupported');
      await flutterTts.setLanguage('it_IT');
      _language = 'it_IT';
      await flutterTts.setVolume(_volume);
      await flutterTts.setPitch(_pitch);
      await flutterTts.setSpeechRate(_rate);
      await flutterTts.awaitSpeakCompletion(true);
      var languages = await flutterTts.getLanguages;
      print('Available languages: $languages');
      flutterTts.setStartHandler(() {
        print('TTS STARTED');
        setState(() {
          _isSpeaking = true;
          _errorMessage = null;
        });
      });
      flutterTts.setCompletionHandler(() {
        if (kDebugMode) {
          print("TTS COMPLETED");
        }
        setState(() {
          _isSpeaking = false;
        });
      });
      flutterTts.setCancelHandler(() {
        if (kDebugMode) {
          print("TTS CANCELLED");
        }
        _isSpeaking = false;
      });
      flutterTts.setErrorHandler((message) {
        if (kDebugMode) {
          print("TTS ERROR: $message");
        }
        setState(() {
          _isSpeaking = false;
          _errorMessage = message;
        });
      });
      if (kDebugMode) {
        print('TTS initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing TTS $e');
      }
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _speak() async {
    if (_summary.isEmpty) {
      if (kDebugMode) {
        print("Summary is empty, nothing to speak");
      }
      return;
    }
    try {
      if (_isSpeaking) {
        if (kDebugMode) {
          print("Stopping TTS");
        }
        await flutterTts.stop();
        setState(() {
          _isSpeaking = false;
        });
      } else {
        String textToSpeak = "$_displayTitle. $_summary";
        if (kDebugMode) {
          print("Starting TTS with text: ${textToSpeak.substring(0, textToSpeak.length > 20 ? 20 : textToSpeak.length)}...");
        }
        await flutterTts.setVolume(_volume);
        await flutterTts.setPitch(_pitch);
        await flutterTts.setSpeechRate(_rate);
        var result = await flutterTts.speak(textToSpeak);
        if (kDebugMode) {
          print("speak result: $result");
        }
        if (result == 1) {
          Future.delayed(const Duration(seconds: 5), () async {
            await flutterTts.speak(textToSpeak);
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error while speaking: $e");
      }
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  void _translateSummary() async {
    if (_isTranslated) {
      setState(() {
        _summary = _originalSummary;
        _displayTitle = _originalTitle;
        _isTranslated = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restored original content'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await _logSummaryTranslationActivity();
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final String targetLanguage = localeProvider.locale.languageCode;
    if (kDebugMode) {
      print("Current locale: ${localeProvider.locale}");
    }
    if (kDebugMode) {
      print("Target language for translation: ${targetLanguage}");
    }
    try {
      final QuerySnapshot translatedSnapshot = await _firestore
          .collection('news_summaries')
          .where('newsTitle', isEqualTo: widget.news.title)
          .where('language', isEqualTo: targetLanguage)
          .limit(1)
          .get();
      if (translatedSnapshot.docs.isNotEmpty) {
        final existingTranslation = translatedSnapshot.docs.first.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            if (!_isTranslated) {
              _originalTitle = widget.news.title;
              _originalSummary = _summary;
            }
            _displayTitle = existingTranslation['newsTitle'] as String;
            _summary = existingTranslation['summary'] as String;
            _isTranslating = false;
            _isTranslated = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Using an existing translation ${targetLanguage.toUpperCase()}"),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error in checking existing translations: $e");
      }
    }
    setState(() {
      _isTranslating = true;
    });
    try {
      final translatedTitle = await _translator.translate(
        widget.news.title,
        to: targetLanguage,
      );
      final translatedSummary = await _translator.translate(
        _summary,
        to: targetLanguage,
      );
      if (mounted) {
        setState(() {
          if (!_isTranslated) {
            _originalTitle = widget.news.title;
            _originalSummary = _summary;
          }
          _displayTitle = translatedTitle.text;
          _summary = translatedSummary.text;
          _isTranslating = false;
          _isTranslated = true;
        });
        _saveSummaryToFirebase(translatedSummary.text);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Translated into ${localeProvider.locale.languageCode.toUpperCase()}"),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error during translation: $e");
      }
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error during translation"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  Future<String?> _checkForExistingRegeneratedSummary() async {
    try {
      final QuerySnapshot regeneratedSnapshot = await _firestore
          .collection('news_summaries')
          .where('newsTitle', isEqualTo: widget.news.title)
          .where('language', isEqualTo: 'original')
          .where('isRegeneratedSummary', isEqualTo: true)
          .limit(1)
          .get();
      if (regeneratedSnapshot.docs.isNotEmpty) {
        final existingRegeneratedSummary = regeneratedSnapshot.docs.first.data() as Map<String, dynamic>;
        return existingRegeneratedSummary['summary'] as String;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print("Error checking for regenerated summary: $e");
      }
      return null;
    }
  }

  Future<void> _regenerateSummary() async {
    setState(() {
      _isProcessing = true;
      _showLoadingIndicator = true;
    });
    await _logSummaryRegenerationActivity();
    final existingRegeneratedSummary = await _checkForExistingRegeneratedSummary();
    
    if (existingRegeneratedSummary != null) {
      if (mounted) {
        setState(() {
          _summary = existingRegeneratedSummary;
          _originalSummary = existingRegeneratedSummary;
          _isProcessing = false;
          _showLoadingIndicator = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Using an existing regenerated summary"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      try {
        final request = ChatCompleteText(
          model: Gpt4oMiniChatModel(),
          messages: [
            {
              "role": "system",
              "content": "You are a helpful assistant that summarizes news articles. The previous summary was rated poorly, please create a more accurate and concise summary.",
            },
            {
              "role": "user",
              "content": "Please create a better summary for this news article in 5-6 sentences in the same language as written. Title: ${widget.news.title}. Content: ${widget.news.content ?? 'No content available'}",
            },
          ],
          maxToken: 300,
        );
        
        final response = await _openAi.onChatCompletion(request: request);
        String responseText;
        
        if (response != null &&
            response.choices.isNotEmpty &&
            response.choices.first.message != null) {
          responseText = response.choices.first.message!.content;
        } else {
          responseText = "Unable to generate a better summary for this article.";
        }
        
        if (mounted) {
          setState(() {
            _summary = responseText;
            _originalSummary = responseText;
            _isProcessing = false;
            _showLoadingIndicator = false;
          });
          
          _saveSummaryToFirebase(responseText, isRegeneratedSummary: true);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("New summary successfully generated"),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print("Error regenerating summary: $e");
        }
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _showLoadingIndicator = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Error in summary regeneration"),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  void _showRatingDialog(){
    showDialog(
      context: context, 
      builder: (BuildContext context){
        return AlertDialog(
          title: const Text("Rate this summary"),
          content: null,
          actions: [
            Row(
              children: [
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _logSummaryRatingActivity(false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Checking for regenerated summary..."),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    _regenerateSummary();
                  },
                  child: const Icon(Icons.thumb_down, color: Colors.blue,)
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop(); 
                    await _logSummaryRatingActivity(true);
                  },
                  child: const Icon(Icons.thumb_up, color: Colors.blue),
                )
              ],
            ),          
          ],
        );
      }
    );
  }

  Future<void> _generateAndSavePdf() async {
    setState(() {
      _isProcessing = true;
    });
    await _logPdfGenerationActivity();
    try {
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _displayTitle,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                widget.news.source,
                style: const pw.TextStyle(
                  fontSize: 14,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Text(
                    "Published: ${_formatDate(widget.news.publishedAt)}",
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Summary',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                _summary,
                style: const pw.TextStyle(
                  fontSize: 12,
                  lineSpacing: 1.5,
                ),
              ),
              pw.SizedBox(height: 20),
            ],
          ),
        ),
      );
      
      final output = await path_provider.getApplicationDocumentsDirectory();
      final fileName = 'ciao_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF salvato in: ${file.path}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Apri',
              onPressed: () {
                OpenFile.open(file.path);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Errore durante la creazione del PDF: $e');
      }
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel salvataggio del PDF: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _generateAndSharePdf() async {
    setState(() {
      _isProcessing = true;
    });
    await _logSummaryShareActivity();
    
    try {
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _displayTitle,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                widget.news.source,
                style: const pw.TextStyle(
                  fontSize: 14,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Text(
                    "Published: ${_formatDate(widget.news.publishedAt)}",
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Summary',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                _summary,
                style: const pw.TextStyle(
                  fontSize: 12,
                  lineSpacing: 1.5,
                ),
              ),
              pw.SizedBox(height: 20),           
            ],
          ),
        ),
      );
      
      final output = await path_provider.getApplicationDocumentsDirectory();
      final fileName = 'news_summary_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${output.path}/$fileName';
      final file = File(filePath);
      
      await file.writeAsBytes(await pdf.save());
      
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'News Summary: $_displayTitle',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during PDF generation or sharing: $e');
      }
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing PDF: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }


  Future<void> _logSummaryRegenerationActivity() async {
  try {
    final User? user = _auth.currentUser;
    if (user == null) {
      if (kDebugMode) {
        print("Cannot log activity: No user logged in");
      }
      return;
    }
    
    final activityData = {
      'userId': user.uid,
      'activityType': 'summary_regenerated',
      'newsId': widget.news.id,
      'newsTitle': widget.news.title,
      'description': 'User requested summary regeneration for news article',
      'timestamp': FieldValue.serverTimestamp(),
    };
    
    await _firestore.collection('activity_logs').add(activityData);
    
    if (kDebugMode) {
      print("Regeneration activity logged successfully");
    }
  } catch (e) {
    if (kDebugMode) {
      print("Error logging regeneration activity: $e");
    }
  }
}

// Metodo per registrare la traduzione del sommario
Future<void> _logSummaryTranslationActivity() async {
  try {
    final User? user = _auth.currentUser;
    if (user == null) {
      if (kDebugMode) {
        print("Cannot log activity: No user logged in");
      }
      return;
    }
    
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final String targetLanguage = localeProvider.locale.languageCode;
    
    final activityData = {
      'userId': user.uid,
      'activityType': 'summary_translated',
      'newsId': widget.news.id,
      'newsTitle': widget.news.title,
      'description': 'Summary translated to ${targetLanguage.toUpperCase()}',
      'timestamp': FieldValue.serverTimestamp(),
    };
    
    await _firestore.collection('activity_logs').add(activityData);
    
    if (kDebugMode) {
      print("Translation activity logged successfully");
    }
  } catch (e) {
    if (kDebugMode) {
      print("Error logging translation activity: $e");
    }
  }
}

// Metodo per registrare il rating del sommario
Future<void> _logSummaryRatingActivity(bool isPositive) async {
  try {
    final User? user = _auth.currentUser;
    if (user == null) {
      if (kDebugMode) {
        print("Cannot log activity: No user logged in");
      }
      return;
    }
    
    final activityData = {
      'userId': user.uid,
      'activityType': 'summary_rated',
      'newsId': widget.news.id,
      'newsTitle': widget.news.title,
      'description': isPositive 
          ? 'User rated summary positively (thumbs up)'
          : 'User rated summary negatively (thumbs down)',
      'timestamp': FieldValue.serverTimestamp(),
    };
    
    await _firestore.collection('activity_logs').add(activityData);
    
    if (kDebugMode) {
      print("Rating activity logged successfully");
    }
  } catch (e) {
    if (kDebugMode) {
      print("Error logging rating activity: $e");
    }
  }
}

// Metodo per registrare la condivisione del sommario
Future<void> _logSummaryShareActivity() async {
  try {
    final User? user = _auth.currentUser;
    if (user == null) {
      if (kDebugMode) {
        print("Cannot log activity: No user logged in");
      }
      return;
    }
    
    final activityData = {
      'userId': user.uid,
      'activityType': 'summary_shared',
      'newsId': widget.news.id,
      'newsTitle': widget.news.title,
      'description': 'User shared summary as PDF',
      'timestamp': FieldValue.serverTimestamp(),
    };
    
    await _firestore.collection('activity_logs').add(activityData);
    
    if (kDebugMode) {
      print("Share activity logged successfully");
    }
  } catch (e) {
    if (kDebugMode) {
      print("Error logging share activity: $e");
    }
  }
}

// Metodo per registrare la generazione di PDF
Future<void> _logPdfGenerationActivity() async {
  try {
    final User? user = _auth.currentUser;
    if (user == null) {
      if (kDebugMode) {
        print("Cannot log activity: No user logged in");
      }
      return;
    }
    
    final activityData = {
      'userId': user.uid,
      'activityType': 'pdf_generated',
      'newsId': widget.news.id,
      'newsTitle': widget.news.title,
      'description': 'User generated PDF of summary',
      'timestamp': FieldValue.serverTimestamp(),
    };
    
    await _firestore.collection('activity_logs').add(activityData);
    
    if (kDebugMode) {
      print("PDF generation activity logged successfully");
    }
  } catch (e) {
    if (kDebugMode) {
      print("Error logging PDF generation activity: $e");
    }
  }
}

  @override
  Widget build(BuildContext context) {
    if (_showLoadingIndicator) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Summary'),
          automaticallyImplyLeading: true,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                "Generating summary...",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Summary'),
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _displayTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.news.source,
              style: const TextStyle(
                fontSize: 18,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(widget.news.publishedAt),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Summary',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          _speak();
                        },
                        icon: Icon(
                          _isSpeaking ? Icons.stop : Icons.campaign,
                          color: _isSpeaking ? Colors.red : Colors.white,
                        ),
                      ),
                      const SizedBox(width: 22),
                      IconButton(
                        onPressed: _isTranslating ? null : _translateSummary,
                        icon: _isTranslating
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                Icons.translate,
                                color: _isTranslated ? Colors.green : Colors.white,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              _summary,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 250),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    IconButton(
                      onPressed: () {
                      _showRatingDialog();
                      },
                      icon: const Icon(Icons.rate_review, color: Colors.white),
                    ),
                    const Text('Rate Summary')
                  ],
                ),
                Column(
                  children: [
                    IconButton(
                      onPressed: _isProcessing ? null : _generateAndSavePdf,
                      icon: _isProcessing
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.picture_as_pdf, color: Colors.white),
                    ),
                    const Text('Save PDF')
                  ],
                ),
                Column(
                  children: [
                    IconButton(
                      onPressed: () {
                      _generateAndSharePdf();
                      },
                      icon: const Icon(Icons.share, color: Colors.white),
                    ),
                    const Text('Share PDF')
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}