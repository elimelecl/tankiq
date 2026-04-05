import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class CompleteMeasurementDialog extends StatefulWidget {
  final Map<String, dynamic> measurement;

  const CompleteMeasurementDialog({super.key, required this.measurement});

  @override
  State<CompleteMeasurementDialog> createState() =>
      _CompleteMeasurementDialogState();
}

class _CompleteMeasurementDialogState extends State<CompleteMeasurementDialog>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _apiController = TextEditingController();
  final TextEditingController _gswController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSubmitting = false;
  bool _isComplete = false;
  Map<String, dynamic>? _updatedMeasurement;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _apiController.dispose();
    _gswController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await _apiService.completarMedicion(
        widget.measurement['id'],
        api: double.parse(_apiController.text),
        gsw: double.parse(_gswController.text),
      );
      setState(() {
        _isSubmitting = false;
        _isComplete = true;
        _updatedMeasurement = result;
      });
      _animController.forward(from: 0);
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFF27E26);
    const darkBg = Color(0xFF101524);
    const cardBg = Color(0xFF1C2438);
    final m = widget.measurement;

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
                          colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.check_circle_outline, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Completar Medición',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m['tanque_nombre'] ?? 'Tanque ID: ${m['tanque']}',
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context, _isComplete),
                      icon: const Icon(Icons.close, color: Colors.white54),
                      splashRadius: 20,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ─── Measurement Summary ───
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow('Tipo', m['tipo_medicion'] ?? '---', cardBg),
                      const SizedBox(height: 6),
                      _buildInfoRow('Nivel Calculado',
                          '${m['nivel_calculado_final'] ?? '---'} mm', cardBg),
                      const SizedBox(height: 6),
                      _buildInfoRow('Inspector', m['inspector'] ?? '---', cardBg),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                if (!_isComplete) ...[
                  // ─── Input Form ───
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'API (Gravedad API observada)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _apiController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                          ],
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Ej: 29.5',
                            suffixText: '°API',
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
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Requerido';
                            final n = double.tryParse(value);
                            if (n == null) return 'Valor inválido';
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        const Text(
                          'GSW',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _gswController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                          ],
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Ej: 0.895',
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
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Requerido';
                            final n = double.tryParse(value);
                            if (n == null) return 'Valor inválido';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),

                  // Error message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 22),
                      label: Text(
                        _isSubmitting ? 'Procesando...' : 'Completar Medición',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                ] else ...[
                  // ─── Success View ───
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        // Success icon
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: Color(0xFF22C55E),
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '¡Medición Completada!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Results
                        _buildResultRow(
                          icon: Icons.oil_barrel,
                          label: 'API Observado',
                          value: '${_updatedMeasurement?['api']?.toStringAsFixed(1) ?? '---'} °API',
                          cardBg: cardBg,
                        ),
                        const SizedBox(height: 10),
                        _buildResultRow(
                          icon: Icons.science,
                          label: 'GSW',
                          value: _updatedMeasurement?['gsw']?.toStringAsFixed(3) ?? '---',
                          cardBg: cardBg,
                        ),
                        const SizedBox(height: 10),
                        _buildResultRow(
                          icon: Icons.water_drop,
                          label: 'Volumen Calculado',
                          value: '${_updatedMeasurement?['volumen_calculado']?.toStringAsFixed(2) ?? '---'}',
                          cardBg: cardBg,
                          highlight: true,
                        ),

                        const SizedBox(height: 24),

                        SizedBox(
                          height: 48,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Aceptar',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
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

  Widget _buildInfoRow(String label, String value, Color cardBg) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildResultRow({
    required IconData icon,
    required String label,
    required String value,
    required Color cardBg,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFF22C55E).withValues(alpha: 0.08)
            : cardBg,
        borderRadius: BorderRadius.circular(10),
        border: highlight
            ? Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: highlight ? const Color(0xFF22C55E) : Colors.white38, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
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
