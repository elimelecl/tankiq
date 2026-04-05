import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/measurement_dialog.dart';
import '../widgets/calculate_measurement_dialog.dart';
import 'measurements_screen.dart';
import 'tanks_grid_screen.dart';
import '../widgets/tank_status_card.dart';
import 'measurement_detail_screen.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../utils/formatters.dart';
import 'balance_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _wsSubscription;

  List<dynamic> _tanks = [];
  List<dynamic> _measurements = [];
  List<dynamic> _filteredMeasurements = [];
  Map<String, dynamic>? _latestBalance;
  bool _isLoading = true;
  String? _error;

  // Filters
  int? _selectedTankId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _setupWebSocket();
  }

  void _setupWebSocket() {
    _wsService.connect();
    _wsSubscription = _wsService.stream.listen((message) {
      // Re-fetch all home data on any relevant update
      _fetchData(showLoading: false);
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchData({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final tanks = await _apiService.getTanques();
      final medsResponse = await _apiService.getMediciones();
      final meds = medsResponse['results'] as List<dynamic>;
      final balances = await _apiService.getBalances();
      
      if (mounted) {
        setState(() {
          _tanks = tanks;
          _measurements = meds;
          _latestBalance = balances.isNotEmpty ? balances.first : null;
          _isLoading = false;
          _applyFilters();
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

  void _applyFilters() {
    setState(() {
      _filteredMeasurements = _measurements.where((m) {
        // Tank filter
        if (_selectedTankId != null && m['tanque'] != _selectedTankId) {
          return false;
        }
        
        // Date filter
        final mDate = DateTime.tryParse(m['fecha_hora'] ?? '') ?? DateTime.now();
        if (_startDate != null) {
            final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
            if (mDate.isBefore(start)) return false;
        }
        if (_endDate != null) {
            final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
            if (mDate.isAfter(end)) return false;
        }
        
        return true;
      }).toList();
    });
  }

  Future<void> _showRegisterDialog(BuildContext context) async {
    final result = await showDialog(
      context: context,
      builder: (context) => const MeasurementDialog(),
    );
    if (result == true) {
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
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
          : _error != null
              ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 700;
                    
                    return SingleChildScrollView(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Buttons Row - Responsive
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children: [
                                    SizedBox(
                                      width: isDesktop ? 220 : (constraints.maxWidth - 48) / 2,
                                      child: OutlinedButton(
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => const CalculateMeasurementDialog(),
                                          );
                                        },
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Color(0xFFF27E26), width: 2),
                                          padding: const EdgeInsets.symmetric(vertical: 20),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: const Text('Calcular', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                      ),
                                    ),
                                    SizedBox(
                                      width: isDesktop ? 220 : (constraints.maxWidth - 48) / 2,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          _showRegisterDialog(context);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 20),
                                          backgroundColor: const Color(0xFFF27E26),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: const Text('Registrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),
                                // Update Section: Balance Summary
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Resumen Último Balance',
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        // Leads to all tanks or balances? 
                                        // User said to place summary here.
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const TanksGridScreen()),
                                        ).then((_) => _fetchData());
                                      },
                                      child: const Text('Ver Tanques', style: TextStyle(color: Color(0xFFF27E26))),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildBalanceSummary(),

                                const SizedBox(height: 42),

                                // MEASUREMENTS SECTION
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Mediciones',
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    if (_selectedTankId != null || _startDate != null || _endDate != null)
                                      TextButton(
                                        onPressed: () {
                                            setState(() {
                                                _selectedTankId = null;
                                                _startDate = null;
                                                _endDate = null;
                                            });
                                            _applyFilters();
                                        },
                                        child: const Text('Limpiar Filtros', style: TextStyle(color: Colors.redAccent)),
                                      ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const MeasurementsScreen()),
                                        ).then((_) => _fetchData());
                                      },
                                      child: const Text('Ver Historial', style: TextStyle(color: Color(0xFFF27E26))),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildFilterBar(),
                                const SizedBox(height: 16),
                                _filteredMeasurements.isEmpty
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(vertical: 40),
                                          child: Text('No hay mediciones con los filtros seleccionados', style: TextStyle(color: Colors.white54)),
                                        ),
                                      )
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: _filteredMeasurements.length,
                                        itemBuilder: (context, index) {
                                          final m = _filteredMeasurements[index];
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
                                                await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(builder: (context) => MeasurementDetailScreen(measurement: m)),
                                                );
                                                _fetchData();
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: ListTile(
                                                  leading: Container(
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF101524),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: const Icon(Icons.water_drop, color: Color(0xFFF27E26)),
                                                  ),
                                                  title: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text('$tankDisplay - ID: ${m['id']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                      const SizedBox(height: 6),
                                                      _buildEstadoBadge(m['estado'] ?? 'REGISTRADA'),
                                                    ],
                                                  ),
                                                  subtitle: Padding(
                                                    padding: const EdgeInsets.only(top: 4.0),
                                                    child: Text(
                                                        'Tipo: ${m['tipo_medicion']}\nInsp: ${m['inspector']} / Op: ${m['operador_nombre'] ?? 'N/A'}\nNivel: ${NumberUtils.format(m['nivel_calculado_final'])} mm',
                                                        style: const TextStyle(color: Colors.white60)),
                                                  ),
                                                  trailing: Text(formattedDate, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                                  isThreeLine: true,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                ),
    );
  }

  Widget _buildBalanceSummary() {
    if (_latestBalance == null) {
      return const Center(child: Text('No hay balances registrados', style: TextStyle(color: Colors.white54)));
    }

    final fecha = _latestBalance!['fecha'] ?? '';
    final estado = _latestBalance!['estado'] ?? '';
    final totalEntrada = _latestBalance!['total_entrada_nsv'] ?? 0.0;
    final totalSalida = _latestBalance!['total_salida_nsv'] ?? 0.0;
    final variacionTotal = _latestBalance!['variacion_total_nsv'] ?? 0.0;

    return Card(
      color: const Color(0xFF1C2438),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.assessment, color: Color(0xFFF27E26), size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Balance: $fecha', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Estado: $estado', style: TextStyle(color: estado == 'CERRADO' ? Colors.green : Colors.amber, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => BalanceScreen(balance: _latestBalance!)),
                    ).then((_) => _fetchData());
                  },
                  icon: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 18),
                  tooltip: 'Ver detalle de balance',
                ),
              ],
            ),
            const Divider(height: 32, color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBalanceStat('Entradas', NumberUtils.format(totalEntrada), Colors.green),
                _buildBalanceStat('Salidas', NumberUtils.format(totalSalida), Colors.redAccent),
                _buildBalanceStat('Variación', NumberUtils.format(variacionTotal), Colors.blueAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Column(
      children: [
        Row(
          children: [
            // Tank Dropdown
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2438),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedTankId,
                    hint: const Text('Todos los tanques', style: TextStyle(color: Colors.white54, fontSize: 14)),
                    dropdownColor: const Color(0xFF1C2438),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFF27E26)),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Todos los Tanques', style: TextStyle(color: Colors.white)),
                      ),
                      ..._tanks.map((t) => DropdownMenuItem<int>(
                        value: t['id'],
                        child: Text(t['nombre'] ?? 'Tanque', style: const TextStyle(color: Colors.white)),
                      )).toList(),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedTankId = val);
                      _applyFilters();
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Date Picker Button
            Expanded(
              child: InkWell(
                onTap: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                    initialDateRange: (_startDate != null && _endDate != null) 
                        ? DateTimeRange(start: _startDate!, end: _endDate!)
                        : null,
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Color(0xFFF27E26),
                            onPrimary: Colors.white,
                            surface: Color(0xFF1C2438),
                            onSurface: Colors.white,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (range != null) {
                    setState(() {
                      _startDate = range.start;
                      _endDate = range.end;
                    });
                    _applyFilters();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2438),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, color: Color(0xFFF27E26), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (_startDate != null && _endDate != null)
                              ? "${_startDate!.day}/${_startDate!.month} - ${_endDate!.day}/${_endDate!.month}"
                              : "Filtrar por fecha",
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
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

