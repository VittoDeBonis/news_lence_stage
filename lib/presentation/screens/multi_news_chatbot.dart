import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:news_lens/models/news_class.dart';
import 'package:news_lens/presentation/screens/details/news_details.dart';

class MultiNewsChatbot extends StatefulWidget {
  final List<News> selectedNews;
  
  const MultiNewsChatbot({
    super.key,
    required this.selectedNews,
  });

  @override
  State<MultiNewsChatbot> createState() => _MultiNewsChatbotState();
}

class _MultiNewsChatbotState extends State<MultiNewsChatbot> {
  final _openAi = OpenAI.instance.build(
    token: dotenv.env['OPENAI_API_KEY'],
    baseOption: HttpSetup(
      receiveTimeout: const Duration(seconds: 60),
    ),
    enableLog: true,
  );
  
  final ChatUser _currentUser = ChatUser(id: '1', firstName: 'User');
  final ChatUser _gptChatUser = ChatUser(id: '2', firstName: 'Assistant');
  List<ChatMessage> _messages = <ChatMessage>[];
  
  bool _isProcessing = false;
  String? _error;
  
  // Contenuto concatenato di tutte le notizie selezionate per il contesto
  late String _newsContext;
  
  @override
  void initState() {
    super.initState();
    _prepareNewsContext();
    // Removed _sendInitialMessage() call to keep chat empty initially
  }
  
  void _prepareNewsContext() {
    _newsContext = widget.selectedNews.asMap().entries.map((entry) {
      int index = entry.key;
      News news = entry.value;
      return "News #${index + 1}:\nTitle: ${news.title}\nSource: ${news.source}\nContent: ${news.content}";
    }).join("\n\n");
  }
  
  String _buildSystemPrompt() {
    return "You are a helpful assistant that can answer questions about news articles. "
           "The user has selected several news articles, and you have access to their full content "
           "to answer questions accurately. Be concise and informative in your responses. "
           "The full news content is for your reference only and should not be repeated verbatim unless requested.\n\n"
           "$_newsContext";
  }
  
  Future<void> getChatResponse(ChatMessage m) async {
    if (_isProcessing) {
      return;
    }
    
    setState(() {
      _messages.insert(0, m);
      _isProcessing = true;
    });
    
    try {
      // Prepara il messaggio per la API
      List<Map<String, dynamic>> messagesHistory = [
        {"role": "system", "content": _buildSystemPrompt()},
      ];
      
      // Inizia conversazione 
      messagesHistory.addAll(_messages.reversed.map((m) {
        if(m.user == _currentUser) {
          return {"role": "user", "content": m.text};
        } else {
          return {"role": "assistant", "content": m.text};
        }
      }).toList());
      
      final request = ChatCompleteText(
        model: Gpt4oMiniChatModel(),
        messages: messagesHistory,
        maxToken: 500,
      );
      
      final response = await _openAi.onChatCompletion(request: request);
      
      if (response != null && response.choices.isNotEmpty && 
          response.choices.first.message != null) {
        final responseText = response.choices.first.message!.content;
        
        setState(() {
          _messages.insert(0, ChatMessage(
            user: _gptChatUser,
            createdAt: DateTime.now(),
            text: responseText
          ));
        });
      } else {
        throw Exception("Failed to get response from OpenAI");
      }
    } catch (e) {
      setState(() {
        _messages.insert(0, ChatMessage(
          user: _gptChatUser,
          createdAt: DateTime.now(),
          text: "Sorry, I encountered an error while processing your request."
        ));
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat about ${widget.selectedNews.length} Articles'),
      ),
      body: Column(
        children: [
          Expanded(
            child: DashChat(
              currentUser: _currentUser,
              messageOptions: MessageOptions(
                currentUserContainerColor: Theme.of(context).colorScheme.primaryContainer,
                currentUserTextColor: Theme.of(context).colorScheme.onPrimaryContainer,
                containerColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                textColor: Theme.of(context).colorScheme.onSurface,
                showTime: true,
              ),
              inputOptions: InputOptions(
                inputDecoration: InputDecoration(
                  hintText: "Ask about these news articles...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                ),
                sendButtonBuilder: (void Function() onPressed) {
                  return IconButton(
                    icon: Icon(
                      Icons.send,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: onPressed,
                  );
                },
              ),
              onSend: (ChatMessage m) {
                getChatResponse(m);
              },
              messages: _messages,
            ),
          ),
          if (_isProcessing)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Processing your request...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}