import io
from django.conf import settings
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, Image
from reportlab.lib.units import inch
from .models import Terminal, BalanceDiario, DetalleBalance, Medicion

def generate_balance_pdf(balance_id):
    balance = BalanceDiario.objects.get(id=balance_id)
    detalles = balance.detalles.all().select_related('tanque', 'medicion', 'medicion__producto')
    terminal = Terminal.objects.first()

    buffer = io.BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=letter, rightMargin=30, leftMargin=30, topMargin=40, bottomMargin=40)
    elements = []

    styles = getSampleStyleSheet()
    
    # Custom styles
    title_style = ParagraphStyle('Title', parent=styles['Heading1'], fontSize=18, textColor=colors.HexColor("#1e293b"), alignment=1, spaceAfter=8)
    subtitle_style = ParagraphStyle('Subtitle', parent=styles['Normal'], fontSize=10, textColor=colors.grey, alignment=1, spaceAfter=20)
    company_name_style = ParagraphStyle('CompanyName', parent=styles['Heading2'], fontSize=14, textColor=colors.HexColor("#0f172a"), spaceAfter=2)
    company_info_style = ParagraphStyle('CompanyInfo', parent=styles['Normal'], fontSize=9, textColor=colors.HexColor("#475569"), leading=11)
    subtotal_style = ParagraphStyle('Subtotal', parent=styles['Normal'], fontSize=8, fontName='Helvetica-Bold', textColor=colors.HexColor("#334155"), alignment=1)
    total_text_style = ParagraphStyle('TotalText', parent=styles['Normal'], fontSize=10, fontName='Helvetica-Bold', textColor=colors.black, alignment=2)

    # --- Header ---
    logo_path = None
    if terminal and terminal.logo:
        try: logo_path = terminal.logo.path
        except: pass
            
    if logo_path:
        img = Image(logo_path, width=1.1*inch, height=0.55*inch, kind='proportional')
        company_col = [
            Paragraph(terminal.nombre or "TankIQ Terminal", company_name_style),
            Paragraph(f"NIT: {terminal.nit or ''}", company_info_style),
            Paragraph(f"{terminal.direccion or ''}", company_info_style),
            Paragraph(f"Tel: {terminal.telefono or ''} | {terminal.email or ''}", company_info_style),
        ]
        header_table = Table([[img, company_col]], colWidths=[1.5*inch, 5.5*inch])
    else:
        company_col = [
            Paragraph(terminal.nombre or "TankIQ Terminal", company_name_style),
            Paragraph(f"NIT: {terminal.nit or ''}", company_info_style),
            Paragraph(f"{terminal.direccion or ''}", company_info_style),
            Paragraph(f"Tel: {terminal.telefono or ''} | {terminal.email or ''}", company_info_style),
        ]
        header_table = Table([[company_col]], colWidths=[7*inch])

    header_table.setStyle(TableStyle([('VALIGN', (0, 0), (-1, -1), 'MIDDLE'), ('ALIGN', (0, 0), (0, 0), 'LEFT')]))
    elements.append(header_table)
    elements.append(Spacer(1, 0.3*inch))

    # --- Title ---
    elements.append(Paragraph("REPORTE DE BALANCE DIARIO", title_style))
    elements.append(Paragraph(f"Fecha: {balance.fecha.strftime('%d/%m/%Y')}", subtitle_style))

    # --- Table Assembly ---
    headers = ["Tanque", "Producto", "V. Inicial", "V. Tanque", "Movm (Medio: Cant)", "Balance", "Vol. Total"]
    data = [headers]
    
    # Styling tracking
    style_commands = [
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#004b6b")),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, 0), 9),
        ('BOTTOMPADDING', (0, 0), (-1, 0), 10),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('ALIGN', (0, 1), (-1, -1), 'CENTER'),
        ('FONTSIZE', (0, 1), (-1, -1), 7.5),
    ]

    # Group by Product
    by_product = {}
    for d in detalles:
        prod_name = d.medicion.producto.nombre if d.medicion and d.medicion.producto else "SIN PRODUCTO"
        if prod_name not in by_product: by_product[prod_name] = []
        by_product[prod_name].append(d)

    row_idx = 1
    for prod_name, product_detalles in by_product.items():
        # Optional: Add section header row? User image doesnt show it, but it groupings tanks.
        # Let's just iterate and add subtotal at the end of the product group.
        
        prod_initial_total = 0.0
        prod_volume_total = 0.0
        
        for d in product_detalles:
            transportes = list(d.transportes.all().select_related('medio_transporte'))
            total_transporte = sum(float(t.cantidad) for t in transportes)
            cambio_fisico = float(d.volumen_tanque) - float(d.volumen_inicial)
            bal_operativo = cambio_fisico - total_transporte
            
            initial_v = float(d.volumen_inicial)
            tank_v = float(d.volumen_tanque)
            total_v = float(d.volumen_total)
            
            prod_initial_total += initial_v
            prod_volume_total += total_v

            # Generate rows for this tank
            num_rows = max(1, len(transportes))
            for i in range(num_rows):
                if i == 0:
                    # First row has all main data
                    move_text = f"{transportes[0].medio_transporte.nombre}: {float(transportes[0].cantidad):,.2f}" if transportes else "N/A"
                    data.append([
                        d.tanque.nombre,
                        prod_name,
                        f"{initial_v:,.2f}",
                        f"{tank_v:,.2f}",
                        move_text,
                        f"{bal_operativo:,.2f}",
                        f"{total_v:,.2f}"
                    ])
                else:
                    # Secondary rows for other movements
                    move_text = f"{transportes[i].medio_transporte.nombre}: {float(transportes[i].cantidad):,.2f}"
                    data.append(["", "", "", "", move_text, "", ""])
                
                # Apply background color per tank section toggle
                if len(product_detalles) % 2 == 0: # Simple toggle logic could be improved
                     style_commands.append(('BACKGROUND', (0, row_idx), (-1, row_idx), colors.HexColor("#f8fafc")))
                
                row_idx += 1

        # Product Subtotal Row
        data.append(["", "", Paragraph(f"<b>Subtotal: {prod_volume_total:,.2f}</b>", subtotal_style), "", "", "", ""])
        style_commands.append(('BACKGROUND', (0, row_idx), (-1, row_idx), colors.HexColor("#f1f5f9")))
        style_commands.append(('SPAN', (2, row_idx), (3, row_idx)))
        row_idx += 1

    # Main Table build
    table = Table(data, colWidths=[0.85*inch, 1.1*inch, 0.95*inch, 0.95*inch, 2.1*inch, 0.85*inch, 0.95*inch])
    table.setStyle(TableStyle(style_commands))
    elements.append(table)
    elements.append(Spacer(1, 0.3*inch))

    # --- Summary ---
    summary_data = [[Paragraph(f"<b>Total General de Planta:</b> {balance.total_general:,.2f} BBL/L", total_text_style)]]
    summary_table = Table(summary_data, colWidths=[7.7*inch])
    summary_table.setStyle(TableStyle([('ALIGN', (0, 0), (-1, -1), 'RIGHT'), ('RIGHTPADDING', (0, 0), (-1, -1), 0)]))
    elements.append(summary_table)

    # --- Footer ---
    from datetime import datetime
    elements.append(Spacer(1, 0.8*inch))
    ts = datetime.now().strftime('%d/%m/%Y %H:%M:%S')
    elements.append(Paragraph(f"Generado el {ts} - TankIQ Terminal Management System", ParagraphStyle('Footer', parent=styles['Normal'], fontSize=8, textColor=colors.grey, alignment=1)))

    doc.build(elements)
    pdf = buffer.getvalue()
    buffer.close()
    return pdf

