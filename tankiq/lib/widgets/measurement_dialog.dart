import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MeasurementDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const MeasurementDialog({super.key, this.initialData});

  @override
  State<MeasurementDialog> createState() => _MeasurementDialogState();
}



class _MeasurementDialogState extends State<MeasurementDialog> {
  int _step = 0; // 0: Tank, 1: Type, 2: Form
  Map<String, dynamic>? _selectedTank; // Changed to Store Map
  String? _measurementType; // 'VACIO' or 'FONDO'
  List<dynamic> _tanks = [];
  bool _isLoadingTanks = true;
  String? _tankError;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _step = 2;
      _measurementType = widget.initialData!['tipo_medicion'];
      _selectedTank = {
        'id': widget.initialData!['tanque'],
        'nombre': widget.initialData!['tanque_nombre'],
      };
      
      // Initialize controllers with initial data
      _readingsControllers[0].text = (widget.initialData!['lectura_1_cinta_o_nivel'] ?? '').toString();
      _readingsControllers[1].text = (widget.initialData!['lectura_2_cinta_o_nivel'] ?? '').toString();
      _readingsControllers[2].text = (widget.initialData!['lectura_3_cinta_o_nivel'] ?? '').toString();
      
      _plomadaControllers[0].text = (widget.initialData!['lectura_1_plomada'] ?? '').toString();
      _plomadaControllers[1].text = (widget.initialData!['lectura_2_plomada'] ?? '').toString();
      _plomadaControllers[2].text = (widget.initialData!['lectura_3_plomada'] ?? '').toString();
      
      _tempAmbController.text = (widget.initialData!['temperatura_ambiente'] ?? '').toString();
      _tempLiqTopController.text = (widget.initialData!['temp_liquido_superior'] ?? '').toString();
      _tempLiqMidController.text = (widget.initialData!['temp_liquido_media'] ?? '').toString();
      _tempLiqBotController.text = (widget.initialData!['temp_liquido_inferior'] ?? '').toString();
      
      _autoLevelController.text = (widget.initialData!['nivel_automatico'] ?? '').toString();
      _autoTempController.text = (widget.initialData!['temperatura_automatica'] ?? '').toString();
      _inspectorController.text = (widget.initialData!['inspector'] ?? '').toString();
      
