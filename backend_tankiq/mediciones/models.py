from django.db import models
from django.contrib.auth.models import User
from django.core.validators import MinValueValidator, MaxValueValidator
from django.core.exceptions import ValidationError
from django.utils import timezone
from django.db.models import Q
from decimal import Decimal, ROUND_HALF_UP
from .funciones_liquidacion import ctlD, ctl

class Tanque(models.Model):
    nombre = models.CharField(max_length=100, unique=True)
    descripcion = models.TextField(blank=True, null=True)
    capacidad_maxima = models.FloatField(help_text="Capacidad en barriles o litros")
    altura_referencia = models.FloatField(help_text="Altura de referencia del tanque en mm")
    zona_critica_L = models.FloatField(default=0, help_text="Altura de la zona crítica en mm")
    enchaquetamiento = models.BooleanField(default=False, help_text="Indica si el tanque tiene enchaquetamiento")
    requiere_api = models.BooleanField(default=True, help_text="Indica si el cálculo requiere gravedad API")
    api_actual = models.FloatField(null=True, blank=True, help_text="Gravedad API actual del producto en el tanque")
    producto_actual = models.ForeignKey('Producto', on_delete=models.SET_NULL, null=True, blank=True, related_name='tanques_con_producto')

    def __str__(self):
        return self.nombre

class Cliente(models.Model):
    nombre = models.CharField(max_length=100, unique=True)
    contacto = models.CharField(max_length=100, blank=True, null=True)

    def __str__(self):
        return self.nombre

class Producto(models.Model):
    nombre = models.CharField(max_length=100)
    api = models.FloatField(help_text="Gravedad API")
    cliente = models.ForeignKey(Cliente, on_delete=models.CASCADE, related_name='productos')
    es_refinado = models.BooleanField(default=False)
    es_hidrocarburo = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.nombre} ({self.cliente})"

class MedioTransporte(models.Model):
    nombre = models.CharField(max_length=100, unique=True)
    imagen = models.ImageField(upload_to='medios_transporte', null=True, blank=True)
    icono = models.CharField(max_length=50, default='local_shipping', help_text="Nombre del icono de Material Design (ej: 'local_shipping', 'directions_boat')")
    def __str__(self):
        return self.nombre

class NombresDeTablas(models.Model):
    nombre = models.CharField(max_length = 50, null = True)
    tanque = models.ForeignKey(Tanque, null = True, blank = True, on_delete = models.CASCADE, related_name = 'Tanque_nombresTabla')
    api = models.IntegerField(null=True, blank=True)
    ajuste_fra = models.FloatField(null = True, blank = True)
    incremento_fra = models.FloatField(null = True, blank = True)
    activa = models.CharField(max_length = 20, choices = (('Si', 'Si'), ('No', 'No')), default = 'Si')
    def __str__(self):
        return '{} / {} / Tanque: {}'.format(self.id, self.nombre, self.tanque)
    class Meta:
        verbose_name_plural = 'Nombres De Tablas'

class TablaDeAforo(models.Model):
    unidad = models.CharField(max_length = 30, blank = True, choices = (('Cm', 'Cm'),('Mm', 'Mm')))
    cantidad = models.IntegerField(null = True, blank = True)
    barriles = models.FloatField(null = True, blank = True)
    tabla = models.ForeignKey(NombresDeTablas, null = True, blank = True, on_delete = models.CASCADE)
    def __str__(self):
        return 'id: {} /cantidad {} /barriles: {} tabla: {}'.format(self.id,self.cantidad, self.barriles, self.tabla)
    class Meta:
        verbose_name_plural = 'Tablas De Aforo'

class TablaDensidad(models.Model):
    producto = models.ForeignKey(Producto, on_delete=models.CASCADE, related_name='tablas_densidad')
    temperatura = models.IntegerField(help_text="Temperatura en °F (entero)")
    densidad = models.DecimalField(max_digits=10, decimal_places=5, help_text="Densidad en g/ml o kg/m3")

    class Meta:
        verbose_name = "Tabla de Densidad"
        verbose_name_plural = "Tablas de Densidad"
        unique_together = ['producto', 'temperatura']

    def __str__(self):
        return f"{self.producto.nombre} - {self.temperatura}°F: {self.densidad}"

