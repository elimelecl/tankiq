import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/complete_measurement_dialog.dart';
import '../widgets/measurement_dialog.dart';
import 'dart:math' as math;
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../utils/formatters.dart';
import 'package:url_launcher/url_launcher.dart';

class MeasurementDetailScreen extends StatefulWidget {
  final Map<String, dynamic> measurement;

  const MeasurementDetailScreen({super.key, required this.measurement});

  @override
  State<MeasurementDetailScreen> createState() => _MeasurementDetailScreenState();
}

class _MeasurementDetailScreenState extends State<MeasurementDetailScreen> {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _wsSubscription;
  late Map<String, dynamic> measurement;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    measurement = Map<String, dynamic>.from(widget.measurement);
    _setupWebSocket();
  }

  void _setupWebSocket() {
    _wsService.connect();
    _wsSubscription = _wsService.stream.listen((message) {
      if (message['model'] == 'Medicion' && message['id'] == measurement['id']) {
        _refreshData();
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshData() async {
    try {
      final updated = await _apiService.getMedicionById(measurement['id']);
      if (mounted) {
        setState(() {
          measurement = updated;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing measurement: $e');
    }
  }

  Future<void> _openCompleteDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => CompleteMeasurementDialog(measurement: measurement),
    );
    if (result == true && mounted) {
      _refreshData();
    }
  }

  Future<void> _editMeasurement() async {
    if (measurement['is_in_balance'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede editar una medición que ya hace parte de un balance.')),
      );
      return;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => MeasurementDialog(initialData: measurement),
    );
    if (result == true && mounted) {
      _refreshData();
    }
  }

  Future<void> _deleteMeasurement() async {
    if (measurement['is_in_balance'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede eliminar una medición que ya hace parte de un balance.')),
      );
      return;
    }
    // Math challenge simulation
    final int a = math.Random().nextInt(10) + 1;
    final int b = math.Random().nextInt(10) + 1;
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
            const Text('Esta acción deshabilitará permanentemente esta medición.'),
            const SizedBox(height: 16),
            Text(
              'Para confirmar, resuelve: ¿Cuánto es $a + $b?',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF27E26)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Tu respuesta',
                border: OutlineInputBorder(),
              ),
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
                  const SnackBar(content: Text('Respuesta incorrecta.')),
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
          Navigator.pop(context, true); // Return to list
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

  Future<void> _exportPdf() async {
    final url = Uri.parse('${ApiService.baseUrl}/mediciones/${measurement['id']}/exportar-pdf/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace para descargar el PDF.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Parse Dates
    final dateStr = measurement['fecha_hora'];
    DateTime? date;
    if (dateStr != null) date = DateTime.tryParse(dateStr);
    final formattedDate = date != null 
        ? DateFormat('dd MMM yyyy • HH:mm').format(date) 
        : (dateStr ?? 'N/A');

    // Safe casting helper
    String safeNum(dynamic val, [String suffix = '', int decimals = 2]) {
      if (val == null) return '---';
      return '${NumberUtils.format(val, decimalDigits: decimals)} $suffix';
    }

    final isVacio = measurement['tipo_medicion'] == 'VACIO';
    final primaryColor = isVacio ? Colors.blue : Colors.green;
    final estado = measurement['estado'] ?? 'REGISTRADA';
    final isRegistrada = estado == 'REGISTRADA';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Detalle de Medición', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              ),
              SizedBox(width: 4),
              Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
              SizedBox(width: 8),
            ],
          ),
          IconButton(
            icon: Icon(
              Icons.edit, 
              color: measurement['is_in_balance'] == true ? Colors.white24 : Colors.white70
            ),
            onPressed: measurement['is_in_balance'] == true ? null : _editMeasurement,
            tooltip: measurement['is_in_balance'] == true 
                ? 'Bloqueado (Parte de un balance)' 
                : 'Editar Medición',
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline, 
              color: measurement['is_in_balance'] == true ? Colors.white24 : Colors.redAccent
            ),
            onPressed: measurement['is_in_balance'] == true ? null : _deleteMeasurement,
            tooltip: measurement['is_in_balance'] == true 
                ? 'Bloqueado (Parte de un balance)' 
                : 'Eliminar Medición',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Color(0xFFF27E26)),
            onPressed: _exportPdf,
            tooltip: 'Exportar PDF',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Row(
                               children: [
                                 Text(
                                   measurement['tanque_nombre'] ?? 'Tanque ID: ${measurement['tanque']}',
                                   style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                 ),
                                 const SizedBox(width: 8),
                                 Text(
                                   '#${measurement['id']}',
                                   style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14, fontWeight: FontWeight.normal),
                                 ),
                               ],
                             ),
                             const SizedBox(height: 4),
                             Text(measurement['producto_nombre'] ?? 'Producto Desconocido', 
                               style: const TextStyle(color: Color(0xFFF27E26), fontWeight: FontWeight.bold)
                             ),
                           ],
                         ),
                       ),
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.end,
                         children: [
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                             decoration: BoxDecoration(
                               color: primaryColor.withValues(alpha: 0.2),
                               borderRadius: BorderRadius.circular(20),
                               border: Border.all(color: primaryColor),
                             ),
                             child: Text(
                               isVacio ? "VACÍO" : "FONDO",
                               style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                             ),
                           ),
                           const SizedBox(height: 6),
                           // Estado badge
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                             decoration: BoxDecoration(
                               color: isRegistrada
                                   ? Colors.amber.withValues(alpha: 0.15)
                                   : const Color(0xFF22C55E).withValues(alpha: 0.15),
                               borderRadius: BorderRadius.circular(20),
                               border: Border.all(
                                 color: isRegistrada ? Colors.amber : const Color(0xFF22C55E),
                               ),
                             ),
                             child: Row(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 Icon(
                                   isRegistrada ? Icons.pending : Icons.check_circle,
                                   size: 14,
                                   color: isRegistrada ? Colors.amber : const Color(0xFF22C55E),
                                 ),
                                 const SizedBox(width: 4),
                                 Text(
                                   measurement['estado_display'] ?? estado,
                                   style: TextStyle(
                                     color: isRegistrada ? Colors.amber : const Color(0xFF22C55E),
                                     fontWeight: FontWeight.w600,
                                     fontSize: 11,
                                   ),
                                 ),
                               ],
                             ),
                           ),
                         ],
                       ),
                     ],
                   ),
                   const SizedBox(height: 20),
                   const Divider(color: Colors.white10),
                   const SizedBox(height: 20),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       _buildInfoCol("Nivel Final", safeNum(measurement['nivel_calculado_final'], 'mm')),
                       _buildInfoCol("Volumen", safeNum(measurement['volumen_calculado'], '')),
                       _buildInfoCol("Temp. Amb.", safeNum(measurement['temperatura_ambiente'], '°F')),
                     ],
                   )
                ],
              ),
            ),

            // ─── Completar Button (only if REGISTRADA) ───
            if (isRegistrada) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _openCompleteDialog,
                  icon: const Icon(Icons.add_task, size: 22),
                  label: const Text(
                    'Completar Medición (API / GSW)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],

            // ─── API / GSW / Volume Section (only when COMPLETADA) ───
            if (!isRegistrada && (measurement['api'] != null || measurement['gsw'] != null)) ...[
              const SizedBox(height: 24),
              const Text("Resumen de Liquidación", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('API Observada', '${NumberUtils.format(measurement['api'], decimalDigits: 1)} °API'),
                    _buildDetailRow('API @ 60°F', '${NumberUtils.format(measurement['api_60'], decimalDigits: 1)} °API'),
                    const Divider(color: Colors.white10),
                    _buildDetailRow('S&W (GSW)', '${NumberUtils.format(measurement['gsw'], decimalDigits: 3)} %'),
                    const Divider(color: Colors.white10, height: 24),
                    
                    _buildDetailRow('TOV (Tablas)', NumberUtils.format(measurement['tov'])),
                    _buildDetailRow('Factor CTSH', NumberUtils.format(measurement['ctsh_factor'], decimalDigits: 5)),
                    _buildDetailRow('Ajuste FRA', NumberUtils.format(measurement['fra_valor'])),
                    const Divider(color: Colors.white10),
                    
                    _buildDetailRow('GOV', NumberUtils.format(measurement['gov']), highlight: true),
                    _buildDetailRow('Factor CTL', NumberUtils.format(measurement['ctl_factor'], decimalDigits: 5)),
                    const Divider(color: Colors.white10),
                    
                    _buildDetailRow('GSV', NumberUtils.format(measurement['gsv']), highlight: true),
                    const Divider(color: Colors.white10),
                    
                    _buildDetailRow(
                      'NSV (Neto)',
                      NumberUtils.format(measurement['nsv']),
                      highlight: true,
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            const Text("Detalles de Medición", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            
            // Grid of details
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildGridItem(Icons.calendar_today, "Fecha", formattedDate),
                _buildGridItem(Icons.label_important_outline, "Motivo", measurement['motivo'] ?? 'MOVIMIENTO'),
                _buildGridItem(Icons.person, "Inspector", measurement['inspector'] ?? '---'),
                _buildGridItem(Icons.engineering, "Operador", measurement['operador_nombre'] ?? '---'),
                _buildGridItem(Icons.straighten, isVacio ? "Medida Cinta" : "Medida Nivel", safeNum(measurement['lectura_1_cinta_o_nivel'], 'mm')),
                if (isVacio) _buildGridItem(Icons.vertical_align_bottom, "Plomada 1", safeNum(measurement['lectura_1_plomada'], 'mm')),
                _buildGridItem(Icons.thermostat, "Temp. Líq. Superior", safeNum(measurement['temp_liquido_superior'], '°F')),
              ],
            ),
             const SizedBox(height: 24),
            
            // Raw Readings Expansion
            ExpansionTile(
              title: const Text("Lecturas Brutas", style: TextStyle(color: Colors.white70)),
              collapsedIconColor: Colors.white70,
              iconColor: Colors.white,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black12,
                  child: Column(
                    children: [
                      _buildRowItem("Lectura 1", safeNum(measurement['lectura_1_cinta_o_nivel'])),
                      _buildRowItem("Lectura 2", safeNum(measurement['lectura_2_cinta_o_nivel'])),
                      if (measurement['lectura_3_cinta_o_nivel'] != null)
                        _buildRowItem("Lectura 3", safeNum(measurement['lectura_3_cinta_o_nivel'])),
                      const Divider(color: Colors.white10),
                       if (isVacio) ...[
                        _buildRowItem("Plomada 1", safeNum(measurement['lectura_1_plomada'])),
                        _buildRowItem("Plomada 2", safeNum(measurement['lectura_2_plomada'])),
                       ],
                       const Divider(color: Colors.white10),
                       _buildRowItem("Nivel Automático", safeNum(measurement['nivel_automatico'])),
                       _buildRowItem("Temp. Automática", safeNum(measurement['temperatura_automatica'])),
                    ],
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildInfoCol(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildGridItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFF27E26), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                 Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRowItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60)),
          Text(value, style: const TextStyle(color: Colors.white, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color: highlight ? const Color(0xFF22C55E) : Colors.white,
              fontSize: highlight ? 16 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
