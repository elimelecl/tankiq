import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';

class CalculateMeasurementDialog extends StatefulWidget {
  const CalculateMeasurementDialog({super.key});

  @override
  State<CalculateMeasurementDialog> createState() =>
      _CalculateMeasurementDialogState();
}

class _CalculateMeasurementDialogState
    extends State<CalculateMeasurementDialog> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _nivelController = TextEditingController();

  List<dynamic> _tanques = [];
  Map<String, dynamic>? _selectedTanque;
  bool _isLoading = true;
  bool _hasCalculated = false;
  double? _cintaAIngresar;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _loadTanques();
  }

  @override
  void dispose() {
    _nivelController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadTanques() async {
    try {
      final tanques = await _apiService.getTanques();
      setState(() {
        _tanques = tanques;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al cargar tanques: $e';
      });
    }
  }

  void _calcular() {
    if (_selectedTanque == null) {
      setState(() {
        _errorMessage = 'Seleccione un tanque';
      });
      return;
    }

    final nivelText = _nivelController.text.trim();
    if (nivelText.isEmpty) {
      setState(() {
        _errorMessage = 'Ingrese el nivel de líquido';
      });
      return;
    }

    final nivel = double.tryParse(nivelText);
    if (nivel == null) {
      setState(() {
        _errorMessage = 'Nivel inválido';
      });
      return;
    }

    final alturaRef =
        (_selectedTanque!['altura_referencia'] as num).toDouble();

    setState(() {
      _cintaAIngresar = alturaRef - nivel + 100;
      _hasCalculated = true;
      _errorMessage = null;
    });
    _animController.forward(from: 0);
  }

  void _reset() {
    setState(() {
      _hasCalculated = false;
      _cintaAIngresar = null;
      _nivelController.clear();
      _selectedTanque = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFF27E26);
    const darkBg = Color(0xFF101524);
    const cardBg = Color(0xFF1C2438);

    return Dialog(
      backgroundColor: darkBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Header ───
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [orange, Color(0xFFE06D1B)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.straighten, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Calcular Medición a Vacío',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Calcula la cinta a ingresar en el tanque',
                            style: TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white54),
                      splashRadius: 20,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(color: orange),
                    ),
                  )
                else if (!_hasCalculated) ...[
                  // ─── STEP 1: Input Form ───

                  // Tanque Selector
                  const Text(
                    'Seleccionar Tanque',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedTanque != null
                            ? orange.withValues(alpha: 0.5)
                            : Colors.white10,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: _selectedTanque?['id'],
                        hint: const Text(
                          'Ej: TK-001',
                          style: TextStyle(color: Colors.white30),
                        ),
                        dropdownColor: cardBg,
                        icon: const Icon(Icons.expand_more, color: orange),
                        items: _tanques.map<DropdownMenuItem<int>>((t) {
                          return DropdownMenuItem<int>(
                            value: t['id'],
                            child: Text(
                              t['nombre'],
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedTanque = _tanques.firstWhere(
                              (t) => t['id'] == value,
                            );
                            _errorMessage = null;
                          });
                        },
                      ),
                    ),
                  ),

                  // Show reference height if tank selected
                  if (_selectedTanque != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: orange.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.height, color: orange, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Altura de referencia:',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${NumberUtils.format(_selectedTanque!['altura_referencia'])} mm',
                            style: const TextStyle(
                              color: orange,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Nivel Input
                  const Text(
                    'Nivel de líquido (telemetría)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nivelController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ingrese el nivel en mm',
                      suffixText: 'mm',
                      suffixStyle: const TextStyle(
                        color: orange,
                        fontWeight: FontWeight.bold,
                      ),
                      filled: true,
                      fillColor: cardBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: orange, width: 2),
                      ),
                    ),
                  ),

                  // Error message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Formula reminder
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.functions,
                            color: Colors.white.withValues(alpha: 0.4), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Cinta = Altura Ref. − Nivel + 100',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Calculate Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _calcular,
                      icon: const Icon(Icons.calculate, size: 22),
                      label: const Text(
                        'Calcular',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ] else ...[
                  // ─── STEP 2: Results ───
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        // Main Result Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                orange.withValues(alpha: 0.15),
                                orange.withValues(alpha: 0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: orange.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'CINTA A INGRESAR',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    NumberUtils.format(_cintaAIngresar!),
                                    style: const TextStyle(
                                      color: orange,
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'mm',
                                    style: TextStyle(
                                      color: orange,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Detail rows
                        _buildDetailRow(
                          icon: Icons.propane_tank_outlined,
                          label: 'Tanque',
                          value: _selectedTanque!['nombre'],
                          cardBg: cardBg,
                        ),
                        const SizedBox(height: 10),
                        _buildDetailRow(
                          icon: Icons.height,
                          label: 'Altura de Referencia',
                          value:
                              '${_selectedTanque!['altura_referencia']} mm',
                          cardBg: cardBg,
                        ),
                        const SizedBox(height: 10),
                        _buildDetailRow(
                          icon: Icons.water,
                          label: 'Nivel Telemetría',
                          value: '${_nivelController.text} mm',
                          cardBg: cardBg,
                        ),
                        const SizedBox(height: 10),
                        _buildDetailRow(
                          icon: Icons.add_circle_outline,
                          label: 'Constante',
                          value: '+ 100 mm',
                          cardBg: cardBg,
                        ),

                        const SizedBox(height: 20),

                        // Formula breakdown
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Text(
                            '${NumberUtils.format(_selectedTanque!['altura_referencia'])} − ${NumberUtils.format(double.tryParse(_nivelController.text) ?? 0)} + 100 = ${NumberUtils.format(_cintaAIngresar!)} mm',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _reset,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Nueva Cálculo'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(
                                      color: Colors.white24),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    Navigator.pop(context),
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('Aceptar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color cardBg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
