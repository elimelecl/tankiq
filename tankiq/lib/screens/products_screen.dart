import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import 'product_detail_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _wsSubscription;
  
  List<dynamic> _products = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _setupWebSocket();
  }

  void _setupWebSocket() {
    _wsService.connect();
    _wsSubscription = _wsService.stream.listen((message) {
      final model = message['model'];
      if (model == 'Producto' || model == 'Cliente') {
        _fetchProducts(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchProducts({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final data = await _apiService.getProductos();
      if (mounted) {
        setState(() {
          _products = data;
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

  Future<void> _deleteProduct(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Estás seguro de que deseas eliminar este producto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService().deleteProducto(id);
        _fetchProducts();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto eliminado')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showProductDialog({Map<String, dynamic>? product}) async {
    final isEditing = product != null;
    final nameController = TextEditingController(text: isEditing ? product['nombre'] : '');
    final apiController = TextEditingController(text: isEditing ? product['api'].toString() : '');
    bool isRefinado = isEditing ? (product['es_refinado'] ?? false) : false;
    int? selectedClientId = isEditing ? product['cliente'] : null;

    // Fetch clients for dropdown
    List<dynamic> clients = [];
    try {
       clients = await ApiService().getClientes();
       if (clients.isNotEmpty && selectedClientId == null && !isEditing) {
         selectedClientId = clients[0]['id'];
       }
    } catch (e) {
      // Handle error or show empty
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(isEditing ? 'Editar Producto' : 'Nuevo Producto'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: apiController,
                      decoration: const InputDecoration(labelText: 'Gravedad API'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedClientId,
                      decoration: const InputDecoration(labelText: 'Cliente'),
                      items: clients.map<DropdownMenuItem<int>>((client) {
                        return DropdownMenuItem<int>(
                          value: client['id'],
                          child: Text(client['nombre']),
                        );
                      }).toList(),
                      onChanged: (val) => setStateDialog(() => selectedClientId = val),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text("Es Refinado?"),
                        Switch(
                          value: isRefinado,
                          activeColor: const Color(0xFFF27E26),
                          onChanged: (val) => setStateDialog(() => isRefinado = val),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancelar")
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty || apiController.text.isEmpty || selectedClientId == null) {
                       return;
                    }
                    
                    final data = {
                      'nombre': nameController.text,
                      'api': double.tryParse(apiController.text) ?? 0.0,
                      'cliente': selectedClientId,
                      'es_refinado': isRefinado,
                    };

                    try {
                      if (isEditing) {
                        await ApiService().updateProducto(product['id'], data);
                      } else {
                        await ApiService().createProducto(data);
                      }
                      if (mounted) {
                          Navigator.pop(ctx);
                          _fetchProducts();
                      }
                    } catch (e) {
                       // Error handling
                         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF27E26)),
                  child: Text(isEditing ? "Actualizar" : "Crear"),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Productos', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFF27E26),
        onPressed: () => _showProductDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF27E26)))
          : _error != null
              ? Center(child: Text("Error: $_error", style: const TextStyle(color: Colors.red)))
              : _products.isEmpty
                  ? const Center(child: Text("No hay productos registrados.", style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        return Card(
                          color: const Color(0xFF1E293B),
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ProductDetailScreen(product: product)),
                              );
                            },
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.white10,
                                child: Text(
                                  (product['nombre'] as String? ?? 'P')[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                product['nombre'] ?? 'Sin Nombre',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                "API: ${product['api']} • ${product['es_refinado'] == true ? 'Refinado' : 'Crudo'}",
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                    onPressed: () => _showProductDialog(product: product),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                                    onPressed: () => _deleteProduct(product['id']),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
