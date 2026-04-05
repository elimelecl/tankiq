import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _wsSubscription;
  late Map<String, dynamic> product;

  @override
  void initState() {
    super.initState();
    product = Map<String, dynamic>.from(widget.product);
    _setupWebSocket();
  }

  void _setupWebSocket() {
    _wsService.connect();
    _wsSubscription = _wsService.stream.listen((message) {
      if (message['model'] == 'Producto' && message['id'] == product['id']) {
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
      final updated = await _apiService.getProductoById(product['id']);
      if (mounted) {
        setState(() {
          product = updated;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing product: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRefinado = product['es_refinado'] == true;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(product['nombre'] ?? 'Detalle del Producto', style: const TextStyle(color: Colors.white)),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: isRefinado ? Colors.orange.withOpacity(0.2) : Colors.brown.withOpacity(0.2),
                    child: Icon(
                      isRefinado ? Icons.local_gas_station : Icons.oil_barrel,
                      size: 40,
                      color: isRefinado ? Colors.orange : Colors.brown,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    product['nombre'] ?? 'Sin Nombre',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isRefinado ? Colors.orange.withOpacity(0.2) : Colors.brown.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isRefinado ? Colors.orange : Colors.brown,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isRefinado ? "Refinado" : "Crudo",
                      style: TextStyle(
                        color: isRefinado ? Colors.orange : Colors.brown![300],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Información Técnica",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildDetailTile(Icons.science, "Gravedad API", "${product['api']?.toString() ?? '---'} °API"),
            _buildDetailTile(Icons.business, "Cliente", product['cliente_nombre'] ?? "ID: ${product['cliente']}"),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