def generate_medicion_pdf(medicion_id):
    medicion = Medicion.objects.select_related('tanque', 'producto').get(id=medicion_id)
    terminal = Terminal.objects.first()

    buffer = io.BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=letter, rightMargin=40, leftMargin=40, topMargin=40, bottomMargin=40)
    elements = []

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        'TitleStyle',
        parent=styles['Heading1'],
        fontSize=18,
        textColor=colors.HexColor("#1E293B"),
        spaceAfter=12,
        alignment=1 # Center
    )
    
    section_style = ParagraphStyle(
        'SectionStyle',
        parent=styles['Heading2'],
        fontSize=12,
        textColor=colors.HexColor("#F27E26"),
        spaceBefore=10,
        spaceAfter=6
    )

    company_name_style = ParagraphStyle(
        'CompanyName',
        parent=styles['Heading2'],
        fontSize=14,
        textColor=colors.HexColor("#0F172A"),
        spaceAfter=2
    )
    
    company_info_style = ParagraphStyle(
        'CompanyInfo',
        parent=styles['Normal'],
        fontSize=9,
        textColor=colors.HexColor("#475569"),
        leading=11
    )

    # --- Header ---
    header_data = []
    logo_path = None
    if terminal and terminal.logo:
        try:
            logo_path = terminal.logo.path
        except:
            pass
            
    if logo_path:
        img = Image(logo_path, width=1.2*inch, height=0.6*inch, kind='proportional')
        company_col = [
            Paragraph(terminal.nombre if terminal else "TankIQ Terminal", company_name_style),
            Paragraph(f"NIT: {terminal.nit}" if terminal else "", company_info_style),
            Paragraph(f"{terminal.direccion}" if terminal else "", company_info_style),
            Paragraph(f"Tel: {terminal.telefono} | {terminal.email}" if terminal else "", company_info_style),
        ]
        header_table = Table([[img, company_col]], colWidths=[1.5*inch, 4.5*inch])
    else:
        company_col = [
            Paragraph(terminal.nombre if terminal else "TankIQ Terminal", company_name_style),
            Paragraph(f"NIT: {terminal.nit}" if terminal else "", company_info_style),
            Paragraph(f"{terminal.direccion}" if terminal else "", company_info_style),
            Paragraph(f"Tel: {terminal.telefono} | {terminal.email}" if terminal else "", company_info_style),
        ]
        header_table = Table([[company_col]], colWidths=[6*inch])

    header_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('ALIGN', (0, 0), (0, 0), 'LEFT'),
    ]))
    elements.append(header_table)
    elements.append(Spacer(1, 0.3*inch))

    # --- Title ---
    elements.append(Paragraph(f"REPORTE DE MEDICIÓN #{medicion.id}", title_style))
    elements.append(Paragraph(f"Fecha: {medicion.fecha_hora.strftime('%d/%m/%Y %H:%M')}", ParagraphStyle('DateStyle', parent=styles['Normal'], alignment=1, textColor=colors.grey, fontSize=10)))
    elements.append(Spacer(1, 0.2*inch))

    # --- Information Table ---
    operador_nombre = "N/A"
    if medicion.operador:
        operador_nombre = medicion.operador.get_full_name() or medicion.operador.username

    info_data = [
        [Paragraph("<b>Tanque:</b>", styles['Normal']), medicion.tanque.nombre, Paragraph("<b>Producto:</b>", styles['Normal']), medicion.producto.nombre if medicion.producto else "N/A"],
        [Paragraph("<b>Tipo:</b>", styles['Normal']), medicion.tipo_medicion, Paragraph("<b>Estado:</b>", styles['Normal']), medicion.estado],
        [Paragraph("<b>Inspector:</b>", styles['Normal']), medicion.inspector, Paragraph("<b>Operador:</b>", styles['Normal']), operador_nombre],
    ]
    info_table = Table(info_data, colWidths=[1*inch, 2*inch, 1*inch, 2*inch])
    info_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
    ]))
    elements.append(info_table)
    elements.append(Spacer(1, 0.2*inch))

    # --- Levels & API Section ---
    elements.append(Paragraph("Datos de Nivel y Gravedad API", section_style))
    
    levels_data = [
        ["Parámetro", "Lectura 1", "Lectura 2", "Lectura 3", "Final"],
        ["Cinta / Nivel (mm)", medicion.lectura_1_cinta_o_nivel, medicion.lectura_2_cinta_o_nivel or "-", medicion.lectura_3_cinta_o_nivel or "-", f"{medicion.nivel_calculado_final if medicion.nivel_calculado_final is not None else 0:,.1f}"],
        ["Plomada (mm)", medicion.lectura_1_plomada or "-", medicion.lectura_2_plomada or "-", medicion.lectura_3_plomada or "-", "-"],
        ["API Observado", f"{medicion.api if medicion.api is not None else 0:,.1f}", "-", "-", f"API 60°F: {medicion.api_60 if medicion.api_60 is not None else 0:,.1f}"],
        ["G.S.W (mm)", f"{medicion.gsw if medicion.gsw is not None else 0:,.1f}", "-", "-", f"{medicion.gsw if medicion.gsw is not None else 0:,.1f}"],
    ]
    
    levels_table = Table(levels_data, colWidths=[1.5*inch, 1.1*inch, 1.1*inch, 1.1*inch, 1.2*inch])
    levels_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#F27E26")),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor("#F9FAFB")]),
    ]))
    elements.append(levels_table)
    elements.append(Spacer(1, 0.2*inch))

    # --- Calculated Volumes ---
    elements.append(Paragraph("Cálculos de Volumen (BBL / L)", section_style))
    
    vol_data = [
        ["Concepto", "Valor", "Factor / Nota"],
        ["TOV (Total Observed)", f"{medicion.tov if medicion.tov is not None else 0:,.2f}", "Volumen Bruto Observado"],
        ["GSV (Gross Standard)", f"{medicion.gsv if medicion.gsv is not None else 0:,.2f}", f"CTL: {medicion.ctl_factor if medicion.ctl_factor is not None else 1:,.5f}"],
        ["NSV (Net Standard)", f"{medicion.nsv if medicion.nsv is not None else 0:,.2f}", f"CTSH: {medicion.ctsh_factor if medicion.ctsh_factor is not None else 1:,.5f}"],
        ["Agua / Sedimento", f"{medicion.fra_valor if medicion.fra_valor is not None else 0:,.2f}", "Deducción FRA / GSW"],
        ["VOLUMEN FINAL", f"{medicion.volumen_calculado if medicion.volumen_calculado is not None else 0:,.2f}", "Volumen Neto Balance"],
    ]
    
    vol_table = Table(vol_data, colWidths=[2.5*inch, 1.5*inch, 2*inch])
    vol_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#1E293B")),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (1, 1), (1, -1), 'RIGHT'),
        ('ALIGN', (0, 0), (0, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
        ('BACKGROUND', (0, 5), (-1, 5), colors.HexColor("#FEF3E9")),
        ('FONTNAME', (0, 5), (-1, 5), 'Helvetica-Bold'),
    ]))
    elements.append(vol_table)

    # --- Footer ---
    from datetime import datetime
    elements.append(Spacer(1, 1*inch))
    footer_text = f"Resumen de Medición - Generado el {datetime.now().strftime('%d/%m/%Y %H:%M:%S')} - TankIQ System"
    elements.append(Paragraph(footer_text, ParagraphStyle('Footer', parent=styles['Normal'], fontSize=8, textColor=colors.grey, alignment=1)))

    doc.build(elements)
    pdf = buffer.getvalue()
    buffer.close()
    return pdf
