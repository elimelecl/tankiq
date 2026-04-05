import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/tank_status_card.dart';

class TanksGridScreen extends StatefulWidget {
  const TanksGridScreen({super.key});

  @override
  State<TanksGridScreen> createState() => _TanksGridScreenState();
}

class _TanksGridScreenState extends State<TanksGridScreen> {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _wsSubscription;
  
  List<dynamic> _tanks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTanks();
    _setupWebSocket();
  }

  void _setupWebSocket() {
    _wsService.connect();
    _wsSubscription = _wsService.stream.listen((message) {
      if (message['model'] == 'Tanque') {
        _fetchTanks(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchTanks({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final data = await _apiService.getTanques();
      if (mounted) {
        setState(() {
          _tanks = data;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todos los Tanques'),
        actions: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              const Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(width: 16),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF27E26)))
          : _error != null
              ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.white)))
              : _tanks.isEmpty
                  ? const Center(child: Text('No hay tanques registrados', style: TextStyle(color: Colors.white54)))
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          int crossAxisCount = 2;
                          if (constraints.maxWidth > 600) crossAxisCount = 3;
                          if (constraints.maxWidth > 900) crossAxisCount = 4;

                          return GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: 0.95, // Increased height to eliminate the remaining 2px overflow
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: _tanks.length,
                            itemBuilder: (context, index) {
                              return TankStatusCard(tank: _tanks[index]);
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}
