import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/nav_drawer.dart';
import '../utils/formatters.dart';
import 'measurement_detail_screen.dart';
import '../widgets/measurement_dialog.dart';
import '../utils/user_session.dart';

class MeasurementsScreen extends StatefulWidget {
  const MeasurementsScreen({super.key});

  @override
  State<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends State<MeasurementsScreen> {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _wsSubscription;
  
  List<dynamic> _mediciones = [];
  List<dynamic> _tanks = [];
  bool _isLoading = true;
  
  // Pagination
  final ScrollController _scrollController = ScrollController();
  String? _nextPageUrl;
  bool _isFetchingMore = false;
  
  // Filters
  int? _selectedTankId;
  final TextEditingController _inspectorController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupWebSocket();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isFetchingMore && _nextPageUrl != null) {
        _loadNextPage();
      }
    }
  }

  void _setupWebSocket() {
    _wsService.connect();
    _wsSubscription = _wsService.stream.listen((message) {
      final model = message['model'];
      if (model == 'Medicion' || model == 'Tanque') {
        _applyFilters(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      // Load tanks for filter dropdown
      final tanks = await _apiService.getTanques();
      // Load all measurements initially (first page)
      final response = await _apiService.getMediciones();
      
      if (mounted) {
        setState(() {
          _tanks = tanks;
          _mediciones = response['results'] as List<dynamic>;
          _nextPageUrl = response['next'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _applyFilters({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      String? dateString;
      if (_selectedDate != null) {
        dateString = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      }

      final response = await _apiService.getMediciones(
        tanqueId: _selectedTankId,
        inspector: _inspectorController.text.isEmpty ? null : _inspectorController.text,
        startDate: dateString,
      );
      if (mounted) {
        setState(() {
          _mediciones = response['results'] as List<dynamic>;
          _nextPageUrl = response['next'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadNextPage() async {
    if (_nextPageUrl == null || _isFetchingMore) return;
    
    setState(() => _isFetchingMore = true);
    try {
      final response = await _apiService.getMediciones(url: _nextPageUrl);
      if (mounted) {
        setState(() {
          _mediciones.addAll(response['results'] as List<dynamic>);
          _nextPageUrl = response['next'];
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingMore = false);
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedTankId = null;
      _inspectorController.clear();
      _selectedDate = null;
    });
    _applyFilters();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Seleccionar Fecha de Medición',
      cancelText: 'Cancelar',
      confirmText: 'Seleccionar',
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF27E26),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF0F172A),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _confirmDeleteWithMath(Map<String, dynamic> measurement) async {
    final Random random = Random();
    final int a = random.nextInt(10) + 1;
    final int b = random.nextInt(10) + 1;
    final int expectedResult = a + b;
    
    final TextEditingController controller = TextEditingController();
    
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Confirmar Eliminación'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Esta acción deshabilitará permanentemente esta medición y no se mostrará en los reportes.'),
            const SizedBox(height: 16),
            Text(
              'Para confirmar, resuelve: ¿Cuánto es $a + $b?',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF27E26)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Tu respuesta',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              if (int.tryParse(controller.text) == expectedResult) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Respuesta incorrecta. No se eliminó la medición.')),
                );
                Navigator.pop(context, false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteMedicion(measurement['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Medición eliminada correctamente.')),
          );
          _loadInitialData(); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mediciones'),
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
      body: Column(
        children: [
          // Filter Section
          ExpansionTile(
            title: const Text('Filtros', style: TextStyle(color: Color(0xFFF27E26), fontWeight: FontWeight.bold)),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    bool isWide = constraints.maxWidth > 600;
                    return Column(
                      children: [
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildTankDropdown()),
                              const SizedBox(width: 16),
                              Expanded(child: _buildInspectorInput()),
                            ],
                          )
                        else ...[
                          _buildTankDropdown(),
                          const SizedBox(height: 12),
                          _buildInspectorInput(),
                        ],
                        const SizedBox(height: 12),
                        // Date Picker Field
                        InkWell(
                          onTap: _selectDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month, color: Color(0xFFF27E26), size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  _selectedDate == null 
                                    ? 'Seleccionar Fecha' 
                                    : 'Fecha: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}',
                                  style: TextStyle(
                                    color: _selectedDate == null ? Colors.white54 : Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                const Spacer(),
                                if (_selectedDate != null)
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18, color: Colors.white54),
                                    onPressed: () {
                                      setState(() => _selectedDate = null);
                                    },
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _clearFilters,
                                child: const Text('Limpiar'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _applyFilters,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF27E26),
                                ),
                                child: const Text('Aplicar Filtros'),
                              ),
                            ),
                          ],
                        )
                      ],
                    );
                  }
                ),
              ),
            ],
          ),
          
          // List Section
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFF27E26)))
              : _mediciones.isEmpty
                  ? const Center(child: Text('No se encontraron mediciones.', style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _mediciones.length + (_nextPageUrl != null ? 1 : 0),
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        if (index == _mediciones.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: CircularProgressIndicator(color: Color(0xFFF27E26)),
                            ),
                          );
                        }

                        final m = _mediciones[index];
                        final date = DateTime.tryParse(m['fecha_hora'] ?? '') ?? DateTime.now();
                        final formattedDate = "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
                        final tankDisplay = m['tanque_nombre'] ?? 'Tanque ID: ${m['tanque']}'; 

                        return Card(
                          color: const Color(0xFF1C2438),
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final result = await Navigator.push<bool>(
                                context, 
                                MaterialPageRoute(builder: (context) => MeasurementDetailScreen(measurement: m)),
                              );
                              if (result == true) _loadInitialData();
                            },
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF101524),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.analytics, color: Color(0xFFF27E26)),
                              ),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${tankDisplay} - ID: ${m['id']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  _buildEstadoBadge(m['estado'] ?? 'REGISTRADA'),
                                ],
                              ),
                              subtitle: Text(
                                '${m['tipo_medicion']} - Insp: ${m['inspector']}\nOperador: ${m['operador_nombre'] ?? 'N/A'}\nNivel: ${NumberUtils.format(m['nivel_calculado_final'])} mm',
                                style: const TextStyle(color: Colors.white60),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(formattedDate, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                      if (UserSession.isSuperUser)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                          onPressed: () => _confirmDeleteWithMath(m),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.only(top: 4),
                                          tooltip: 'Deshabilitar Medición',
                                        ),
                                    ],
                                  ),
                                  const Icon(Icons.chevron_right, color: Colors.white24),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showDialog(
            context: context,
            builder: (context) => const MeasurementDialog(),
          );
          if (result == true) {
            _applyFilters();
          }
        },
        backgroundColor: const Color(0xFFF27E26),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
  Widget _buildTankDropdown() {
    return DropdownButtonFormField<int>(
      value: _selectedTankId,
      decoration: const InputDecoration(
        labelText: 'Filtrar por Tanque',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.propane_tank, color: Colors.grey),
      ),
      dropdownColor: const Color(0xFF1C2438),
      items: _tanks.map<DropdownMenuItem<int>>((tank) {
        return DropdownMenuItem<int>(
          value: tank['id'],
          child: Text(tank['nombre'] ?? 'Sin Nombre', style: const TextStyle(color: Colors.white)),
        );
      }).toList(),
      onChanged: (val) {
        setState(() => _selectedTankId = val);
      },
    );
  }

  Widget _buildInspectorInput() {
    return TextField(
      controller: _inspectorController,
      decoration: const InputDecoration(
        labelText: 'Buscar por Inspector',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.person_search, color: Colors.grey),
      ),
    );
  }

  Widget _buildEstadoBadge(String estado) {
    final isRegistrada = estado == 'REGISTRADA';
    final color = isRegistrada ? Colors.amber : const Color(0xFF22C55E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRegistrada ? Icons.pending : Icons.check_circle,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            isRegistrada ? 'Registrada' : 'Completada',
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
