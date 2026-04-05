from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'tanques', views.TanqueViewSet)
router.register(r'mediciones', views.MedicionViewSet)
router.register(r'lineas', views.LineaViewSet)
router.register(r'clientes', views.ClienteViewSet)
router.register(r'productos', views.ProductoViewSet)
router.register(r'balances', views.BalanceDiarioViewSet)
router.register(r'balance-detalles', views.DetalleBalanceViewSet)
router.register(r'medios-transporte', views.MedioTransporteViewSet)
router.register(r'movimientos-transporte', views.MovimientoTransporteViewSet)

urlpatterns = [
    path('', include(router.urls)),
]
