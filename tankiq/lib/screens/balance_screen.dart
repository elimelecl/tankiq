import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../utils/formatters.dart';
import 'package:url_launcher/url_launcher.dart';

class BalanceScreen extends StatefulWidget {
  final Map<String, dynamic> balance;

  const BalanceScreen({super.key, required this.balance});

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _wsSubscription;
  
  List<dynamic> _detalles = [];
  List<dynamic> _lineasDisponibles = [];
  List<dynamic> _allTanks = [];
  List<dynamic> _allLines = [];
  Map<int, List<dynamic>> _medicionesPorTanque = {}; // tanqueId -> [mediciones]
  List<dynamic> _mediosTransporte = [];
  
  bool _isLoading = true;
  String? _error;
  late String _estado;
  late int _balanceId;

  @override
  void initState() {
    super.initState();
    _balanceId = widget.balance['id'];
    _estado = widget.balance['estado'];
    _fetchData();
    _setupWebSocket();
  }

  void _setupWebSocket() {
    _wsService.connect();
    _wsSubscription = _wsService.stream.listen((message) {
      final String model = message['model'];
      // Refresh if any relevant data for this screen changed
      if (model == 'Medicion' || model == 'Linea' || model == 'DetalleBalance' || 
          model == 'BalanceDiario' || model == 'Tanque' || model == 'MovimientoTransporte') {
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
      final dateStr = widget.balance['fecha'];
      
      final currentBalance = await _apiService.getBalanceById(_balanceId);
      final allDetalles = currentBalance['detalles'] as List<dynamic>;
      
      final allLines = await _apiService.getLineas();
      final allTanks = await _apiService.getTanques();
      
      List<int> assignedLineIds = [];
      for (var d in allDetalles) {
        final lineIds = (d['lineas'] as List<dynamic>).cast<int>();
        assignedLineIds.addAll(lineIds);
      }
      
      final available = allLines.where((l) => !assignedLineIds.contains(l['id'])).toList();

      Map<int, List<dynamic>> medsM = {};
      for (var d in allDetalles) {
        int tId = d['tanque'];
        final medsResponse = await _apiService.getMediciones(
          tanqueId: tId,
          // Removed startDate restriction to allow picking the latest reading
        );
        final meds = medsResponse['results'] as List<dynamic>;
        
        // Filter to only COMPLETED
        var filteredMeds = meds.where((m) => m['estado'] == 'COMPLETADA').toList();
        
        // Sort by date/time descending (most recent first)
        filteredMeds.sort((a, b) {
          final dateA = DateTime.tryParse(a['fecha_hora'] ?? '') ?? DateTime(2000);
          final dateB = DateTime.tryParse(b['fecha_hora'] ?? '') ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });

        // Limit to latest 5 but ALWAYS include the currently selected one if it exists
        final currentMedId = d['medicion'];
        List<dynamic> displayMeds = filteredMeds.take(5).toList();
        
        if (currentMedId != null && !displayMeds.any((m) => m['id'] == currentMedId)) {
          final activeMed = meds.firstWhere((m) => m['id'] == currentMedId, orElse: () => null);
          if (activeMed != null) {
            displayMeds.add(activeMed);
          }
        }
        
        medsM[tId] = displayMeds;
      }

      if (mounted) {
        setState(() {
          _detalles = allDetalles;
          _lineasDisponibles = available;
          _medicionesPorTanque = medsM;
        });
        
        final medios = await _apiService.getMediosTransporte();
        
        if (mounted) {
          setState(() {
            _mediosTransporte = medios;
            _allTanks = allTanks;
            _allLines = allLines;
            _estado = currentBalance['estado'];
            _isLoading = false;
          });
        }
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

  bool get _isClosed => _estado == 'CERRADO';

  double _getTankTotal(Map<String, dynamic> detalle) {
    return NumberUtils.toDouble(detalle['volumen_total']);
  }

  double _getGrandTotal() {
    double grand = 0.0;
    for (var d in _detalles) {
      grand += _getGrandTotalForTank(d);
    }
    return grand;
  }

  double _getPlantBalance() {
    double totalBalance = 0.0;
    for (var d in _detalles) {
      totalBalance += _getBalanceOperativo(d);
    }
    return totalBalance;
  }

  Future<void> _updateDetail(Map<String, dynamic> detalle, Map<String, dynamic> data) async {
    try {
      await _apiService.updateBalanceDetail(detalle['id'], data);
      _fetchData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));
    }
  }

  void _onLineDropped(dynamic linea, Map<String, dynamic> detalle) {
    if (_isClosed) return;
    
    final currentLineIds = (detalle['lineas'] as List<dynamic>).cast<int>().toList();
    if (!currentLineIds.contains(linea['id'])) {
      currentLineIds.add(linea['id']);
      double lineVol = NumberUtils.toDouble(linea['volumen_tov']);
      
      _updateDetail(detalle, {
        'lineas': currentLineIds,
        'volumen_total': NumberUtils.toDouble(detalle['volumen_total']) + lineVol,
      });
    }
  }

  void _onLineRemoved(int lineaId, double lineVol, Map<String, dynamic> detalle) {
    if (_isClosed) return;

    final currentLineIds = (detalle['lineas'] as List<dynamic>).cast<int>().toList();
    currentLineIds.remove(lineaId);
    
    _updateDetail(detalle, {
      'lineas': currentLineIds,
      'volumen_total': NumberUtils.toDouble(detalle['volumen_total']) - lineVol,
    });
  }

  Future<void> _editInitialVolume(Map<String, dynamic> detalle) async {
    if (_isClosed) return;
    
    final controller = TextEditingController(text: detalle['volumen_inicial'].toString());
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Volumen Inicial'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Volumen Inicial', suffixText: 'bbl'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text)),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result != null) {
      _updateDetail(detalle, {'volumen_inicial': result});
    }
  }

