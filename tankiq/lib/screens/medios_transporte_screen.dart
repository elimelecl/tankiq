import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/nav_drawer.dart';

class MediosTransporteScreen extends StatefulWidget {
  const MediosTransporteScreen({super.key});

  @override
  State<MediosTransporteScreen> createState() => _MediosTransporteScreenState();
}

class _MediosTransporteScreenState extends State<MediosTransporteScreen> {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _wsSubscription;

  List<dynamic> _medios = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMedios();
    _setupWebSocket();
  }

  void _setupWebSocket() {
    _wsService.connect();
    _wsSubscription = _wsService.stream.listen((message) {
      if (message['model'] == 'MedioTransporte') {
        _fetchMedios(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  final Map<String, IconData> _iconMap = {
    'local_shipping': Icons.local_shipping,
    'directions_boat': Icons.directions_boat,
    'train': Icons.train,
    'swap_horiz': Icons.swap_horiz,
    'inventory_2': Icons.inventory_2,
    'factory': Icons.factory,
    'account_balance': Icons.account_balance,
  };

  IconData _getIconData(String? name) {
    if (name == null || !_iconMap.containsKey(name)) {
      return Icons.category;
    }
    return _iconMap[name]!;
  }

  Future<void> _fetchMedios({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final data = await _apiService.getMediosTransporte();
      if (mounted) {
        setState(() {
          _medios = data;
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

  Future<void> _deleteMedio(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Estás seguro de que deseas eliminar este medio de transporte?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteMedioTransporte(id);
        _fetchMedios();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Medio de transporte eliminado')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showMedioDialog({Map<String, dynamic>? medio}) {
    final isEditing = medio != null;
    final nameController = TextEditingController(text: isEditing ? medio['nombre'] : '');
    String selectedIcon = isEditing ? (medio['icono'] ?? 'local_shipping') : 'local_shipping';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(isEditing ? 'Editar Medio' : 'Nuevo Medio de Transporte'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 20),
                  const Text('Seleccionar Icono', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _iconMap.keys.map((iconName) {
                      bool isSelected = selectedIcon == iconName;
                      return GestureDetector(
                        onTap: () => setStateDialog(() => selectedIcon = iconName),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFF27E26).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFF27E26) : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _iconMap[iconName],
                            color: isSelected ? const Color(0xFFF27E26) : Colors.white54,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nota: La edición de imágenes se implementará en una versión futura.',
                    style: TextStyle(fontSize: 10, color: Colors.white54),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty) return;
                  final data = {
                    'nombre': nameController.text,
                    'icono': selectedIcon,
                  };
                  try {
                    if (isEditing) {
                      await _apiService.updateMedioTransporte(medio['id'], data);
                    } else {
                      await _apiService.createMedioTransporte(data);
                    }
                    if (mounted) {
                      Navigator.pop(ctx);
                      _fetchMedios();
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: Text(isEditing ? 'Actualizar' : 'Crear'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medios de Transporte'),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMedioDialog(),
        backgroundColor: const Color(0xFFF27E26),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF27E26)))
          : _error != null
              ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
              : _medios.isEmpty
                  ? const Center(child: Text('No hay medios registrados.', style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _medios.length,
                      itemBuilder: (context, index) {
                        final m = _medios[index];
                        final IconData icon = _getIconData(m['icono']);
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: m['imagen'] != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        m['imagen'],
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Icon(icon, color: const Color(0xFFF27E26)),
                                      ),
                                    )
                                  : Icon(icon, color: const Color(0xFFF27E26)),
                            ),
                            title: Text(m['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                                  onPressed: () => _showMedioDialog(medio: m),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                  onPressed: () => _deleteMedio(m['id']),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
