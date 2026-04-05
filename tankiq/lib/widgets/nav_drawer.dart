import 'package:flutter/material.dart';
import '../screens/tank_settings_screen.dart';
import '../screens/measurements_screen.dart';
import '../screens/home_screen.dart';
import '../screens/products_screen.dart';
import '../screens/lineas_screen.dart';
import '../screens/balances_list_screen.dart';
import '../screens/medios_transporte_screen.dart';

class NavDrawer extends StatelessWidget {
  const NavDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF101524),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xFFF27E26),
                  child: Icon(Icons.settings, color: Colors.white),
                ),
                SizedBox(height: 12),
                Text(
                  'TankIQ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Inicio'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Mediciones'),
            onTap: () {
              Navigator.pop(context);
               Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MeasurementsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.propane_tank),
            title: const Text('Tanques'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TankSettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Productos'),
            onTap: () {
              Navigator.pop(context);
               Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProductsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.linear_scale),
            title: const Text('Líneas'),
            onTap: () {
              Navigator.pop(context);
               Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LineasScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_shipping),
            title: const Text('Transporte'),
            onTap: () {
              Navigator.pop(context);
               Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MediosTransporteScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.balance),
            title: const Text('Balance de Planta'),
            onTap: () {
              Navigator.pop(context);
               Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BalancesListScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
