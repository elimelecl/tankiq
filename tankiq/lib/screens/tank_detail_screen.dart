import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import 'package:intl/intl.dart';
import '../utils/formatters.dart';
import 'measurement_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'dart:convert';

class TankDetailScreen extends StatefulWidget {
  final Map<String, dynamic> tank;

  const TankDetailScreen({super.key, required this.tank});

  @override
  State<TankDetailScreen> createState() => _TankDetailScreenState();
}

class _TankDetailScreenState extends State<TankDetailScreen> {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _wsSubscription;

  late Map<String, dynamic> tank;
  List<dynamic> _history = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    tank = Map<String, dynamic>.from(widget.tank);
    _fetchHistory();
    _setupWebSocket();
  }

  void _setupWebSocket() {
    _wsService.connect();
    _wsSubscription = _wsService.stream.listen((message) {
      final model = message['model'];
      final id = message['id'];
      
      // If the tank itself updated
      if (model == 'Tanque' && id == tank['id']) {
        _refreshTankData();
      }
      // If a measurement for this tank was updated/added
      if (model == 'Medicion') {
        _fetchHistory(showLoading: false);
        // Also refresh tank data as it might change 'ultima_medicion'
        _refreshTankData();
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshTankData() async {
    try {
      final updated = await _apiService.getTanqueById(tank['id']);
      if (mounted) {
        setState(() {
          tank = updated;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing tank: $e');
    }
  }

  Future<void> _fetchHistory({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final dataResponse = await _apiService.getMediciones(tanqueId: tank['id']);
      final data = dataResponse['results'] as List<dynamic>;
      if (mounted) {
        setState(() {
          _history = data;
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
    // We use the 'tank' from state, which is reactive via WebSockets
    final lastMeasurement = tank['ultima_medicion'];
    final productName = lastMeasurement != null ? lastMeasurement['producto'] : (tank['producto_actual_nombre'] ?? 'Sin Producto');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(tank['nombre'] ?? 'Detalle del Tanque', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined, color: Color(0xFFF27E26)),
            tooltip: 'Subir Tabla de Aforo',
            onPressed: () => _showUploadTableDialog(context),
          ),
          const SizedBox(width: 8),
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
      body: RefreshIndicator(
        onRefresh: () async => _fetchHistory(),
        color: const Color(0xFFF27E26),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              _buildHeaderCard(tank, lastMeasurement, productName),
              const SizedBox(height: 24),
              
              const Text(
                "Historial de Mediciones",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // History List
              _buildHistoryList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Map<String, dynamic> tank, Map<String, dynamic>? last, String prodName) {
    final capacity = tank['capacidad_maxima'] is num ? (tank['capacidad_maxima'] as num).toDouble() : 0.0;
    final levelMm = last != null && last['nivel_mm'] is num ? (last['nivel_mm'] as num).toDouble() : 0.0;
    final volLitres = last != null ? last['volumen_litros'] : '---';
    final percentage = last != null && last['nivel_porcentaje'] is num ? (last['nivel_porcentaje'] as num).toDouble() : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prodName,
                    style: const TextStyle(
                      color: Color(0xFFF27E26),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tank['nombre'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              _buildPercentageIndicator(percentage),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               _buildDetailItem('Nivel Actual', '${NumberUtils.format(levelMm)} mm'),
               _buildDetailItem('Volumen', NumberUtils.format(volLitres)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               _buildDetailItem('Capacidad', '${NumberUtils.format(capacity)} L'),
               _buildDetailItem('Altura Ref.', '${NumberUtils.format(tank['altura_referencia'] ?? 0)} mm'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               _buildApiItem(tank),
               _buildDetailItem('Zona Crítica', '${NumberUtils.format(tank['zona_critica_L'] ?? 0)} mm'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApiItem(Map<String, dynamic> tank) {
    final api = tank['api_actual'] != null ? NumberUtils.format(tank['api_actual']) : '---';
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Densidad (API)',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Row(
            children: [
              Text(
                api,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 16, color: Color(0xFFF27E26)),
                onPressed: () => _showUpdateApiDialog(context, tank),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPercentageIndicator(double percentage) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.white10,
            color: percentage > 90 ? Colors.red : (percentage < 20 ? Colors.orange : Colors.green),
            strokeWidth: 6,
          ),
        ),
        Text(
          "${NumberUtils.format(percentage)}%",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildHistoryList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFF27E26)));
    }
    if (_error != null) {
      return Center(child: Text("Error: $_error", style: const TextStyle(color: Colors.red)));
    }
    if (_history.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text("No hay mediciones registradas.", style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        final type = item['tipo_medicion'] ?? 'N/A';
        final isVacio = type == 'VACIO';
        
        final dateStr = item['fecha_hora'];
        DateTime? date;
        if (dateStr != null) {
           date = DateTime.tryParse(dateStr);
        }
        final formattedDate = date != null ? DateFormat('dd MMM yyyy • HH:mm').format(date) : dateStr;

        return Card(
          color: const Color(0xFF1E293B),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
               Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => MeasurementDetailScreen(measurement: item)),
              );
            },
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: isVacio ? Colors.blue.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                child: Icon(
                  isVacio ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isVacio ? Colors.blue : Colors.green,
                  size: 20,
                ),
              ),
              title: Text(
                '#${item['id']} - $formattedDate',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Text("Inspector: ${item['inspector']}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      if (item['producto_nombre'] != null)
                        Text("Producto: ${item['producto_nombre']}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ]
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${NumberUtils.format(item['nivel_calculado_final'])} mm",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    isVacio ? "A Vacío" : "A Fondo",
                     style: TextStyle(color: isVacio ? Colors.blue[200] : Colors.green[200], fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showUpdateApiDialog(BuildContext context, Map<String, dynamic> tank) {
    final controller = TextEditingController(text: (tank['api_actual'] ?? '').toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Actualizar Densidad (API)', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Nueva Gravedad API',
            labelStyle: TextStyle(color: Colors.white70),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFF27E26))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF27E26)),
            onPressed: () async {
              try {
                final apiValue = double.parse(controller.text);
                await _apiService.updateTankApi(tank['id'], apiValue);
                Navigator.pop(context);
                setState(() {}); // Refresh
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Densidad actualizada correctamente')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showUploadTableDialog(BuildContext context) {
    final nameController = TextEditingController();
    final apiController = TextEditingController();
    final fraAdjController = TextEditingController(text: '0.0');
    final fraIncController = TextEditingController(text: '0.0');
    PlatformFile? selectedFile;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Subir Tabla de Aforo', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la Tabla *',
                    hintText: 'Este será el nombre con el que se reconocerá la tabla',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                TextField(
                  controller: apiController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Api de la Tabla *',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fraAdjController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Ajuste Fra *',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: fraIncController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Incremento Fra *',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Text('Archivo: *', style: TextStyle(color: Colors.white70)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          FilePickerResult? result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['xlsx'],
                            withData: true, 
                          );
                          if (result != null) {
                            setDialogState(() {
                              selectedFile = result.files.single;
                            });
                          }
                        },
                        icon: const Icon(Icons.file_present, size: 18),
                        label: Text(selectedFile == null ? 'Seleccionar archivo' : 'Listo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedFile != null ? Colors.green : Colors.white24,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                if (selectedFile != null)
                   Padding(
                     padding: const EdgeInsets.only(top: 4.0),
                     child: Text(
                       selectedFile!.name,
                       style: const TextStyle(color: Colors.white38, fontSize: 11),
                       textAlign: TextAlign.end,
                     ),
                   ),
              ],
            ),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final url = Uri.parse('https://docs.google.com/spreadsheets/d/1S6zRDRY98zIuRSTlW98M2X8Vl-aC6V9p_N-d9f7N3Ew/export?format=xlsx');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No se pudo abrir el enlace de la plantilla')),
                      );
                    }
                  },
                  icon: const Icon(Icons.download_for_offline_outlined, size: 18),
                  label: const Text('Descargar Plantilla', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                ),
                Row(
                   children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context), 
                        child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                      ),
                      StatefulBuilder(
                        builder: (context, setBtnState) {
                          bool isSaving = false;
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF27E26),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: isSaving ? null : () async {
                              if (selectedFile == null) {
                                 ScaffoldMessenger.of(context).showSnackBar(
                                   const SnackBar(content: Text('Por favor, selecciona un archivo primero.')),
                                 );
                                 return;
                              }
                              
                              setBtnState(() => isSaving = true);
                              try {
                                final nombreTabla = nameController.text.trim();
                                if (nombreTabla.isEmpty) {
                                   ScaffoldMessenger.of(context).showSnackBar(
                                     const SnackBar(content: Text('El nombre de la tabla es obligatorio.')),
                                   );
                                   setBtnState(() => isSaving = false);
                                   return;
                                }

                                final apiTabla = apiController.text;
                                final ajusteFra = fraAdjController.text;
                                final incrementoFra = fraIncController.text;
                                
                                List<int> bytes;
                                if (kIsWeb) {
                                  bytes = selectedFile!.bytes!;
                                } else {
                                  bytes = File(selectedFile!.path!).readAsBytesSync();
                                }
                                
                                var decoder = SpreadsheetDecoder.decodeBytes(bytes);
                                
                                Map<String, List<Map<String, dynamic>>> registros = {
                                  'cms': [],
                                  'ucms': [],
                                  'umms': [],
                                };
                                
                                for (var table in decoder.tables.keys) {
                                  var sheet = decoder.tables[table]!;
                                  Map<String, int> colMap = {};
                                  if (sheet.maxRows > 0) {
                                    var firstRow = sheet.rows[0];
                                    for (int i = 0; i < firstRow.length; i++) {
                                      var cellValue = firstRow[i];
                                      if (cellValue != null) colMap[cellValue.toString().trim()] = i;
                                    }
                                  }
                                  
                                  for (int i = 1; i < sheet.maxRows; i++) {
                                    var row = sheet.rows[i];
                                    registros['cms']!.add({
                                      'DecenasCm': row[colMap['DecenasCm']!],
                                      'CantidadCm': row[colMap['CantidadCm']!],
                                    });
                                    
                                    if ((i - 1) < 10) {
                                      registros['ucms']!.add({
                                        'UnidadCm': row[colMap['UnidadCm']!],
                                        'CantidadUcm': row[colMap['CantidadUcm']!],
                                      });
                                      registros['umms']!.add({
                                        'UnidadMm': row[colMap['UnidadMm']!],
                                        'CantidadMm': row[colMap['CantidadMm']!],
                                      });
                                    }
                                  }
                                }

                                final payload = {
                                  'registros': registros,
                                  'nombre_tabla': nombreTabla,
                                  'api_tabla': apiTabla,
                                  'ajuste_fra': ajusteFra,
                                  'incremento_fra': incrementoFra,
                                };

                                await _apiService.saveCalibrationTable(widget.tank['id'], payload);
                                
                                if (mounted) {
                                  Navigator.pop(context);
                                  _refreshTankData();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Tabla de aforo guardada exitosamente'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                debugPrint('Error en el guardado: $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error al guardar: $e')),
                                  );
                                }
                              } finally {
                                if (mounted) setBtnState(() => isSaving = false);
                              }
                            },
                            child: isSaving 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Guardar'),
                          );
                        }
                      ),
                   ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
