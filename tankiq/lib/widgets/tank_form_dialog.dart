import 'package:flutter/material.dart';

class TankFormDialog extends StatefulWidget {
  final String? existingName;
  final double? existingCapacity;
  final double? existingHeight;

  const TankFormDialog({
    super.key,
    this.existingName,
    this.existingCapacity,
    this.existingHeight,
  });

  @override
  State<TankFormDialog> createState() => _TankFormDialogState();
}

class _TankFormDialogState extends State<TankFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _capacityController;
  late TextEditingController _heightController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingName);
    _capacityController = TextEditingController(
        text: widget.existingCapacity?.toString() ?? '');
    _heightController = TextEditingController(
        text: widget.existingHeight?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.existingName != null;
    return AlertDialog(
      title: Text(
        isEditing ? 'Editar Tanque' : 'Nuevo Tanque',
        style: const TextStyle(color: Color(0xFFF27E26), fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(_nameController, 'Nombre del Tanque (Ej: T-01)', false),
              const SizedBox(height: 16),
              _buildTextField(_capacityController, 'Capacidad Máxima (Barriles)', true),
              const SizedBox(height: 16),
              _buildTextField(_heightController, 'Altura de Referencia (mm)', true),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              // Return data to caller
              Navigator.pop(context, {
                'name': _nameController.text,
                'capacity': double.tryParse(_capacityController.text),
                'height': double.tryParse(_heightController.text),
              });
            }
          },
          child: Text(isEditing ? 'Guardar Cambios' : 'Crear Tanque'),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, bool isNumeric) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Requerido';
        if (isNumeric && double.tryParse(value) == null) return 'Inválido';
        return null;
      },
    );
  }
}
