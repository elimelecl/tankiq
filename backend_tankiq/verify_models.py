from mediciones.models import Tanque, Medicion
from django.utils import timezone

def verify():
    print("Verifying TankIQ Models...")
    
    # 1. Create Tanque
    t1 = Tanque.objects.create(
        nombre="T-101",
        capacidad_maxima=50000,
        altura_referencia=15000 # mm
    )
    print(f"Created Tanque: {t1}")

    # 2. Create Medicion (VACIO)
    # Cinta 1 = 5000, Cinta 2 = 5000 -> Avg 5000
    # Nivel = 15000 - 5000 = 10000
    m_vacio = Medicion(
        tanque=t1,
        inspector="Inspector Gadget",
        fecha_hora=timezone.now(),
        tipo_medicion='VACIO',
        temperatura_ambiente=90,
        nivel_automatico=10000,
        temperatura_automatica=90,
        temp_liquido_superior=90,
        lectura_1_cinta_o_nivel=5000,
        lectura_2_cinta_o_nivel=5000
    )
    m_vacio.save()
    print(f"Created Medicion VACIO. Calculado: {m_vacio.nivel_calculado_final} (Expected 10000.0)")

    # 3. Create Medicion (FONDO)
    # Nivel 1 = 8000, Nivel 2 = 8200 -> Diff 200, assume we add 3rd reading of 8100? 
    # Let's test basic avg of 2 first.
    m_fondo = Medicion(
        tanque=t1,
        inspector="Inspector Gadget",
        fecha_hora=timezone.now(),
        tipo_medicion='FONDO',
        temperatura_ambiente=90,
        nivel_automatico=8100,
        temperatura_automatica=90,
        temp_liquido_superior=90,
        lectura_1_cinta_o_nivel=8000,
        lectura_2_cinta_o_nivel=8200
    )
    m_fondo.save()
    print(f"Created Medicion FONDO. Calculado: {m_fondo.nivel_calculado_final} (Expected 8100.0)")

    print("Verification Complete.")

if __name__ == '__main__':
    verify()
