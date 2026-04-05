from rest_framework import serializers
from decimal import Decimal
from .models import Tanque, Medicion, Linea, Cliente, Producto, BalanceDiario, DetalleBalance, MedioTransporte, MovimientoTransporte

class TanqueSerializer(serializers.ModelSerializer):
    ultima_medicion = serializers.SerializerMethodField()

    class Meta:
        model = Tanque
        fields = '__all__'

    def get_ultima_medicion(self, obj):
        latest = obj.mediciones.filter(activo=True).first() # Ordered by -fecha_hora
        if not latest:
            return None
        
        # Priority: NSV (fiscal) > Volumen Calculado (simple) > 0
        volume = latest.nsv or latest.volumen_calculado or 0
        nivel = latest.nivel_calculado_final or 0
        max_height = obj.altura_referencia or 1
        percentage = max(0, min((nivel / max_height) * 100, 100))
        
        return {
            'id': latest.id,
            'fecha': latest.fecha_hora.strftime('%d/%m/%Y'),
            'hora': latest.fecha_hora.strftime('%H:%M'),
            'nivel_porcentaje': round(percentage, 1),
            'volumen_litros': f"{volume:,.2f}",
            'nivel_mm': nivel,
            'producto': latest.producto.nombre if latest.producto else 'N/A',
            'estado': latest.estado
        }

class ClienteSerializer(serializers.ModelSerializer):
    class Meta:
        model = Cliente
        fields = '__all__'

class ProductoSerializer(serializers.ModelSerializer):
    cliente_nombre = serializers.ReadOnlyField(source='cliente.nombre')
    
    class Meta:
        model = Producto
        fields = '__all__'

class MedicionSerializer(serializers.ModelSerializer):
    tanque_nombre = serializers.ReadOnlyField(source='tanque.nombre')
    operador_nombre = serializers.ReadOnlyField(source='operador.username')
    producto_nombre = serializers.ReadOnlyField(source='producto.nombre')
    estado_display = serializers.CharField(source='get_estado_display', read_only=True)
    fecha_hora_display = serializers.SerializerMethodField()
    is_in_balance = serializers.SerializerMethodField()

    class Meta:
        model = Medicion
        fields = '__all__'
        read_only_fields = (
            'nivel_calculado_final', 'volumen_calculado',
            'tov', 'gov', 'gsv', 'nsv', 'api_60', 
            'ctsh_factor', 'ctl_factor', 'fra_valor',
            'tanque_nombre', 'operador_nombre', 'producto_nombre', 'estado_display',
            'fecha_hora_display', 'is_in_balance',
        )

    def get_fecha_hora_display(self, obj):
        return obj.fecha_hora.strftime('%d/%m/%Y %H:%M')

    def get_is_in_balance(self, obj):
        return obj.detallebalance_set.exists()


class CompletarMedicionSerializer(serializers.Serializer):
    """Serializer for the 'completar' action — accepts API and GSW to finalize a measurement."""
    api = serializers.DecimalField(
        max_digits=5, decimal_places=1,
        help_text="Gravedad API observada (1 decimal)"
    )
    gsw = serializers.DecimalField(
        max_digits=5, decimal_places=3,
        help_text="GSW (3 decimales)"
    )

class LineaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Linea
        fields = '__all__'

class MedioTransporteSerializer(serializers.ModelSerializer):
    class Meta:
        model = MedioTransporte
        fields = '__all__'

class MovimientoTransporteSerializer(serializers.ModelSerializer):
    medio_transporte_nombre = serializers.ReadOnlyField(source='medio_transporte.nombre')
    medio_transporte_icono = serializers.ReadOnlyField(source='medio_transporte.icono')
    
    class Meta:
        model = MovimientoTransporte
        fields = '__all__'

class DetalleBalanceSerializer(serializers.ModelSerializer):
    transportes = MovimientoTransporteSerializer(many=True, read_only=True)
    
    class Meta:
        model = DetalleBalance
        fields = '__all__'

class BalanceDiarioSerializer(serializers.ModelSerializer):
    detalles = DetalleBalanceSerializer(many=True, read_only=True)
    estado_display = serializers.CharField(source='get_estado_display', read_only=True)

    class Meta:
        model = BalanceDiario
        fields = '__all__'
