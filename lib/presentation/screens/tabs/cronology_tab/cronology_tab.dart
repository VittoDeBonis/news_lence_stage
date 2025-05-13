import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';

class CronologyTab extends StatefulWidget {
  const CronologyTab({super.key});

  @override
  State<CronologyTab> createState() => _CronologyTabState();
}

class _CronologyTabState extends State<CronologyTab> {
  final _remoteConfig = FirebaseRemoteConfig.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initRemoteConfig();
  }

  _initRemoteConfig() async {
    setState(() {
      _isLoading = true;
    });

    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(seconds: 10),
    ));
    
    await _remoteConfig.fetchAndActivate();
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomCard(text: "For this event: ${_remoteConfig.getString("event")}"),
                ],
              ),
      ),
    );
  }
}

class CustomCard extends StatelessWidget {
  final String text;

  const CustomCard({
    Key? key,
    required this.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}