  Future<void> _addMovimientoTransporte(Map<String, dynamic> detalle) async {
    if (_isClosed) return;

    final medio = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Medio de Transporte'),
        content: SizedBox(
          width: double.maxFinite,
          child: _mediosTransporte.isEmpty 
              ? const Text('No hay medios de transporte configurados.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _mediosTransporte.length,
                  itemBuilder: (context, index) {
                    final m = _mediosTransporte[index];
                    return ListTile(
                      leading: Icon(_getIconData(m['icono']), color: const Color(0xFFF27E26)),
                      title: Text(m['nombre']),
                      onTap: () => Navigator.pop(ctx, m),
                    );
                  },
                ),
        ),
      ),
    );

    if (medio == null) return;

    final cantidadController = TextEditingController();
    final cantidad = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cantidad (${medio['nombre']})'),
        content: TextField(
          controller: cantidadController,
          decoration: const InputDecoration(labelText: 'Cantidad', suffixText: 'bbl'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(cantidadController.text)), 
            child: const Text('Añadir')
          ),
        ],
      ),
    );

    if (cantidad != null) {
      try {
        await _apiService.createMovimientoTransporte({
          'detalle_balance': detalle['id'],
          'medio_transporte': medio['id'],
          'cantidad': cantidad,
        });
        _fetchData();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteMovimientoTransporte(int id) async {
    if (_isClosed) return;
    try {
      await _apiService.deleteMovimientoTransporte(id);
      _fetchData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  IconData _getIconData(String? name) {
    const iconMap = {
      'local_shipping': Icons.local_shipping,
      'directions_boat': Icons.directions_boat,
      'train': Icons.train,
      'swap_horiz': Icons.swap_horiz,
      'inventory_2': Icons.inventory_2,
      'factory': Icons.factory,
      'account_balance': Icons.account_balance,
    };
    return iconMap[name] ?? Icons.category;
  }

  Future<void> _cerrarBalance() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Balance'),
        content: const Text('¿Estás seguro de cerrar el balance? Una vez cerrado no podrá ser modificado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Confirmar y Cerrar', style: TextStyle(fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.closeBalance(_balanceId);
        _fetchData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Balance cerrado exitosamente')));
      } catch (e) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _downloadPdf() async {
    const String baseUrl = ApiService.baseUrl;
    final Uri url = Uri.parse('$baseUrl/balances/$_balanceId/exportar-pdf/');
    
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Balance: ${widget.balance['fecha']}'),
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
          if (!_isClosed)
            ElevatedButton.icon(
              onPressed: _cerrarBalance,
              icon: const Icon(Icons.lock_outline, size: 18),
              label: const Text('Cerrar Balance'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          if (_estado == 'CERRADO')
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
              tooltip: 'Descargar Reporte PDF',
              onPressed: _downloadPdf,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchData(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isMobile = constraints.maxWidth < 900;
                    final int crossAxisCount = constraints.maxWidth < 750 ? 1 : (constraints.maxWidth < 1250 ? 2 : 3);
                    
                    return Column(
                      children: [
                        if (_isClosed)
                          Container(
                            width: double.infinity,
                            color: Colors.green.withValues(alpha: 0.2),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: const Center(
                              child: Text(
                                'ESTE BALANCE ESTÁ CERRADO Y ES DE SOLO LECTURA',
                                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ),
                        
                        Expanded(
                          child: isMobile 
                            ? Column(
                                children: [
                                  if (!_isClosed && _lineasDisponibles.isNotEmpty)
                                    _buildMobileLinesArea(),
                                  Expanded(child: _buildTanksGrid(crossAxisCount, constraints.maxWidth)),
                                ],
                              )
                            : Row(
                                children: [
                                  _buildDesktopLinesPanel(),
                                  Expanded(child: _buildTanksGrid(crossAxisCount, constraints.maxWidth)),
                                ],
                              ),
                        ),
                        
                        _buildBottomBar(isMobile),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _buildMobileLinesArea() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: const Color(0xFF0F172A),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _lineasDisponibles.length,
        itemBuilder: (context, index) {
          final linea = _lineasDisponibles[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildDraggableLine(linea, isSmall: true),
          );
        },
      ),
    );
  }

  Widget _buildDesktopLinesPanel() {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF0F172A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LÍNEAS DISPONIBLES',
            style: TextStyle(
              color: Color(0xFFF27E26),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
          Expanded(
            child: _isClosed 
              ? const Center(child: Text('Balance cerrado', style: TextStyle(color: Colors.white24)))
              : _lineasDisponibles.isEmpty
                ? const Center(
                    child: Text(
                      'No hay líneas libres',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    itemCount: _lineasDisponibles.length,
                    itemBuilder: (context, index) {
                      final linea = _lineasDisponibles[index];
                      return _buildDraggableLine(linea);
                    },
                  ),
          ),
          if (!_isClosed) ...[
            const SizedBox(height: 16),
            const Text(
              '💡 Arrastra las líneas a los tanques para sumarlas.',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildTanksGrid(int crossAxisCount, double maxWidth) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: crossAxisCount == 1 ? 0.95 : 1.3, // Slightly taller cards to prevent overflows
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _detalles.length,
        itemBuilder: (context, index) {
          final detalle = _detalles[index];
          return _buildTankTarget(detalle, maxWidth);
        },
      ),
    );
  }

  Widget _buildBottomBar(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics, color: Color(0xFFF27E26)),
          const SizedBox(width: 12),
          const Text(
            'TOTAL:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Text(
            '${NumberUtils.format(_getGrandTotal())} bbl',
            style: const TextStyle(
              color: Color(0xFFF27E26),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 24),
          const VerticalDivider(color: Colors.white24, width: 1, indent: 8, endIndent: 8),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('BALANCE PLANTA:', style: TextStyle(fontSize: 9, color: Colors.white54)),
              Text(
                '${NumberUtils.format(_getPlantBalance())} bbl',
                style: TextStyle(
                  color: _getPlantBalance().abs() < 10.0 ? Colors.greenAccent : (_getPlantBalance() > 0 ? Colors.blueAccent : Colors.redAccent),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (!isMobile)
            Text(
              'Estado: $_estado',
              style: TextStyle(
                color: _isClosed ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDraggableLine(dynamic linea, {bool isSmall = false}) {
    return Draggable<Map>(
      data: linea as Map,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: isSmall ? 150 : 250,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF27E26).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${linea['nombre']} (${linea['volumen_tov']} bbl)',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _buildLineTile(linea, isSmall: isSmall),
      ),
      child: _buildLineTile(linea, isSmall: isSmall),
    );
  }

  Widget _buildLineTile(dynamic linea, {bool isSmall = false}) {
    if (isSmall) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF27E26).withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.linear_scale, color: Color(0xFFF27E26), size: 14),
            const SizedBox(width: 6),
            Text(
              linea['nombre'],
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
            const SizedBox(width: 6),
            Text(
              '${linea['volumen_tov']}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF27E26)),
            ),
          ],
        ),
      );
    }

    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        horizontalTitleGap: 8,
        leading: const Icon(Icons.linear_scale, color: Color(0xFFF27E26), size: 18),
        title: Text(
          linea['nombre'],
          style: const TextStyle(fontSize: 13, color: Colors.white),
        ),
        trailing: Text(
          '${linea['volumen_tov']} bbl',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTankTarget(dynamic detalle, double maxWidth) {
    final int tId = detalle['tanque'];
    final List<int> assignedLineIds = (detalle['lineas'] as List<dynamic>).cast<int>();
    final tankMeds = _medicionesPorTanque[tId] ?? [];
    final int? selectedMedId = detalle['medicion'];
    final bool isNarrow = maxWidth < 500;
    
    return DragTarget<Map>(
      onWillAcceptWithDetails: (details) => !_isClosed,
      onAcceptWithDetails: (details) => _onLineDropped(details.data, detalle),
      builder: (context, candidateData, rejectedData) {
        bool isHovered = candidateData.isNotEmpty;
        
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C2438),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovered ? const Color(0xFFF27E26) : Colors.white10,
              width: isHovered ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _allTanks.firstWhere((t) => t['id'] == tId, orElse: () => {'nombre': 'Tanque $tId'})['nombre'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.propane_tank, color: Colors.white54, size: 18),
                      ],
                    ),
                  ),
                  
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: isNarrow 
                        ? Column(
                            children: [
                              _buildTankMeasurementSection(detalle, tankMeds, selectedMedId),
                              const Divider(color: Colors.white10, height: 20),
                              Expanded(child: _buildTankDataSection(detalle, assignedLineIds)),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(flex: 1, child: _buildTankMeasurementSection(detalle, tankMeds, selectedMedId)),
                              const VerticalDivider(color: Colors.white10, width: 24),
                              Expanded(flex: 1, child: _buildTankDataSection(detalle, assignedLineIds)),
                            ],
                          ),
                    ),
                  ),
                ],
              ),
              if (!_isClosed)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: FloatingActionButton.small(
                    onPressed: () => _addMovimientoTransporte(detalle),
                    backgroundColor: const Color(0xFFF27E26),
                    elevation: 2,
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  double _getGrandTotalForTank(dynamic detalle) {
    return NumberUtils.toDouble(detalle['volumen_total']);
  }

  double _getVariacion(dynamic detalle) {
    double finalVol = _getGrandTotalForTank(detalle);
    double initialVol = NumberUtils.toDouble(detalle['volumen_inicial']);
    return finalVol - initialVol;
  }

  double _getSumaTransporte(dynamic detalle) {
    double total = 0.0;
    final transportes = detalle['transportes'] as List<dynamic>? ?? [];
    for (var m in transportes) {
      total += NumberUtils.toDouble(m['cantidad']);
    }
    return total;
  }

  double _getBalanceOperativo(dynamic detalle) {
    return _getVariacion(detalle) - _getSumaTransporte(detalle);
  }

  Widget _buildTankMeasurementSection(dynamic detalle, List<dynamic> tankMeds, int? selectedMedId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('VOLUMEN INICIAL', style: TextStyle(fontSize: 10, color: Colors.white54)),
            const SizedBox(width: 4),
            if (!_isClosed)
              InkWell(
                onTap: () => _editInitialVolume(detalle),
                child: const Icon(Icons.edit, size: 10, color: Colors.white38),
              ),
          ],
        ),
        Text(
          '${NumberUtils.format(detalle['volumen_inicial'])} bbl',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueAccent),
        ),
        const SizedBox(height: 8),
        const Text('MEDICIÓN FINAL', style: TextStyle(fontSize: 10, color: Colors.white54)),
        const SizedBox(height: 4),
        DropdownButton<int?>(
          isExpanded: true,
          value: selectedMedId,
          hint: const Text('Sin medición', style: TextStyle(fontSize: 11)),
          dropdownColor: const Color(0xFF1C2438),
          underline: Container(height: 1, color: Colors.white24),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Ninguna', style: TextStyle(fontSize: 11))),
            ...tankMeds.map((m) {
              DateTime? date;
              if (m['fecha_hora'] != null) {
                date = DateTime.tryParse(m['fecha_hora']);
              }
              final dateStr = date != null 
                  ? DateFormat('dd/MM HH:mm').format(date) 
                  : (m['fecha_hora_display'] ?? 'Sin fecha');
              final display = 'ID ${m['id']} - $dateStr';
                  
              return DropdownMenuItem<int?>(
                value: m['id'],
                child: Text(display, style: const TextStyle(fontSize: 11)),
              );
            }),
            if (selectedMedId != null && !tankMeds.any((m) => m['id'] == selectedMedId))
              DropdownMenuItem<int?>(
                value: selectedMedId,
                child: const Text('ID no encontrado', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
              ),
          ],
          onChanged: _isClosed ? null : (val) {
            final selectedMed = tankMeds.firstWhere((m) => m['id'] == val, orElse: () => null);
            double newTankVol = (selectedMed != null) ? NumberUtils.toDouble(selectedMed['volumen_calculado']) : 0.0;
            double currentLineVol = NumberUtils.toDouble(detalle['volumen_total']) - NumberUtils.toDouble(detalle['volumen_tanque']);
            _updateDetail(detalle, {
              'medicion': val,
              'volumen_tanque': newTankVol,
              'volumen_total': newTankVol + currentLineVol,
            });
          },
        ),
        const SizedBox(height: 8),
        const Text('VOL. FINAL (TANQUE+L)', style: TextStyle(fontSize: 10, color: Colors.white54)),
        Text(
          '${NumberUtils.format(detalle['volumen_total'])} bbl',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        _buildOperativeBalanceBox(detalle),
      ],
    );
  }

  Widget _buildOperativeBalanceBox(dynamic detalle) {
    final variacion = _getVariacion(detalle);
    final transporte = _getSumaTransporte(detalle);
    final balance = _getBalanceOperativo(detalle);
    
    // Determine color based on balance (perfect is 0)
    Color balanceColor = Colors.orangeAccent;
    if (balance.abs() < 1.0) {
      balanceColor = Colors.greenAccent;
    } else if (balance > 0) {
      balanceColor = Colors.blueAccent; // Gain
    } else {
      balanceColor = Colors.redAccent; // Loss
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: balanceColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: balanceColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('VARIACIÓN:', style: TextStyle(fontSize: 9, color: Colors.white54)),
              Text(NumberUtils.format(variacion), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TRANSPORTE:', style: TextStyle(fontSize: 9, color: Colors.white54)),
              Text(NumberUtils.format(transporte), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 8, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('DIFERENCIA:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: balanceColor)),
              Text(
                '${NumberUtils.format(balance)} bbl',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: balanceColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTankDataSection(dynamic detalle, List<int> assignedLineIds) {
    return Column(
      children: [
        Expanded(flex: 3, child: _buildTankLinesSection(detalle, assignedLineIds)),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Divider(color: Colors.white10, height: 1),
        ),
        Expanded(flex: 2, child: _buildTankTransportSection(detalle)),
      ],
    );
  }

  Widget _buildTankTransportSection(dynamic detalle) {
    final transportes = detalle['transportes'] as List<dynamic>? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('TRANSPORTE', style: TextStyle(fontSize: 10, color: Colors.white54)),
        const SizedBox(height: 4),
        Expanded(
          child: transportes.isEmpty
            ? const Center(child: Text('Sin movimientos', style: TextStyle(color: Colors.white24, fontSize: 10)))
            : ListView.builder(
                itemCount: transportes.length,
                itemBuilder: (context, index) {
                  final m = transportes[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(_getIconData(m['medio_transporte_icono']), size: 12, color: const Color(0xFFF27E26)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            m['medio_transporte_nombre'],
                            style: const TextStyle(fontSize: 9, color: Colors.white70),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${NumberUtils.format(m['cantidad'])}',
                          style: TextStyle(
                            fontSize: 9, 
                            fontWeight: FontWeight.bold,
                            color: NumberUtils.toDouble(m['cantidad']) < 0 ? Colors.redAccent : Colors.greenAccent
                          ),
                        ),
                        if (!_isClosed)
                          InkWell(
                            onTap: () => _deleteMovimientoTransporte(m['id']),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.close, size: 12, color: Colors.white24),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildTankLinesSection(dynamic detalle, List<int> assignedLineIds) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('LÍNEAS', style: TextStyle(fontSize: 10, color: Colors.white54)),
        const SizedBox(height: 8),
        Expanded(
          child: assignedLineIds.isEmpty
            ? const Center(child: Text('Sin líneas', style: TextStyle(color: Colors.white24, fontSize: 10)))
            : ListView.builder(
                itemCount: assignedLineIds.length,
                itemBuilder: (context, index) {
                  final lineId = assignedLineIds[index];
                  final line = _allLines.firstWhere(
                    (l) => l['id'] == lineId, 
                    orElse: () => {'nombre': 'Línea $lineId', 'volumen_tov': 0.0}
                  );
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.link, size: 14, color: Colors.white54),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line['nombre'],
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${NumberUtils.format(line['volumen_tov'])} bbl',
                                style: const TextStyle(fontSize: 9, color: Colors.white60),
                              ),
                            ],
                          ),
                        ),
                        if (!_isClosed)
                          InkWell(
                            onTap: () => _onLineRemoved(lineId, NumberUtils.toDouble(line['volumen_tov']), detalle),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 8, right: 4),
                              child: Icon(Icons.close, size: 14, color: Colors.redAccent),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }
}