      if (_readingsControllers[2].text.isNotEmpty) {
        _showThirdReading = true;
      }
    } else {
      _fetchTanks();
    }
  }

  Future<void> _fetchTanks() async {
    try {
      final tanks = await ApiService().getTanques();
      if (mounted) {
        setState(() {
          _tanks = tanks;
          _isLoadingTanks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _tankError = e.toString();
          _isLoadingTanks = false;
        });
      }
    }
  }

  // Form Controllers
  final _formKey = GlobalKey<FormState>();

  // Use lists to manage dynamic sets of controllers
  // 0: Reading 1, 1: Reading 2, 2: Reading 3 (optional)
  final List<TextEditingController> _readingsControllers = 
      List.generate(3, (_) => TextEditingController());
  
  // Plomada (only for Vacio)
  final List<TextEditingController> _plomadaControllers = 
      List.generate(3, (_) => TextEditingController());

  // Temperatures
  final _tempAmbController = TextEditingController();
  final _tempLiqTopController = TextEditingController();
  final _tempLiqMidController = TextEditingController();
  final _tempLiqBotController = TextEditingController();

  final _autoLevelController = TextEditingController();
  final _autoTempController = TextEditingController();
  final _inspectorController = TextEditingController();

  bool _showThirdReading = false;

  @override
  void dispose() {
    for (var c in _readingsControllers) c.dispose();
    for (var c in _plomadaControllers) c.dispose();
    _tempAmbController.dispose();
    _tempLiqTopController.dispose();
    _tempLiqMidController.dispose();
    _tempLiqBotController.dispose();
    _autoLevelController.dispose();
    _autoTempController.dispose();
    _inspectorController.dispose();
    super.dispose();
  }

  void _checkThirdReadingNeeded() {
    if (_readingsControllers[0].text.isNotEmpty && 
        _readingsControllers[1].text.isNotEmpty) {
      if (_readingsControllers[0].text != _readingsControllers[1].text) {
        setState(() {
          _showThirdReading = true;
        });
      } else {
        setState(() {
          _showThirdReading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_getTitle()),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: _buildContent(),
        ),
      ),
      actions: _buildActions(),
    );
  }

  String _getTitle() {
    if (widget.initialData != null) return 'Editar Medición';
    if (_step == 0) return 'Seleccionar Tanque';
    if (_step == 1) return 'Tipo de Medición';
    return 'Registrar Medición ($_measurementType)';
  }

  Widget _buildContent() {
    if (_step == 0) return _buildTankSelection();
    if (_step == 1) return _buildTypeSelection();
    return _buildForm();
  }

  Widget _buildTankSelection() {
    if (_isLoadingTanks) {
      return const SizedBox(
        height: 400,
        child: Center(child: CircularProgressIndicator(color: Color(0xFFF27E26))),
      );
    }
    
    if (_tankError != null) {
      return SizedBox(
        height: 400,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 40),
              const SizedBox(height: 16),
              Text('Error: $_tankError', style: const TextStyle(color: Colors.white)),
              TextButton(onPressed: _fetchTanks, child: const Text('Reintentar'))
            ],
          ),
        ),
      );
    }

    if (_tanks.isEmpty) {
      return const SizedBox(
        height: 400,
        child: Center(child: Text('No hay tanques registrados', style: TextStyle(color: Colors.white54))),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Dynamic cross axis count based on width
        int crossAxisCount = 2;
        if (constraints.maxWidth > 500) crossAxisCount = 3;
        if (constraints.maxWidth > 700) crossAxisCount = 4;

        return SizedBox(
          height: 400, 
          width: double.maxFinite,
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 1.1,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _tanks.length,
            itemBuilder: (context, index) {
              final tank = _tanks[index];
              final tankName = tank['nombre'] ?? 'Sin Nombre';
              return ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedTank = tank; // Store full object
                    _step = 1;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF27E26), // Orange
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.all(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tankName, 
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTypeSelection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTypeButton('MEDICIÓN A VACÍO', 'VACIO', Icons.arrow_downward),
        const SizedBox(height: 16),
        _buildTypeButton('MEDICIÓN A FONDO', 'FONDO', Icons.arrow_upward),
      ],
    );
  }

  Widget _buildTypeButton(String label, String type, IconData icon) {
    return ElevatedButton(
      onPressed: () => _selectType(type),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(80),
        backgroundColor: const Color(0xFF1C2438), // Dark card color
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFF27E26), width: 1), // Orange border
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Icon(icon, color: const Color(0xFFF27E26), size: 32),
        ],
      ),
    );
  }

  void _selectType(String type) {
    setState(() {
      _measurementType = type;
      _step = 2;
    });
  }

  Widget _buildForm() {
    bool isVacio = _measurementType == 'VACIO';
    String readingLabel = isVacio ? 'Cinta' : 'Nivel';
    
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Lecturas Manuales ($readingLabel)'),
          Row(
            children: [
              Expanded(child: _buildNumField(_readingsControllers[0], '$readingLabel 1', 20000, onChanged: _checkThirdReadingNeeded)),
              if (isVacio) ...[
                const SizedBox(width: 8),
                Expanded(child: _buildNumField(_plomadaControllers[0], 'Plomada 1', 150)),
              ]
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildNumField(_readingsControllers[1], '$readingLabel 2', 20000, onChanged: _checkThirdReadingNeeded)),
              if (isVacio) ...[
                const SizedBox(width: 8),
                Expanded(child: _buildNumField(_plomadaControllers[1], 'Plomada 2', 150)),
              ]
            ],
          ),
          if (_showThirdReading) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildNumField(_readingsControllers[2], '$readingLabel 3 (Requerido)', 20000)),
                if (isVacio) ...[
                  const SizedBox(width: 8),
                  Expanded(child: _buildNumField(_plomadaControllers[2], 'Plomada 3', 150)),
                ]
              ],
            ),
          ],

          const SizedBox(height: 16),
          _buildSectionHeader('Temperaturas (80-135°F)'),
          _buildNumField(_tempAmbController, 'Temp. Ambiente', 135, min: 80),
          const SizedBox(height: 8),
          _buildNumField(_tempLiqTopController, 'Temp. Líquido Superior (Obligatorio)', 135, min: 80),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildNumField(_tempLiqMidController, 'Media (Opcional)', 135, min: 80)),
              const SizedBox(width: 8),
              Expanded(child: _buildNumField(_tempLiqBotController, 'Inferior (Opcional)', 135, min: 80)),
            ],
          ),

          const SizedBox(height: 16),
          _buildSectionHeader('Lecturas Automáticas'),
           Row(
            children: [
              Expanded(child: _buildNumField(_autoLevelController, 'Nivel Auto', 20000)),
              const SizedBox(width: 8),
              Expanded(child: _buildNumField(_autoTempController, 'Temp. Auto', 200)), // Limit?
            ],
          ),


          const SizedBox(height: 16),
          _buildSectionHeader('Inspector'),
          TextFormField(
            controller: _inspectorController,
            decoration: const InputDecoration(
              labelText: 'Nombre Inspector',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildNumField(TextEditingController controller, String label, double max, {double min = 0, VoidCallback? onChanged}) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (_) => onChanged?.call(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          // Optional fields check
          if (label.contains('Opcional')) return null;
          return 'Requerido';
        }
        final n = double.tryParse(value);
        if (n == null) return 'Inválido';
        if (n < min || n > max) return 'Rango: $min-$max';
        return null;
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF27E26), fontSize: 16)),
    );
  }

  List<Widget> _buildActions() {
    if (_step == 2) {
      return [
        if (widget.initialData == null)
          TextButton(
            onPressed: () {
              setState(() {
                _step = 1; // Back to type
              });
            },
            child: const Text('Atrás'),
          ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              try {
                // Construct payload
                final payload = {
                  'tanque': _selectedTank!['id'],
                  // Operator is mock for now, backend expects User ID. 
                  // If backend requires auth user, we might need a default user or handle auth.
                  // For now, assuming backend might default or we send a mock user ID if required.
                  // Checking backend model: 'operador' is ForeignKey to User. 
                  // Needs a valid user ID. Assuming ID 1 exists (admin/superuser).
                  'operador': 1, 
                  'operador': 1, 
                  'inspector': _inspectorController.text,
                  'tipo_medicion': _measurementType,
                  'fecha_hora': DateTime.now().toIso8601String(),
                  
                  // Readings
                  'lectura_1_cinta_o_nivel': double.tryParse(_readingsControllers[0].text),
                  'lectura_2_cinta_o_nivel': double.tryParse(_readingsControllers[1].text),
                  'lectura_3_cinta_o_nivel': _readingsControllers[2].text.isNotEmpty 
                      ? double.tryParse(_readingsControllers[2].text) 
                      : null,
                  
                  // Plomada (only if Vacio)
                  'lectura_1_plomada': _plomadaControllers[0].text.isNotEmpty 
                      ? double.tryParse(_plomadaControllers[0].text) 
                      : null,
                  'lectura_2_plomada': _plomadaControllers[1].text.isNotEmpty 
                      ? double.tryParse(_plomadaControllers[1].text) 
                      : null,
                  'lectura_3_plomada': _plomadaControllers[2].text.isNotEmpty 
                      ? double.tryParse(_plomadaControllers[2].text) 
                      : null,

                  // Temperatures
                  'temperatura_ambiente': double.tryParse(_tempAmbController.text),
                  'temp_liquido_superior': double.tryParse(_tempLiqTopController.text),
                  'temp_liquido_media': _tempLiqMidController.text.isNotEmpty 
                      ? double.tryParse(_tempLiqMidController.text) 
                      : null,
                  'temp_liquido_inferior': _tempLiqBotController.text.isNotEmpty 
                      ? double.tryParse(_tempLiqBotController.text) 
                      : null,

                  // Automatic
                  'nivel_automatico': _autoLevelController.text.isNotEmpty
                      ? double.tryParse(_autoLevelController.text)
                      : null,
                  'temperatura_automatica': _autoTempController.text.isNotEmpty
                      ? double.tryParse(_autoTempController.text)
                      : null,
                };

                if (widget.initialData != null) {
                  await ApiService().updateMedicion(widget.initialData!['id'], payload);
                } else {
                  await ApiService().createMedicion(payload);
                }
                
                if (mounted) {
                  Navigator.pop(context, true); // Return true to indicate success
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(widget.initialData != null ? 'Medición Actualizada' : 'Medición Registrada Exitosamente')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            }
          },
          child: const Text('Guardar'),
        ),
      ];
    }
    return [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      )
    ];
  }
}
