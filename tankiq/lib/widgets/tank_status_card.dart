import 'package:flutter/material.dart';
import '../screens/tank_detail_screen.dart';
import '../utils/formatters.dart';

class TankStatusCard extends StatelessWidget {
  final Map<String, dynamic> tank;

  const TankStatusCard({super.key, required this.tank});

  @override
  Widget build(BuildContext context) {
    final name = tank['nombre'] ?? 'Tanque';
    final data = tank['ultima_medicion'];
    
    // Default values if no measurement
    final nivelMm = data != null ? data['nivel_mm'] : 0.0;
    final nivelPct = data != null ? data['nivel_porcentaje'] : 0.0;
    final fecha = data != null ? data['fecha'] : '--/--';
    final hora = data != null ? data['hora'] : '--:--';

    // Simplified Date string: "26/10 - 14:35"
    // Assuming fecha is dd/mm/yyyy from serializer
    String shortDate = fecha.toString();
    if (shortDate.length >= 5) {
        shortDate = shortDate.substring(0, 5); // Take dd/mm
    }
    final dateTimeStr = "$shortDate • $hora";

    return Container(
      height: 200, // Fixed height for consistency
      decoration: BoxDecoration(
        color: const Color(0xFFF27E26), // Orange
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TankDetailScreen(tank: tank),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Row(
              children: [
                // Left Column: Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        data != null && data['producto'] != null ? data['producto'] : 'Sin Producto',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const Spacer(),
                      _buildInfoRow('Nivel:', '${NumberUtils.format(nivelMm)} mm'),
                      const SizedBox(height: 8),
                      _buildInfoRow('Volumen:', data != null ? '${data['volumen_litros']} L' : '--- L'),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.white.withValues(alpha: 0.8), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            dateTimeStr,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Right Column: Progress Bar
                Container(
                    width: 50,
                    margin: const EdgeInsets.only(left: 8),
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              Container(
                                width: 14,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              FractionallySizedBox(
                                heightFactor: (nivelPct / 100).clamp(0.0, 1.0),
                                child: Container(
                                  width: 14,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF22C55E), // Vibrant Green
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${NumberUtils.format(nivelPct)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          '%',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
