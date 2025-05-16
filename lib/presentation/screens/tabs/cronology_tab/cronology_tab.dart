import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:news_lens/models/activity_log.dart';

/// Scheda che mostra la cronologia delle attività dell'utente
class CronologyTab extends StatefulWidget {
  const CronologyTab({super.key});

  @override
  State<CronologyTab> createState() => _CronologyTabState();
}

class _CronologyTabState extends State<CronologyTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  List<ActivityLog> _activityLogs = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filterType = 'all'; // Tipo di filtro corrente
  String _eventName = ''; // Nome dell'evento da configurazione remota

  @override
  void initState() {
    super.initState();
    _initRemoteConfig(); // Inizializza la configurazione remota all'avvio
  }

  /// Inizializza la configurazione remota e carica le informazioni necessarie
  Future<void> _initRemoteConfig() async {
    try {
      // Impostare la configurazione remota
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(seconds: 10),
      ));
      await _remoteConfig.fetchAndActivate();

      // Ottieni il nome dell'evento dalla configurazione remota
      final eventName = _remoteConfig.getString("event");
      if (mounted) {
        setState(() {
          _eventName = eventName;
        });
      }

      // Ora carica i registri delle attività
      _loadActivityLogs();
    } catch (e) {
      if (kDebugMode) {
        print('Errore durante l\'inizializzazione della configurazione remota: $e');
      }
      // Prova comunque a caricare i registri delle attività anche se la configurazione remota fallisce
      _loadActivityLogs();
    }
  }

  /// Carica i registri delle attività dall'utente corrente da Firestore
  Future<void> _loadActivityLogs() async {
    if (_auth.currentUser == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Utente non loggato';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final String userId = _auth.currentUser!.uid;
      QuerySnapshot snapshot;

      // Approccio query modificato che rimuove l'ordinamento per timestamp per evitare problemi di indice
      if (_filterType == 'all') {
        // Per "tutti" otterremo documenti senza usare orderBy temporaneamente
        snapshot = await _firestore
            .collection('activity_logs')
            .where('userId', isEqualTo: userId)
            // Rimozione dell'ordinaPer evitare problemi di indice
            .limit(100)
            .get();
      } else {
        // Per le visualizzazioni filtrate, basta filtrare per tipo senza ordinamento complesso
        snapshot = await _firestore
            .collection('activity_logs')
            .where('userId', isEqualTo: userId)
            .where('activityType', isEqualTo: _filterType)
            // Rimozione dell'ordinaPer evitare problemi di indice
            .limit(100)
            .get();
      }

      // Dopo aver ottenuto i documenti, li ordina manualmente nel codice Dart
      final List<ActivityLog> logs = snapshot.docs.map((doc) {
        return ActivityLog.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      // Ordina i log manualmente per timestamp (dal più recente al meno recente)
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (mounted) {
        setState(() {
          _activityLogs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Errore durante il caricamento dei registri delle attività: $e');
      }

      // Crea un messaggio di errore utile per l'utente
      String userErrorMessage;
      if (e.toString().contains('FAILED_PRECONDITION') &&
          e.toString().contains('requires an index')) {
        userErrorMessage =
            'Rilevato un problema di indicizzazione del database. Assicurati di avere gli indici Firestore appropriati creati. Codice errore: FS-IDX-001';
      } else {
        userErrorMessage =
            'Impossibile caricare la cronologia delle attività. Riprova più tardi.';
      }

      if (mounted) {
        setState(() {
          _errorMessage = userErrorMessage;
          _isLoading = false;
        });
      }
    }
  }

  /// Costruisce la barra orizzontale con i chip di filtro
  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('Tutte le Attività', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('Sommari', 'summary_generated'),
          const SizedBox(width: 8),
          _buildFilterChip('Rigenerazioni', 'summary_regenerated'),
          const SizedBox(width: 8),
          _buildFilterChip('Traduzioni', 'summary_translated'),
          const SizedBox(width: 8),
          _buildFilterChip('Condivisioni', 'summary_shared'),
        ],
      ),
    );
  }

  /// Costruisce un singolo chip di filtro
  Widget _buildFilterChip(String label, String filterValue) {
    final isSelected = _filterType == filterValue;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        setState(() {
          _filterType = filterValue;
        });
        _loadActivityLogs();
      },
      backgroundColor: isSelected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceVariant,
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
    );
  }

  /// Formatta una data/ora come stringa leggibile
  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  /// Restituisce l'icona appropriata per un tipo di attività
  IconData _getActivityIcon(String activityType) {
    switch (activityType) {
      case 'summary_generated':
        return Icons.summarize;
      case 'summary_regenerated':
        return Icons.refresh;
      case 'summary_rated':
        return Icons.thumb_up_alt;
      case 'summary_translated':
        return Icons.translate;
      case 'summary_shared':
        return Icons.share;
      case 'multi_news_chat':
        return Icons.chat;
      case 'pdf_generated':
        return Icons.picture_as_pdf;
      default:
        return Icons.history;
    }
  }

  /// Restituisce l'etichetta leggibile per un tipo di attività
  String _getActivityLabel(String activityType) {
    switch (activityType) {
      case 'summary_generated':
        return 'Sommario Generato';
      case 'summary_regenerated':
        return 'Sommario Rigenerato';
      case 'summary_rated':
        return 'Sommario Valutato';
      case 'summary_translated':
        return 'Sommario Tradotto';
      case 'summary_shared':
        return 'Sommario Condiviso';
      case 'multi_news_chat':
        return 'Chat Multi-Notizia';
      case 'pdf_generated':
        return 'PDF Generato';
      default:
        return 'Attività';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_eventName.isNotEmpty
            ? 'Cronologia delle Attività - $_eventName'
            : 'Cronologia delle Attività'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActivityLogs,
            tooltip: 'Aggiorna',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48,
                                color: Theme.of(context).colorScheme.error),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadActivityLogs,
                              child: const Text('Riprova'),
                            ),
                          ],
                        ),
                      )
                    : _activityLogs.isEmpty
                        ? _buildEmptyState()
                        : _buildActivityList(),
          ),
        ],
      ),
    );
  }

  /// Mostra uno stato vuoto quando non ci sono attività da mostrare
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 72,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Nessuna cronologia delle attività trovata',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filterType != 'all'
                ? 'Prova a cambiare il filtro o genera nuovi contenuti'
                : 'La tua cronologia delle attività apparirà qui',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Costruisce la lista delle attività
  Widget _buildActivityList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _activityLogs.length,
      itemBuilder: (context, index) {
        final activity = _activityLogs[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                _getActivityIcon(activity.activityType),
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    _getActivityLabel(activity.activityType),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Indicatore di stato per errori API
                if (activity.activityType == 'summary_generated' ||
                    activity.activityType == 'summary_regenerated' ||
                    activity.activityType == 'summary_translated')
                  Tooltip(
                    message: activity.description.contains('failed') ||
                            activity.description.contains('error')
                        ? 'Azione fallita a causa di problemi API'
                        : 'Azione completata con successo',
                    child: Icon(
                      activity.description.contains('failed') ||
                              activity.description.contains('error')
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      size: 16,
                      color: activity.description.contains('failed') ||
                              activity.description.contains('error')
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                activity.newsTitle.isNotEmpty
                    ? Text(
                        'Notizia: ${activity.newsTitle}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      )
                    : const SizedBox.shrink(),
                activity.newsTitle.isNotEmpty
                    ? const SizedBox(height: 4)
                    : const SizedBox.shrink(),
                Text(
                  activity.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(activity.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}