class Medicion(models.Model):
    TIPO_CHOICES = [
        ('VACIO', 'Medición a Vacío'),
        ('FONDO', 'Medición a Fondo'),
    ]

    ESTADO_CHOICES = [
        ('REGISTRADA', 'Registrada'),
        ('COMPLETADA', 'Completada'),
    ]

    tanque = models.ForeignKey(Tanque, on_delete=models.CASCADE, related_name='mediciones')
    operador = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    inspector = models.CharField(max_length=255)
    fecha_hora = models.DateTimeField()
    tipo_medicion = models.CharField(max_length=10, choices=TIPO_CHOICES)
    producto = models.ForeignKey(Producto, on_delete=models.PROTECT, null=True, blank=True)
    
    temperatura_ambiente = models.FloatField(validators=[MinValueValidator(80), MaxValueValidator(135)])
    nivel_automatico = models.IntegerField(validators=[MinValueValidator(0), MaxValueValidator(22000)])
    temperatura_automatica = models.FloatField()

    temp_liquido_superior = models.FloatField(validators=[MinValueValidator(80), MaxValueValidator(135)])
    temp_liquido_media = models.FloatField(null=True, blank=True, validators=[MinValueValidator(80), MaxValueValidator(135)])
    temp_liquido_inferior = models.FloatField(null=True, blank=True, validators=[MinValueValidator(80), MaxValueValidator(135)])
    temperatura_producto = models.FloatField(null=True, blank=True, validators=[MinValueValidator(80), MaxValueValidator(135)])

    lectura_1_cinta_o_nivel = models.IntegerField()
    lectura_1_plomada = models.IntegerField(null=True, blank=True)
    lectura_2_cinta_o_nivel = models.IntegerField()
    lectura_2_plomada = models.IntegerField(null=True, blank=True)
    lectura_3_cinta_o_nivel = models.IntegerField(null=True, blank=True)
    lectura_3_plomada = models.IntegerField(null=True, blank=True)

    nivel_calculado_final = models.FloatField(editable=False, null=True, blank=True)
    estado = models.CharField(max_length=15, choices=ESTADO_CHOICES, default='REGISTRADA')
    api = models.FloatField(null=True, blank=True, help_text="Gravedad API Observada")
    api_60 = models.FloatField(null=True, blank=True, editable=False, help_text="Gravedad API corregida a 60°F")
    gsw = models.FloatField(null=True, blank=True)
    activo = models.BooleanField(default=True)
    volumen_calculado = models.FloatField(editable=False, null=True, blank=True)
    
    tov = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True, editable=False)
    gov = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True, editable=False)
    gsv = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True, editable=False)
    nsv = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True, editable=False)
    ctsh_factor = models.DecimalField(max_digits=10, decimal_places=5, null=True, blank=True, editable=False)
    ctl_factor = models.DecimalField(max_digits=10, decimal_places=5, null=True, blank=True, editable=False)
    fra_valor = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True, editable=False)

    class Meta:
        verbose_name = "Medición"
        verbose_name_plural = "Mediciones"
        ordering = ['-fecha_hora']
    def __str__(self):
        return f"{self.tanque} - {self.fecha_hora} - ID: {self.id}"
    def calcular_volumen(self):
        v = self.nsv_calc()
        if v is not None:
            self.volumen_calculado = v
        return self.volumen_calculado
    def calcular_temperatura_promedio(self):
        """
        Calculate average product temperature from three layers.
        """
        temps = [t for t in [self.temp_liquido_superior, self.temp_liquido_media, self.temp_liquido_inferior] if t is not None]
        if temps:
            self.temperatura_producto = sum(temps) / len(temps)
        else:
            self.temperatura_producto = self.temp_liquido_superior or 0
        return self.temperatura_producto

    def clean(self):
        """
        Custom data validation for measurements.
        """
        # 1. Date Validation
        if self.fecha_hora and self.fecha_hora > timezone.now() + timezone.timedelta(minutes=5):
            raise ValidationError({'fecha_hora': 'La fecha y hora no puede ser futura.'})

        # 2. Type-specific Validation
        if self.tipo_medicion == 'VACIO':
            if self.lectura_1_plomada is None:
                raise ValidationError({'lectura_1_plomada': 'Para mediciones a VACÍO, la plomada 1 es obligatoria.'})
            if self.lectura_2_plomada is None:
                 raise ValidationError({'lectura_2_plomada': 'Para mediciones a VACÍO, la plomada 2 es obligatoria.'})
                 
        # 3. Temperature Validation (Basic consistency)
        if self.temp_liquido_superior is not None and self.temp_liquido_inferior is not None:
             if abs(self.temp_liquido_superior - self.temp_liquido_inferior) > 10:
                 # Standard warning or error? Let's make it a warning in logs, but keep validation loose unless requested.
                 # For now, let's just ensure they are within ranges (already done by validators).
                 pass

    def save(self, *args, **kwargs):
        self.full_clean() # Trigger clean() during save
        if not self.producto and self.tanque.producto_actual:
            self.producto = self.tanque.producto_actual
        
        lecturas = [self.lectura_1_cinta_o_nivel, self.lectura_2_cinta_o_nivel]
        if self.lectura_3_cinta_o_nivel is not None: lecturas.append(self.lectura_3_cinta_o_nivel)
        avg = sum(lecturas) / len(lecturas)
        
        if self.tipo_medicion == 'VACIO':
            self.nivel_calculado_final = self.tanque.altura_referencia - avg
        else:
            self.nivel_calculado_final = avg

        if self.estado == 'COMPLETADA' and self.api is not None and self.gsw is not None:
            self.tov = Decimal(str(self.tov_calc() or 0))
            self.ctsh_factor = Decimal(str(self.ctsh_calc() or 1))
            self.fra_valor = Decimal(str(self.fra_calc() or 0))
            self.ctl_factor = Decimal(str(self.ctl_calc() or 1))
            self.api_60 = self.api_calc()
            self.gov = Decimal(str(self.gov_calc() or 0))
            self.gsv = Decimal(str(self.gsv_calc() or 0))
            self.nsv = Decimal(str(self.nsv_calc() or 0))
            self.volumen_calculado = float(self.nsv)
        
        self.calcular_temperatura_promedio()
        super().save(*args, **kwargs)

    def tabla(self):
        tanque = self.tanque
        if not tanque.requiere_api:
            return NombresDeTablas.objects.filter(tanque=tanque).last()
        api = float(self.api or 0)
        try:
            inf = NombresDeTablas.objects.filter(api__lte=api, tanque=tanque).order_by('-api').first()
            sup = NombresDeTablas.objects.filter(api__gte=api, tanque=tanque).order_by('api').first()
            if sup and not inf: return sup
            if inf and not sup: return inf
            if sup and inf:
                return sup if abs(float(sup.api)-api) <= abs(float(inf.api)-api) else inf
        except: pass
        return None

    def tov_calc(self):
        try:
            nivel = str(int(self.nivel_calculado_final))
            tabla = self.tabla()
            cms = int(nivel[:-2]) * 10 if len(nivel) > 2 else 0
            obj_cms = TablaDeAforo.objects.get(Q(unidad='Cm') & Q(cantidad=cms) & Q(tabla=tabla))
            b_cms = obj_cms.barriles
            if len(nivel) > 1:
                ucms = int(nivel[-2])
                b_ucms = 0
                if ucms != 0:
                    obj_ucms = TablaDeAforo.objects.get(Q(unidad='Cm') & Q(cantidad=ucms) & Q(tabla=tabla))
                    b_ucms = obj_ucms.barriles
            else:
                b_ucms = 0
            if len(nivel) > 0 and int(nivel) > 0:
                mm = int(nivel[-1])
                obj_mm = TablaDeAforo.objects.get(Q(unidad='Mm') & Q(cantidad=mm) & Q(tabla=tabla))
                b_mm = obj_mm.barriles
            else:
                b_mm = 0
            tov = b_cms + b_ucms + b_mm
            tov = round(tov, 2)
        except:
            tov = 0
        return tov
    

    def tsh_calc(self):
        tp = Decimal(str(self.calcular_temperatura_promedio() or 0))
        ta = Decimal(str(self.temperatura_ambiente or 0))
        tsh = tp if self.tanque.enchaquetamiento else (Decimal('7') * tp + ta) / Decimal('8')
        return float(tsh.quantize(Decimal('0'), ROUND_HALF_UP))

    def ctsh_calc(self):
        tsh = Decimal(str(self.tsh_calc()))
        d = tsh - Decimal('60')
        val = Decimal('1') + (Decimal('0.0000124') * d) + (Decimal('0.0000000000384') * (d**2))
        return float(val.quantize(Decimal('0.00001'), ROUND_HALF_UP))

    def ctl_calc(self):
        try:
            tp = float(self.calcular_temperatura_promedio() or 0)
            api = float(self.api or 0)
            if getattr(self.producto, 'es_hidrocarburo', True):
                return float(ctlD(api, tp, 'B') if getattr(self.producto, 'es_refinado', False) else ctl(api, tp))
            return 1.0
        except: return 1.0

    def api_calc(self):
        try:
            api = Decimal(str(self.api or 0))
            ctl_v = Decimal(str(self.ctl_calc()))
            c = (Decimal('141.5') / (Decimal('131.5') + api)) * Decimal('999.016')
            apio = Decimal('141.5') / ((c * ctl_v) / Decimal('999.016')) - Decimal('131.5')
            return float(apio.quantize(Decimal('0.1'), ROUND_HALF_UP))
        except: return 0.0

    def fra_calc(self):
        try:
            lvl = Decimal(str(self.nivel_calculado_final or 0))
            tbl = self.tabla()
            if tbl and lvl > Decimal(str(self.tanque.zona_critica_L)):
                apio = Decimal(str(self.api_60 or self.api_calc()))
                val = (Decimal(str(tbl.ajuste_fra or 0)) - apio) * Decimal(str(tbl.incremento_fra or 0))
                return float(val.quantize(Decimal('0.01'), ROUND_HALF_UP))
        except: pass
        return 0.0

    def gov_calc(self):
        try:
            tov = Decimal(str(self.tov_calc()))
            ctsh = Decimal(str(self.ctsh_calc()))
            fra = Decimal(str(self.fra_calc()))
            return float((tov * ctsh + fra).quantize(Decimal('0.01'), ROUND_HALF_UP))
        except: return 0.0

    def gsv_calc(self):
        try:
            gov = Decimal(str(self.gov_calc()))
            ctl_v = Decimal(str(self.ctl_calc()))
            return float((gov * ctl_v).quantize(Decimal('0.01'), ROUND_HALF_UP))
        except: return 0.0

    def nsv_calc(self):
        try:
            gsv = Decimal(str(self.gsv_calc()))
            sw = Decimal(str(self.gsw or 0))
            return float((gsv * (Decimal('1') - sw/Decimal('100'))).quantize(Decimal('0.01'), ROUND_HALF_UP))
        except: return 0.0

    def densidad_quimico(self):
        try:
            temp = int(round(float(self.calcular_temperatura_promedio() or 0)))
            return float(TablaDensidad.objects.get(producto=self.producto, temperatura=temp).densidad)
        except: return 1.0

