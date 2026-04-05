import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // Use 127.0.0.1 for macOS/iOS Simulator, 10.0.2.2 for Android Emulator
  // static const String baseUrl = 'http://127.0.0.1:8000/api'; 
  // Assuming macOS development for now based on user context
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  ApiService._internal();

  // --- Tanques CRUD ---

  Future<List<dynamic>> getTanques() async {
    final response = await http.get(Uri.parse('$baseUrl/tanques/'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load tanks');
    }
  }

  Future<Map<String, dynamic>> createTanque(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tanques/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create tank: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateTanque(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/tanques/$id/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update tank: ${response.body}');
    }
  }

  Future<void> deleteTanque(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/tanques/$id/'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete tank');
    }
  }

  Future<Map<String, dynamic>> updateTankApi(int id, double api) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tanques/$id/cambiar-api/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'api': api}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update tank API: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> uploadCalibrationTable(
    int id, 
    File file, 
    String nombre, 
    {double? api, double? ajusteFra, double? incrementoFra}
  ) async {
    var request = http.MultipartRequest(
      'POST', 
      Uri.parse('$baseUrl/tanques/$id/upload-tabla/')
    );
    
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    request.fields['nombre'] = nombre;
    if (api != null) request.fields['api'] = api.toString();
    if (ajusteFra != null) request.fields['ajuste_fra'] = ajusteFra.toString();
    if (incrementoFra != null) request.fields['incremento_fra'] = incrementoFra.toString();

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to upload table: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> saveCalibrationTable(int id, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tanques/$id/save-calibration/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to save calibration table: ${response.body}');
    }
  }

  // --- Mediciones CRUD ---

  Future<Map<String, dynamic>> getMediciones({int? tanqueId, String? inspector, String? startDate, String? url}) async {
    // If a full URL is provided (for next pages), use it. Otherwise build from baseUrl.
    String finalUrl = url ?? '$baseUrl/mediciones/';
    
    if (url == null) {
      List<String> queryParams = [];
      if (tanqueId != null) queryParams.add('tanque=$tanqueId');
      if (inspector != null && inspector.isNotEmpty) queryParams.add('inspector=$inspector');
      if (startDate != null && startDate.isNotEmpty) queryParams.add('fecha_hora__date=$startDate');

      if (queryParams.isNotEmpty) {
        finalUrl += '?${queryParams.join('&')}';
      }
    }

    final response = await http.get(Uri.parse(finalUrl));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load measurements: ${response.body}');
    }
  }

  Future<List<dynamic>> getProductos() async {
    final response = await http.get(Uri.parse('$baseUrl/productos/'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load products');
    }
  }

  Future<Map<String, dynamic>> createProducto(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/productos/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create product: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateProducto(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/productos/$id/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update product: ${response.body}');
    }
  }

  Future<void> deleteProducto(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/productos/$id/'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete product');
    }
  }

  Future<List<dynamic>> getClientes() async {
    final response = await http.get(Uri.parse('$baseUrl/clientes/'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load clients');
    }
  }

  Future<Map<String, dynamic>> createMedicion(Map<String, dynamic> data) async {
    // Ensure numeric fields are properly typed/parsed before sending if needed, 
    // though json.encode handles basic types.
    final response = await http.post(
      Uri.parse('$baseUrl/mediciones/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create measurement: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateMedicion(int id, Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/mediciones/$id/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update measurement: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> completarMedicion(int id, {required double api, required double gsw}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/mediciones/$id/completar/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'api': api,
        'gsw': gsw,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al completar medición: ${response.body}');
    }
  }

  Future<void> deleteMedicion(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/mediciones/$id/'));
    if (response.statusCode != 204) {
      throw Exception('Error al eliminar la medición: ${response.body}');
    }
  }

  // --- Líneas CRUD ---

  Future<List<dynamic>> getLineas() async {
    final response = await http.get(Uri.parse('$baseUrl/lineas/'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load lines');
    }
  }

  Future<Map<String, dynamic>> createLinea(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/lineas/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create line: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateLinea(int id, Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/lineas/$id/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update line: ${response.body}');
    }
  }

  Future<void> deleteLinea(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/lineas/$id/'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete line');
    }
  }

  // --- Balances CRUD ---

  Future<List<dynamic>> getBalances() async {
    final response = await http.get(Uri.parse('$baseUrl/balances/'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load balances');
    }
  }

  Future<Map<String, dynamic>> createBalance(String date) async {
    final response = await http.post(
      Uri.parse('$baseUrl/balances/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'fecha': date, 'estado': 'BORRADOR'}),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create balance: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateBalanceDetail(int id, Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/balance-detalles/$id/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update balance detail: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> closeBalance(int id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/balances/$id/cerrar/'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to close balance: ${response.body}');
    }
  }

  Future<void> deleteBalance(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/balances/$id/'));
    if (response.statusCode != 204) {
      throw Exception('Error al eliminar el balance: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getMedicionById(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/mediciones/$id/'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load measurement details');
    }
  }

  Future<Map<String, dynamic>> getTanqueById(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/tanques/$id/'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load tank details');
    }
  }

  Future<Map<String, dynamic>> getProductoById(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/productos/$id/'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load product details');
    }
  }

  Future<Map<String, dynamic>> getBalanceById(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/balances/$id/'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load balance details');
    }
  }

  // --- Medios de Transporte CRUD ---

  Future<List<dynamic>> getMediosTransporte() async {
    final response = await http.get(Uri.parse('$baseUrl/medios-transporte/'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load transport means');
    }
  }

  Future<Map<String, dynamic>> createMedioTransporte(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/medios-transporte/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create transport mean: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateMedioTransporte(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/medios-transporte/$id/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update transport mean: ${response.body}');
    }
  }

  Future<void> deleteMedioTransporte(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/medios-transporte/$id/'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete transport mean');
    }
  }

  // --- Movimientos de Transporte CRUD ---

  Future<List<dynamic>> getMovimientosTransporte() async {
    final response = await http.get(Uri.parse('$baseUrl/movimientos-transporte/'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load transport movements');
    }
  }

  Future<Map<String, dynamic>> createMovimientoTransporte(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/movimientos-transporte/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create transport movement: ${response.body}');
    }
  }

  Future<void> deleteMovimientoTransporte(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/movimientos-transporte/$id/'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete transport movement');
    }
  }

  Future<http.Response> exportMedicionPdf(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/mediciones/$id/exportar-pdf/'));
    if (response.statusCode == 200) {
      return response;
    } else {
      throw Exception('Failed to export measurement PDF: ${response.body}');
    }
  }
}
