from django.contrib import admin
from .models import Tanque, Medicion, Linea, Cliente, Producto, Terminal, NombresDeTablas, TablaDeAforo

admin.site.register(Tanque)
admin.site.register(Medicion)
admin.site.register(Linea)
admin.site.register(Cliente)
admin.site.register(Producto)
admin.site.register(Terminal)
admin.site.register(NombresDeTablas)
admin.site.register(TablaDeAforo)
