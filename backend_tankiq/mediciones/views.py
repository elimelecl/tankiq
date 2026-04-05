import openpyxl
import json
from decimal import Decimal
from rest_framework import viewsets, status, serializers
from rest_framework.decorators import action, permission_classes, authentication_classes
from rest_framework.permissions import AllowAny
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response
from django.db import transaction
from django.http import HttpResponse
from django.shortcuts import get_object_or_404
from django_filters.rest_framework import DjangoFilterBackend
from .models import (
    Tanque, Medicion, Linea, Cliente, Producto, 
    BalanceDiario, DetalleBalance, MedioTransporte, MovimientoTransporte,
    NombresDeTablas, TablaDeAforo
)
from .utils import generate_balance_pdf, generate_medicion_pdf
from .serializers import (
    TanqueSerializer, MedicionSerializer, LineaSerializer,
    ClienteSerializer, ProductoSerializer, CompletarMedicionSerializer,
    BalanceDiarioSerializer, DetalleBalanceSerializer, MedioTransporteSerializer,
    MovimientoTransporteSerializer,
)

class TanqueViewSet(viewsets.ModelViewSet):
    """
    API endpoint that allows Tanques to be viewed or edited.
    """
    queryset = Tanque.objects.all()
    serializer_class = TanqueSerializer

    @action(detail=True, methods=['post'], url_path='upload-tabla')
    def upload_tabla(self, request, pk=None):
        """
        Upload and parse an Excel calibration table for the tank.
        Expects columns: DecenasCm, CantidadCm, UnidadCm, CantidadUcm, UnidadMm, CantidadMm
        """
        tanque = self.get_object()
        file_obj = request.FILES.get('file')
        nombre = request.data.get('nombre', f"Tabla {tanque.nombre}")
        api = request.data.get('api')
        ajuste_fra = request.data.get('ajuste_fra', 0)
        incremento_fra = request.data.get('incremento_fra', 0)

        if not file_obj:
            return Response({'error': 'No se cargó ningún archivo.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            wb = openpyxl.load_workbook(file_obj, data_only=True)
            sheet = wb.active
            
            # Use transaction to ensure data integrity
            with transaction.atomic():
                # 1. Create the table name record
                tabla_nombre = NombresDeTablas.objects.create(
                    nombre=nombre,
                    tanque=tanque,
                    api=int(api) if api else None,
                    ajuste_fra=float(ajuste_fra) if ajuste_fra else 0.0,
                    incremento_fra=float(incremento_fra) if incremento_fra else 0.0,
                    activa='Si'
                )

                # 2. Deactivate previous tables for this tank if new one is active
                NombresDeTablas.objects.filter(tanque=tanque).exclude(id=tabla_nombre.id).update(activa='No')

                # 3. Parse rows
                # Extract headers to find column indices
                headers = [str(cell.value).strip() if cell.value else "" for cell in sheet[1]]
                col_map = {name: i for i, name in enumerate(headers)}
                
                # Required columns based on legacy code
                required = ['DecenasCm', 'CantidadCm', 'UnidadMm', 'CantidadMm']
                for req in required:
                    if req not in col_map:
                        raise ValueError(f"Falta la columna requerida: {req}")

                aforo_entries = []
                
                # Iterate rows (starting from row 2)
                for row in sheet.iter_rows(min_row=2, values_only=True):
                    # DecenasCm & CantidadCm (Base CM values)
                    # Use index from map
                    idx_dcm = col_map['DecenasCm']
                    idx_ccm = col_map['CantidadCm']
                    
                    if row[idx_dcm] is not None:
                        aforo_entries.append(TablaDeAforo(
                            unidad='Cm',
                            cantidad=int(row[idx_dcm]),
                            barriles=float(row[idx_ccm]),
                            tabla=tabla_nombre
                        ))

                    # MM adjustments (often only first 10 rows or specific range)
                    idx_umm = col_map['UnidadMm']
                    idx_cmm = col_map['CantidadMm']
                    if row[idx_umm] is not None:
                        aforo_entries.append(TablaDeAforo(
                            unidad='Mm',
                            cantidad=int(row[idx_umm]),
                            barriles=float(row[idx_cmm]),
                            tabla=tabla_nombre
                        ))
                    
                    # UCMS (Optional based on legacy code)
                    if 'UnidadCm' in col_map and 'CantidadUcm' in col_map:
                        idx_ucm = col_map['UnidadCm']
                        idx_cuc = col_map['CantidadUcm']
                        if row[idx_ucm] is not None:
                             aforo_entries.append(TablaDeAforo(
                                unidad='Cm', # Both base and units are stored under 'Cm'
                                cantidad=int(row[idx_ucm]),
                                barriles=float(row[idx_cuc]),
                                tabla=tabla_nombre
                            ))

                # 4. Bulk create for performance
                TablaDeAforo.objects.bulk_create(aforo_entries)

            return Response({
                'message': f'Tabla "{nombre}" cargada exitosamente.',
                'records_created': len(aforo_entries)
            }, status=status.HTTP_201_CREATED)

        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=True, methods=['post'], url_path='save-calibration')
    @authentication_classes([])
    @permission_classes([AllowAny])
    def save_calibration(self, request, pk=None):
        """
        Save a pre-parsed calibration table from JSON.
        Expects: 'nombre_tabla', 'api_tabla', 'ajuste_fra', 'incremento_fra', 'registros' (JSON).
        """
        tanque = self.get_object()
        try:
            nombre = request.data.get('nombre_tabla')
            api = request.data.get('api_tabla')
            ajuste_fra = request.data.get('ajuste_fra')
            incremento_fra = request.data.get('incremento_fra')
            registros_raw = request.data.get('registros')
            
            # Handle both raw dict and stringified JSON
            if isinstance(registros_raw, str):
                registros = json.loads(registros_raw)
            else:
                registros = registros_raw

            with transaction.atomic():
                # 1. Create the table master record
                tabla_header = NombresDeTablas.objects.create(
                    nombre=nombre,
                    tanque=tanque,
                    api=int(float(api)) if api else None,
                    ajuste_fra=float(ajuste_fra) if ajuste_fra else 0.0,
                    incremento_fra=float(incremento_fra) if incremento_fra else 0.0,
                    activa='Si'
                )

                # 2. Deactivate previous tables for this tank
                NombresDeTablas.objects.filter(tanque=tanque).exclude(id=tabla_header.id).update(activa='No')

                aforo_entries = []
                
                # 3. Process cms (Base ranges)
                for cm in registros.get('cms', []):
                    if cm.get('DecenasCm') is not None and cm.get('CantidadCm') is not None:
                        aforo_entries.append(TablaDeAforo(
                            unidad='Cm',
                            cantidad=int(cm['DecenasCm']),
                            barriles=float(str(cm['CantidadCm']).replace(',', '')),
                            tabla=tabla_header
                        ))
                
                # 4. Process ucms (Unit adjustments in Cm)
                for cm in registros.get('ucms', []):
                     if cm.get('UnidadCm') is not None and int(cm['UnidadCm']) > 0:
                        aforo_entries.append(TablaDeAforo(
                            unidad='Cm',
                            cantidad=int(cm['UnidadCm']),
                            barriles=float(str(cm['CantidadUcm']).replace(',', '')),
                            tabla=tabla_header
                        ))
                
                # 5. Process umms (Millimeter adjustments)
                for mm in registros.get('umms', []):
                    if mm.get('UnidadMm') is not None:
                        aforo_entries.append(TablaDeAforo(
                            unidad='Mm',
                            cantidad=int(mm['UnidadMm']),
                            barriles=float(str(mm['CantidadMm']).replace(',', '')),
                            tabla=tabla_header
                        ))

                # 6. Bulk create for performance
                TablaDeAforo.objects.bulk_create(aforo_entries)

            return Response({
                'estado': 'guardado',
                'records_created': len(aforo_entries),
                'tabla_id': tabla_header.id
            }, status=status.HTTP_201_CREATED)

        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=True, methods=['post'], url_path='cambiar-api')
    @authentication_classes([])
    @permission_classes([AllowAny])
    def cambiar_api(self, request, pk=None):
        """
        Update the current API of the tank.
        """
        tanque = self.get_object()
        api = request.data.get('api')
        if api is None:
            return Response({'error': 'Falta el valor del API.'}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            tanque.api_actual = float(api)
            tanque.save()
            return Response({'status': True, 'api': tanque.api_actual})
        except ValueError:
            return Response({'error': 'Valor de API inválido.'}, status=status.HTTP_400_BAD_REQUEST)


class StandardResultsSetPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100

class MedicionViewSet(viewsets.ModelViewSet):
    """
    API endpoint that allows Mediciones to be viewed or edited.
    """
    queryset = Medicion.objects.all().order_by('-fecha_hora')
    serializer_class = MedicionSerializer
    pagination_class = StandardResultsSetPagination
    filterset_fields = {
        'tanque': ['exact'],
        'inspector': ['exact', 'icontains'],
        'tipo_medicion': ['exact'],
        'estado': ['exact'],
        'fecha_hora': ['date', 'gte', 'lte'],
    }

    def get_queryset(self):
        return Medicion.objects.filter(activo=True).order_by('-fecha_hora')

    def perform_update(self, serializer):
        if serializer.instance.detallebalance_set.exists():
            raise serializers.ValidationError(
                "No se puede editar una medición que ya hace parte de un balance operativo."
            )
        serializer.save()

    def perform_destroy(self, instance):
        if instance.detallebalance_set.exists():
            raise serializers.ValidationError(
                "No se puede deshabilitar una medición que ya está asociada a un balance operativo."
            )
        instance.activo = False
        instance.save()

    @action(detail=True, methods=['post'], url_path='completar')
    def completar(self, request, pk=None):
        """
        Complete a measurement by providing API and GSW values.
        Transitions estado from REGISTRADA to COMPLETADA and triggers volume calculation.
        """
        medicion = self.get_object()

        if medicion.estado == 'COMPLETADA':
            return Response(
                {'error': 'Esta medición ya fue completada.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = CompletarMedicionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        medicion.api = serializer.validated_data['api']
        medicion.gsw = serializer.validated_data['gsw']
        medicion.estado = 'COMPLETADA'
        medicion.save()  # save() will trigger calcular_volumen()

        return Response(
            MedicionSerializer(medicion).data,
            status=status.HTTP_200_OK,
        )

    @action(detail=True, methods=['get'], url_path='exportar-pdf')
    def exportar_pdf(self, request, pk=None):
        """
        Generate and return a PDF report for the measurement.
        """
        medicion = get_object_or_404(Medicion, pk=pk)
        
        try:
            # Basic validation: ensure we have at least a tank and a product
            if not medicion.tanque or not medicion.producto:
                return Response(
                    {'error': 'La medición debe tener un tanque y un producto asociado para generar el PDF.'},
                    status=status.HTTP_400_BAD_REQUEST
                )
                
            pdf_content = generate_medicion_pdf(pk)
            response = HttpResponse(pdf_content, content_type='application/pdf')
            response['Content-Disposition'] = f'attachment; filename="medicion_{pk}.pdf"'
            return response
        except Exception as e:
            return Response(
                {'error': f'Error al generar el PDF: {str(e)}'},
                status=status.HTTP_400_BAD_REQUEST
            )


class LineaViewSet(viewsets.ModelViewSet):
    """
    API endpoint that allows Lineas to be viewed or edited.
    """
    queryset = Linea.objects.all()
    serializer_class = LineaSerializer

class ClienteViewSet(viewsets.ModelViewSet):
    queryset = Cliente.objects.all()
    serializer_class = ClienteSerializer

class ProductoViewSet(viewsets.ModelViewSet):
    queryset = Producto.objects.all()
    serializer_class = ProductoSerializer

class BalanceDiarioViewSet(viewsets.ModelViewSet):
    queryset = BalanceDiario.objects.all().order_by('-fecha')
    serializer_class = BalanceDiarioSerializer

    def perform_create(self, serializer):
        # When creating a new balance, automatically create detail entries for all tanks
        balance = serializer.save()
        
        # Get the most recent previous balance (if any) to pull initial volumes
        prev_balance = BalanceDiario.objects.filter(fecha__lt=balance.fecha).order_by('-fecha').first()
        
        tanques = Tanque.objects.all()
        for tanque in tanques:
            # 1. Fetch initial volume and previous lines
            volumen_inicial = 0.0
            lineas_anteriores = []
            if prev_balance:
                prev_detalle = DetalleBalance.objects.filter(balance=prev_balance, tanque=tanque).first()
                if prev_detalle:
                    volumen_inicial = prev_detalle.volumen_total
                    lineas_anteriores = list(prev_detalle.lineas.all())
            
            # 2. Try to get the latest completed measurement for this tank today
            last_med = Medicion.objects.filter(
                tanque=tanque, 
                estado='COMPLETADA', 
                fecha_hora__date=balance.fecha
            ).order_by('-fecha_hora').first()
            
            # Use Decimal for initial calc
            vol_tanque = Decimal(str(last_med.nsv or last_med.volumen_calculado or 0)) if last_med else Decimal('0')
            vol_lineas = sum(Decimal(str(l.volumen_tov or 0)) for l in lineas_anteriores)
            
            # Initial detail
            detalle = DetalleBalance.objects.create(
                balance=balance,
                tanque=tanque,
                medicion=last_med,
                volumen_inicial=Decimal(str(volumen_inicial)),
                volumen_tanque=vol_tanque,
                volumen_total=vol_tanque + vol_lineas,
            )
            
            # Assign lines if any
            if lineas_anteriores:
                detalle.lineas.set(lineas_anteriores)

    @action(detail=True, methods=['post'], url_path='cerrar')
    def cerrar(self, request, pk=None):
        balance = self.get_object()
        if balance.estado == 'CERRADO':
            return Response({'error': 'Este balance ya está cerrado.'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Calculate totals from all details using Decimal
        total = Decimal('0')
        detalles = balance.detalles.all()
        for d in detalles:
            total += Decimal(str(d.volumen_total))
        
        balance.total_general = total
        balance.estado = 'CERRADO'
        balance.save()
        
        return Response(BalanceDiarioSerializer(balance).data)

    @action(detail=True, methods=['get'], url_path='exportar-pdf')
    def exportar_pdf(self, request, pk=None):
        """
        Genera y descarga el reporte en PDF del balance.
        """
        try:
            pdf_content = generate_balance_pdf(pk)
            response = HttpResponse(pdf_content, content_type='application/pdf')
            response['Content-Disposition'] = f'attachment; filename="balance_{pk}.pdf"'
            return response
        except Exception as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

class DetalleBalanceViewSet(viewsets.ModelViewSet):
    queryset = DetalleBalance.objects.all()
    serializer_class = DetalleBalanceSerializer

class MedioTransporteViewSet(viewsets.ModelViewSet):
    queryset = MedioTransporte.objects.all()
    serializer_class = MedioTransporteSerializer

class MovimientoTransporteViewSet(viewsets.ModelViewSet):
    queryset = MovimientoTransporte.objects.all()
    serializer_class = MovimientoTransporteSerializer