class Linea(models.Model):
    nombre = models.CharField(max_length=100)
    tanque = models.ForeignKey(Tanque, on_delete=models.CASCADE, related_name='lineas', null=True, blank=True)
    volumen_tov = models.DecimalField(max_digits=12, decimal_places=2, help_text="Total Observed Volume de la línea")
    def __str__(self):
        return f"{self.nombre} ({self.tanque})"

class BalanceDiario(models.Model):
    ESTADO_CHOICES = [('BORRADOR', 'En Progreso'), ('CERRADO', 'Confirmado / Cerrado')]
    fecha = models.DateField(unique=True)
    estado = models.CharField(max_length=15, choices=ESTADO_CHOICES, default='BORRADOR')
    total_general = models.DecimalField(max_digits=15, decimal_places=2, default=0.0)
    creado_en = models.DateTimeField(auto_now_add=True)
    actualizado_en = models.DateTimeField(auto_now=True)
    def __str__(self): return f"Balance {self.fecha}"

class DetalleBalance(models.Model):
    balance = models.ForeignKey(BalanceDiario, on_delete=models.CASCADE, related_name='detalles')
    tanque = models.ForeignKey(Tanque, on_delete=models.PROTECT, null=True, blank=True)
    medicion = models.ForeignKey(Medicion, on_delete=models.SET_NULL, null=True, blank=True)
    lineas = models.ManyToManyField(Linea, blank=True)
    volumen_inicial = models.DecimalField(max_digits=12, decimal_places=2, default=0.0)
    volumen_tanque = models.DecimalField(max_digits=12, decimal_places=2, default=0.0)
    volumen_total = models.DecimalField(max_digits=12, decimal_places=2, default=0.0)
    class Meta: unique_together = ['balance', 'tanque']

class MovimientoTransporte(models.Model):
    detalle_balance = models.ForeignKey(DetalleBalance, on_delete=models.CASCADE, related_name='transportes')
    medio_transporte = models.ForeignKey(MedioTransporte, on_delete=models.PROTECT)
    cantidad = models.DecimalField(max_digits=12, decimal_places=2)

class Terminal(models.Model):
    nombre = models.CharField(max_length=255)
    nit = models.CharField(max_length=50)
    logo = models.ImageField(upload_to='terminal_logos', null=True, blank=True)
    direccion = models.TextField()
    telefono = models.CharField(max_length=50)
    email = models.EmailField()
    def __str__(self): return self.nombre
