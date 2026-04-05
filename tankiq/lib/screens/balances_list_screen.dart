import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'balance_screen.dart';
import '../widgets/nav_drawer.dart';
import 'dart:async';
import 'dart:math';
import '../services/websocket_service.dart';
import '../utils/formatters.dart';
import '../utils/user_session.dart';

class BalancesListScreen extends StatefulWidget {
  const BalancesListScreen({super.key});

  @override
  State<BalancesListScreen> createState() => _BalancesListScreenState();
}

class _BalancesListScreenState extends State<BalancesListScreen> {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _wsSubscription;

  List<dynamic> _balances = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchBalances();
    _setupWebSocket();
  }

  void _setupWebSocket() {
    _wsService.connect();
    _wsSubscription = _wsService.stream.listen((message) {
      final model = message['model'];
      // Refresh if any relevant data changed
      if (model == 'BalanceDiario' || model == 'DetalleBalance' || model == 'Medicion') {
        _fetchBalances(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchBalances({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final data = await _apiService.getBalances();
      if (mounted) {
        setState(() {
          _balances = data;
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

  Future<void> _createNewBalance() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Seleccionar Fecha para el Balance',
    );

    if (picked != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(picked);
      try {
        final newBalance = await _apiService.createBalance(dateStr);
        if (mounted) {
          _fetchBalances();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BalanceScreen(balance: newBalance),
            ),
          ).then((_) => _fetchBalances());
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteWithMath(Map<String, dynamic> balance) async {
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
            const Text('Esta acción eliminará permanentemente el balance y todos sus registros.'),
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
                  const SnackBar(content: Text('Respuesta incorrecta. No se eliminó el balance.')),
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
        await _apiService.deleteBalance(balance['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Balance eliminado correctamente.')),
          );
          _fetchBalances();
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
        title: const Text('Historial de Balances'),
        actions: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ],
      ),
      drawer: const NavDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewBalance,
        label: const Text('Nuevo Balance'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFFF27E26),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
              : _balances.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay balances registrados.\nPulsa el botón para crear uno nuevo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _balances.length,
                      itemBuilder: (context, index) {
                        final b = _balances[index];
                        final bool isClosed = b['estado'] == 'CERRADO';
                        final String dateStr = b['fecha']; // API returns yyyy-MM-dd
                        final DateTime date = DateTime.parse(dateStr);
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: isClosed ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                              child: Icon(
                                isClosed ? Icons.check_circle : Icons.pending_actions,
                                color: isClosed ? Colors.green : Colors.orange,
                              ),
                            ),
                            title: Text(
                              DateFormat('EEEE, d MMMM yyyy').format(date),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Estado: ${b['estado_display']} • Total: ${NumberUtils.format(b['total_general'])} bbl',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (UserSession.isSuperUser)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    onPressed: () => _confirmDeleteWithMath(b),
                                    tooltip: 'Eliminar Balance',
                                  ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BalanceScreen(balance: b),
                                ),
                              ).then((_) => _fetchBalances());
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
