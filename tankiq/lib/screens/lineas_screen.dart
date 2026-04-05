import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../utils/formatters.dart';

class LineasScreen extends StatefulWidget {
  const LineasScreen({super.key});

  @override
  State<LineasScreen> createState() => _LineasScreenState();
}

class _LineasScreenState extends State<LineasScreen> {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _wsSubscription;
  
  List<dynamic> _lineas = [];
  List<dynamic> _tanks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _setupWebSocket();
  }

  void _setupWebSocket() {
    _wsService.connect();
    _wsSubscription = _wsService.stream.listen((message) {
      final model = message['model'];
      if (model == 'Linea' || model == 'Tanque') {
        _fetchData(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final lineasData = await _apiService.getLineas();
      final tanksData = await _apiService.getTanques();
      if (mounted) {
        setState(() {
          _lineas = lineasData;
          _tanks = tanksData;
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

  Future<void> _deleteLinea(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Estás seguro de que deseas eliminar esta línea?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteLinea(id);
        _fetchData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Línea eliminada')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showLineDialog({Map<String, dynamic>? linea}) async {
    final isEditing = linea != null;
    final nameController = TextEditingController(text: isEditing ? linea['nombre'] : '');
    final tovController = TextEditingController(text: isEditing ? linea['volumen_tov'].toString() : '');
    int? selectedTankId = isEditing ? linea['tanque'] : null;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(isEditing ? 'Editar Línea' : 'Nueva Línea'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nombre de la Línea'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedTankId,
                      decoration: const InputDecoration(labelText: 'Tanque Asignado'),
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('Sin Tanque'),
                        ),
                        ..._tanks.map<DropdownMenuItem<int>>((tank) {
                          return DropdownMenuItem<int>(
                            value: tank['id'],
                            child: Text(tank['nombre']),
                          );
                        }),
                      ],
                      onChanged: (val) => setStateDialog(() => selectedTankId = val),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: tovController,
                      decoration: const InputDecoration(labelText: 'Volumen TOV', suffixText: 'bbl'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancelar")
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty || tovController.text.isEmpty) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor completa todos los campos')));
                       return;
                    }
                    
                    final data = {
                      'nombre': nameController.text,
                      'tanque': selectedTankId,
                      'volumen_tov': double.tryParse(tovController.text) ?? 0.0,
                    };

                    try {
                      if (isEditing) {
                        await _apiService.updateLinea(linea['id'], data);
                      } else {
                        await _apiService.createLinea(data);
                      }
                      if (mounted) {
                          Navigator.pop(ctx);
                          _fetchData();
                      }
                    } catch (e) {
                       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: Text(isEditing ? "Actualizar" : "Crear"),
                ),
              ],
            );
          }
        );
      }
    );
  }

  String _getTankName(int? tankId) {
    if (tankId == null) return 'Sin asignar';
    final tank = _tanks.firstWhere((t) => t['id'] == tankId, orElse: () => null);
    return tank != null ? tank['nombre'] : 'Desconocido';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Líneas de Planta'),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showLineDialog(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF27E26)))
          : _error != null
              ? Center(child: Text("Error: $_error", style: const TextStyle(color: Colors.red)))
              : _lineas.isEmpty
                  ? const Center(child: Text("No hay líneas registradas.", style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _lineas.length,
                      itemBuilder: (context, index) {
                        final linea = _lineas[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.white10,
                              child: Icon(Icons.linear_scale, color: Color(0xFFF27E26)),
                            ),
                            title: Text(
                              linea['nombre'] ?? 'Sin Nombre',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "Tanque: ${_getTankName(linea['tanque'])}\nTOV: ${NumberUtils.format(linea['volumen_tov'])} bbl",
                              style: const TextStyle(color: Colors.white70),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                  onPressed: () => _showLineDialog(linea: linea),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () => _deleteLinea(linea['id']),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
    );
  }
}
