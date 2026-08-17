#!/usr/bin/env python3
"""Generate clearly non-official vector logos used by examples and tests."""

from pathlib import Path

from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parent

PAGE_SIZES = {
    "tuc": ((397.299, 199.840), (571.798, 374.333)),
    "tuckhs": ((338.535, 201.818), (600.000, 500.000)),
    "tuckhseng": ((373.232, 201.195), (600.000, 500.000)),
}

TEXT = {
    "tuc": ("DEMO UNIVERSITY", "PLACEHOLDER - NOT OFFICIAL"),
    "tuckhs": ("DEMO CAMPUS 2025", "MUSTERLOGO - NICHT OFFIZIELL"),
    "tuckhseng": ("DEMO CAMPUS 2025", "PLACEHOLDER MARK - NOT OFFICIAL"),
}

COLORS = {
    "black": ((0.06, 0.08, 0.10), (0.06, 0.08, 0.10), (0.06, 0.08, 0.10)),
    "green": ((0.00, 0.36, 0.28), (0.00, 0.36, 0.28), (0.00, 0.36, 0.28)),
    "white": ((1.00, 1.00, 1.00), (1.00, 1.00, 1.00), (1.00, 1.00, 1.00)),
    "color": ((0.00, 0.36, 0.28), (0.92, 0.28, 0.18), (0.12, 0.50, 0.72)),
}


def set_rgb(pdf, color):
    pdf.setFillColorRGB(*color)
    pdf.setStrokeColorRGB(*color)


def set_fitted_font(pdf, font, preferred_size, text, max_width):
    size = preferred_size
    while size > 3.0 and pdf.stringWidth(text, font, size) > max_width:
        size -= 0.2
    pdf.setFont(font, size)


def draw_mark(pdf, primary, accent_a, accent_b):
    """Draw an original abstract mark, deliberately unlike the TUC building."""
    pdf.setLineCap(1)
    pdf.setLineJoin(1)
    pdf.setLineWidth(2.8)
    set_rgb(pdf, accent_a)
    pdf.line(8, 39, 25, 47)
    pdf.line(8, 31, 25, 39)
    set_rgb(pdf, accent_b)
    pdf.line(25, 47, 38, 34)
    pdf.line(25, 39, 38, 26)
    set_rgb(pdf, primary)
    pdf.roundRect(8, 13, 30, 11, 5.5, stroke=1, fill=0)
    pdf.setFont("Helvetica-Bold", 7.2)
    pdf.drawCentredString(23, 16.1, "DEMO")


def draw_logo(path, family, tone, margin):
    page = PAGE_SIZES[family][1 if margin else 0]
    pdf = canvas.Canvas(str(path), pagesize=page, pageCompression=1)
    pdf.setTitle("Generic demo logo - not an official university mark")
    pdf.setAuthor("osglecture project")
    pdf.setSubject("Freely distributable placeholder artwork")

    # A fixed 120 x 60 design coordinate system is scaled uniformly. Margin
    # variants intentionally retain the historic larger page boxes.
    target_w = page[0] * (0.64 if margin else 0.94)
    target_h = page[1] * (0.56 if margin else 0.90)
    scale = min(target_w / 120.0, target_h / 60.0)
    x = (page[0] - 120.0 * scale) / 2.0
    y = (page[1] - 60.0 * scale) / 2.0
    pdf.saveState()
    pdf.translate(x, y)
    pdf.scale(scale, scale)

    primary, accent_a, accent_b = COLORS[tone]
    draw_mark(pdf, primary, accent_a, accent_b)
    title, subtitle = TEXT[family]
    set_rgb(pdf, primary)
    set_fitted_font(pdf, "Helvetica-Bold", 10.5, title, 72.0)
    pdf.drawString(44, 33.5, title)
    set_fitted_font(pdf, "Helvetica", 6.0, subtitle, 72.0)
    pdf.drawString(44, 24.0, subtitle)
    pdf.setLineWidth(1.2)
    pdf.line(44, 19.2, 116, 19.2)
    footer = "FICTIONAL IDENTITY FOR TESTS AND EXAMPLES"
    set_fitted_font(pdf, "Helvetica-Bold", 5.0, footer, 72.0)
    pdf.drawString(44, 12.2, footer)
    pdf.restoreState()
    pdf.showPage()
    pdf.save()


def main():
    for family in PAGE_SIZES:
        tones = ("black", "green", "white") if family == "tuc" else (
            "black", "color", "green", "white"
        )
        for tone in tones:
            for margin in (False, True):
                suffix = "_margin" if margin else ""
                draw_logo(ROOT / f"{family}_{tone}{suffix}.pdf", family, tone, margin)


if __name__ == "__main__":
    main()
