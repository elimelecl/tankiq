from django.test import Client
from mediciones.models import Tanque
import json

def verify_api():
    client = Client()
    
    print("Verifying API...")

    # 1. Create a Tank via Model (to have data)
    Tanque.objects.get_or_create(nombre="API-Tank", capacidad_maxima=1000, altura_referencia=5000)
    
    # 2. List Tanks
    response = client.get('/api/tanques/')
    print(f"GET /api/tanques/ Status: {response.status_code}")
    if response.status_code == 200:
        print(f"Response: {response.json()}")
    
    # 3. Create Medicion via API
    # Valid payload
    payload = {
        "tanque": 1, # ID of T-101 created earlier or API-Tank
        "inspector": "API Inspector",
        "fecha_hora": "2023-10-27T10:00:00Z",
        "tipo_medicion": "FONDO",
        "temperatura_ambiente": 95,
        "nivel_automatico": 5000,
        "temperatura_automatica": 95,
        "temp_liquido_superior": 95,
        "lectura_1_cinta_o_nivel": 5000,
        "lectura_2_cinta_o_nivel": 5000
    }
    
    # We need to find the ID of the tank we want to use
    t = Tanque.objects.first()
    payload['tanque'] = t.id
    
    response = client.post(
        '/api/mediciones/', 
        data=json.dumps(payload), 
        content_type='application/json'
    )
    print(f"POST /api/mediciones/ Status: {response.status_code}")
    if response.status_code == 201:
        print(f"Created Medicion: {response.json()['id']}")
    else:
        print(f"Error: {response.content}")

    # 4. List Mediciones
    response = client.get('/api/mediciones/')
    print(f"GET /api/mediciones/ Count: {len(response.json())}")

if __name__ == '__main__':
    verify_api()
