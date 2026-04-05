# Reactive Architecture (WebSockets) in TankIQ

This project follows a **Reactive Architecture** where the UI updates automatically in response to server-side events via WebSockets.

## Backend Standard (Django)
All core models must broadcast their changes. In `models.py`, we use a signal dispatcher to map all models to the WebSocket "updates" group.

```python
REACTIVE_MODELS = [Tanque, Cliente, Producto, Medicion, Linea, BalanceDiario, DetalleBalance]

for model in REACTIVE_MODELS:
    create_signal_handler(model)
```

## Frontend Standard (Flutter)
To make a screen reactive, follow these steps:

1. **Service Usage**: Use the `WebSocketService` singleton.
2. **Setup**: In `initState`, subscribe to the `_wsService.stream`.
3. **Filtering**: Check if the broadcast message is relevant to the current screen.
4. **Action**: Call your data-fetching method (e.g., `_fetchData()`) with `showLoading: false` to avoid UI flickers.
5. **Memory Management**: **ALWAYS** cancel the `StreamSubscription` in the `dispose` method.

### Example Implementation:
```dart
class MyScreen extends StatefulWidget { ... }

class _MyScreenState extends State<MyScreen> {
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _wsSubscription = _wsService.stream.listen((message) {
      // Logic to decide if we refresh
      _fetchData(showLoading: false);
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }
}
```

## Real-Time Indicators
Reactive screens should display a **"LIVE"** indicator in the AppBar (Green Dot) to signal to the user that they don't need to refresh manually.
