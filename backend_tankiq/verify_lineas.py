from django.test import Client
from mediciones.models import Tanque, Linea
import json

def verify_lineas():
    client = Client()
    print("Verifying Lineas...")

    # 1. Ensure Tanque exists
    tanque, _ = Tanque.objects.get_or_create(nombre="T-LINEA", capacidad_maxima=50000, altura_referencia=15000)

    # 2. Create Linea via Model
    l1 = Linea.objects.create(
        nombre="Linea-1",
        tanque=tanque,
        volumen_tov=100.0,
        volumen_gsv=98.0,
        volumen_nsv=97.5
    )
    print(f"Created Linea Model: {l1}")

    # 3. Verify API GET
    response = client.get('/api/lineas/')
    print(f"GET /api/lineas/ Status: {response.status_code}")
    print(f"Count: {len(response.json())}")

    # 4. Verify API POST
    payload = {
        "nombre": "Linea-API",
        "tanque": tanque.id,
        "volumen_tov": 200.0,
        "volumen_gsv": 195.0,
        "volumen_nsv": 190.0
    }
    response = client.post(
        '/api/lineas/',
        data=json.dumps(payload),
        content_type='application/json'
    )
    print(f"POST /api/lineas/ Status: {response.status_code}")
    if response.status_code == 201:
        print(f"Created Linea API ID: {response.json()['id']}")
    else:
        print(f"Error: {response.content}")

if __name__ == '__main__':
    verify_lineas()
