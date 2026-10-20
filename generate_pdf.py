import os
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable, KeepTogether
)
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_page_decorations(self, page_count):
        self.saveState()
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#718096"))
        
        # Header (pages > 1)
        if self._pageNumber > 1:
            self.drawString(54, 11 * 72 - 36, "BANAAG: REE Electrical Design & Takeoff Suite")
            self.drawRightString(8.5 * 72 - 54, 11 * 72 - 36, "PEC 2017 Compliant Engine")
            self.setStrokeColor(colors.HexColor("#CBD5E1"))
            self.setLineWidth(0.5)
            self.line(54, 11 * 72 - 42, 8.5 * 72 - 54, 11 * 72 - 42)

        # Footer
        footer_text = f"Page {self._pageNumber} of {page_count}"
        self.drawString(54, 30, "CONFIDENTIAL - For REE Undergrad Electrical Engineering Course Block Rollout")
        self.drawRightString(8.5 * 72 - 54, 30, footer_text)
        self.setStrokeColor(colors.HexColor("#CBD5E1"))
        self.setLineWidth(0.5)
        self.line(54, 40, 8.5 * 72 - 54, 40)
        self.restoreState()

def generate_catalog_pdf(output_path):
    doc = SimpleDocTemplate(
        output_path,
        pagesize=letter,
        leftMargin=54,
        rightMargin=54,
        topMargin=54,
        bottomMargin=54,
    )

    styles = getSampleStyleSheet()

    # Custom styles
    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=20,
        leading=24,
        textColor=colors.HexColor('#0F172A'),
        spaceAfter=4
    )
    
    subtitle_style = ParagraphStyle(
        'DocSubTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=11,
        leading=15,
        textColor=colors.HexColor('#D97706'), # Amber
        spaceAfter=12
    )

    h1_style = ParagraphStyle(
        'SectionH1',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=12,
        leading=16,
        textColor=colors.HexColor('#1E293B'),
        spaceBefore=10,
        spaceAfter=4
    )

    body_style = ParagraphStyle(
        'DocBody',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=13,
        textColor=colors.HexColor('#334155'),
        spaceAfter=4
    )

    badge_style = ParagraphStyle(
        'Badge',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8,
        leading=10,
        textColor=colors.HexColor('#047857')
    )

    story = []

    # Title Banner
    story.append(Paragraph("⚡ BANAAG: Full Engineering & Takeoff Suite", title_style))
    story.append(Paragraph("SPECIFICATION & FEATURE CATALOG (PEC 2017 & REE COURSE STANDARDS)", subtitle_style))
    story.append(HRFlowable(width="100%", thickness=2, color=colors.HexColor('#D97706'), spaceBefore=2, spaceAfter=10))

    meta_text = """
    <b>Target Audience:</b> Registered Electrical Engineering (REE) Undergrad Students & Design Blocks<br/>
    <b>Standard Basis:</b> Philippine Electrical Code (PEC 2017), IESNA Lighting Handbook, Meralco Service Standards<br/>
    <b>Deployment:</b> 100% Offline Android APK (Zero cloud reliance, immediate calculation feedback)
    """
    story.append(Paragraph(meta_text, body_style))
    story.append(Spacer(1, 10))

    features = [
        (
            "1. Plan Takeoff Canvas & Auto-Layout Generator",
            "Auto-generates concrete walls from client hand sketches (supports L-shaped rooms with cutouts and rectangular spaces). "
            "Computes exact floor area (m²) and automatically routes conduit homeruns from appliances to the Main Distribution Panelboard (LP-1). "
            "Produces instant Bill of Materials (BOM) including conduit length, wire length, boxes, clamps, and labor costs."
        ),
        (
            "2. Smart Lighting Sizer Engine (Lumen Method / Zonal Cavity)",
            "Strict Lumen Method formula: Target Lumens = (Area × Lux × Height Factor) / (CU: 0.60 × LLF: 0.80). "
            "Dynamic lamp sizing: 9W (~800 lm) for compact/toilets, 12W (~1,050 lm) for bedrooms, 15W (~1,350 lm), and 18W (~1,700 lm) for large spaces. "
            "Multi-tier lighting: Standard Minimum, Premium Enhanced (LED Cove strip), and Luxury Architectural (Magnetic Track Spotlights). "
            "Enforces PEC Table 2.20.2.3 mandatory minimum general lighting load floor of 24 VA/m²."
        ),
        (
            "3. Core PEC 2017 Calculation & Sizing Engine",
            "Wire sizing via Table 3.10.2.6 (75°C THHN/THWN-2 Copper) with mandatory 125% continuous duty margin (PEC 2.15.1.2). "
            "Guarantees minimum sizes: 2.0 mm² (#14 AWG) for lighting and 3.5 mm² (#12 AWG) for convenience outlets. "
            "Conduit Fill check (PEC Chapter 9 Table 1) enforcing the 40% maximum fill limit for ≥3 conductors. "
            "Single-phase 230V voltage drop calculator warning when exceeding the 3% branch circuit threshold. "
            "Smart Phase Balancer using Greedy LPT algorithm to distribute VA loads between Line 1 and Line 2."
        ),
        (
            "4. PEC Standard Wiring Color Coding Matrix",
            "Comprehensive conductor identification pursuant to PEC Article 2.0.1.6 & Article 2.50.6.10: "
            "Line 1 (Phase A) = Black, Line 2 (Phase B) = Red, Neutral Conductor = White/Light Gray (strictly ungrounded live use prohibited), "
            "Equipment Grounding Conductor (EGC) = Green / Bare Copper, Switch Leg = Yellow, Travelers (3-way/4-way) = Orange/Blue. "
            "Auto-computes required wire rolls/meters per color code based on total conduit layout."
        ),
        (
            "5. Single-Line Diagram (SLD) & Schedule of Loads",
            "Automatic grouping into PEC functional branch circuits with dedicated breaker trips (15A, 20A, 30A, 40A). "
            "Applies exact PEC Table 2.20.3.3 Residential Demand Factors: First 3,000 VA @ 100%, 3,001 to 120,000 VA @ 35%, dedicated motor/ACU @ 100%. "
            "Includes 2 mandatory spare circuits for future expansion. "
            "Sizes Main Circuit Breaker (MCB AT/AF/kAIC rating), feeder conductors, and 16mm Ø × 2.4m copperweld grounding rod."
        ),
        (
            "6. Utility Service Drop Assessment & Calculator",
            "Evaluates overhead distance from utility distribution pole to weatherhead. "
            "Enforces PEC 2.30.2.4 rule: flags intermediate private pole requirement when overhead span exceeds 30 meters to prevent excessive sag. "
            "Assesses roadway crossing vertical clearances: 5.5m (18 ft) over public roads, 4.5m (15 ft) over residential driveways. "
            "Computes #6 AWG Aluminum Duplex Messenger Wire BOM with 3m drip loop connection allowance."
        ),
        (
            "7. Future-Proofing & Modern Systems Hub",
            "Solar PV Net-Metering Sizer (PEC Article 6.90 & ERC rules): Sizing from 1.0 to 10.0 kWp, calculating inverter continuous output current, backfeed breaker, and rapid shutdown requirements. "
            "Electric Vehicle (EV) Charging provision (Level 1/Level 2 AC EVSE). "
            "Smart Home ready neutral-at-switchbox compliance for IoT automation."
        ),
        (
            "8. 7-Stage QA Electrical Gatekeeper & PS/ICC Shield",
            "Step-by-step Quality Assurance gates from Phase 1 (Site Survey & Load Sched) to Phase 7 (Turnover & As-Built Certification). "
            "Mandatory Megger insulation resistance testing checklist (500V DC) and torque verification. "
            "PS/ICC Material Shield benchmarking Philippine certified brands (Phelps Dodge, Columbia, Philflex, Panasonic, Schneider) against counterfeit products."
        ),
        (
            "9. Commercial Suite & Client Needs Analysis",
            "Modular space-by-space client interview wizard estimating total connected kVA and project costing. "
            "Variation Order (VO) tracking, material addendum adjustments, and labor payroll tracking."
        ),
        (
            "10. Built-in Dev Ticket & Feedback System",
            "1-tap in-app ticket logger for bugs, enhancements, feature requests, and engineering notes. "
            "Persistent offline JSON queue enabling rapid student feedback and agile updates during design defense."
        ),
    ]

    for title, desc in features:
        card_content = [
            Paragraph(title, h1_style),
            Paragraph(desc, body_style),
            Spacer(1, 4)
        ]
        
        table = Table(
            [[card_content]],
            colWidths=[504]
        )
        table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#F8FAFC')),
            ('BOX', (0, 0), (-1, -1), 0.75, colors.HexColor('#CBD5E1')),
            ('ROUNDEDCORNERS', [4, 4, 4, 4]),
            ('TOPPADDING', (0, 0), (-1, -1), 6),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
            ('LEFTPADDING', (0, 0), (-1, -1), 10),
            ('RIGHTPADDING', (0, 0), (-1, -1), 10),
        ]))
        story.append(KeepTogether([table, Spacer(1, 6)]))

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"PDF successfully generated at: {output_path}")

if __name__ == '__main__':
    out_dir = r"C:\Users\Varr\.gemini\antigravity\brain\55dcf0ee-ae22-4593-abd9-0ccbd016fcf8"
    out_file = os.path.join(out_dir, "BANAAG_REE_Feature_Catalog.pdf")
    generate_catalog_pdf(out_file)
