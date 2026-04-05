import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/tank_form_dialog.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import 'tank_detail_screen.dart';

class TankSettingsScreen extends StatefulWidget {
  const TankSettingsScreen({super.key});

  @override
  State<TankSettingsScreen> createState() => _TankSettingsScreenState();
}

class _TankSettingsScreenState extends State<TankSettingsScreen> {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _wsSubscription;
  
  List<dynamic> _tanks = [];
  bool _isLoading = true;

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
      final tanks = await _apiService.getTanques();
      if (mounted) {
        setState(() {
          _tanks = tanks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Error cargando tanques: $e');
      }
    }
  }

  void _addTanque() async {
    final result = await showDialog(
      context: context,
      builder: (_) => const TankFormDialog(),
    );

    if (result != null) {
      try {
        // Map dialog result to API payload (backend expects specific keys)
        final payload = {
          'nombre': result['name'],
          'capacidad_maxima': result['capacity'],
          'altura_referencia': result['height'],
          'descripcion': 'Generado desde App', 
        };
        
        await _apiService.createTanque(payload);
        _fetchTanks(); // Refresh list
        _showSnack('Tanque creado exitosamente');
      } catch (e) {
        _showSnack('Error creando tanque: $e');
      }
    }
  }

  void _editTanque(Map<String, dynamic> tank) async {
    final result = await showDialog(
      context: context,
      builder: (_) => TankFormDialog(
        existingName: tank['nombre'],
        existingCapacity: tank['capacidad_maxima']?.toDouble(),
        existingHeight: tank['altura_referencia']?.toDouble(),
      ),
    );

    if (result != null) {
      try {
        final payload = {
          'nombre': result['name'],
          'capacidad_maxima': result['capacity'],
          'altura_referencia': result['height'],
        };
        
        await _apiService.updateTanque(tank['id'], payload);
        _fetchTanks(); // Refresh list
        _showSnack('Tanque actualizado');
      } catch (e) {
        _showSnack('Error actualizando tanque: $e');
      }
    }
  }

  void _deleteTanque(int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Tanque', style: TextStyle(color: Color(0xFFF27E26))),
        content: Text(
          '¿Estás seguro de eliminar el $name?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _apiService.deleteTanque(id);
                _fetchTanks();
                _showSnack('Tanque eliminado');
              } catch (e) {
                _showSnack('Error eliminando tanque: $e');
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Tanques'),
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
      drawer: const NavDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF27E26)))
          : _tanks.isEmpty
              ? const Center(child: Text('No hay tanques registrados', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tanks.length,
                  itemBuilder: (context, index) {
                    final tank = _tanks[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                           Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => TankDetailScreen(tank: tank)),
                          );
                        },
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF101524),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.propane_tank, color: Color(0xFFF27E26)),
                          ),
                          title: Text(tank['nombre'] ?? 'Sin Nombre', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          subtitle: Text(
                            'Cap: ${tank['capacidad_maxima']} | Alt: ${tank['altura_referencia']}',
                            style: const TextStyle(color: Colors.white60),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                onPressed: () => _editTanque(tank),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () => _deleteTanque(tank['id'], tank['nombre']),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTanque,
        backgroundColor: const Color(0xFFF27E26),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nuevo Tanque', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
