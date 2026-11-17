import os
from PIL import Image
from docx import Document
from docx.enum.section import WD_ORIENT, WD_SECTION
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

IMG = r"C:\tmp\arqui\doc_img"
os.makedirs(IMG, exist_ok=True)

# ---------------- imagenes ----------------
cu56 = Image.open(r"C:\tmp\arqui\png_prop3\replicar_y_patron.png").convert("RGB")
cu8 = Image.open(r"C:\tmp\arqui\png_prop14\cu8_cor.png").convert("RGB")
cu56.save(os.path.join(IMG, "cu56.png"))
cu8.save(os.path.join(IMG, "cu8.png"))
def recortar_zona(im, destino, margen=25):
    """Recorta la zona lila del patron: caja que contiene los pixeles del color de la zona."""
    px = im.load(); w, h = im.size
    xs, ys = [], []
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            r, g, b = px[x, y]
            if abs(r - 230) < 4 and abs(g - 220) < 4 and abs(b - 250) < 4:
                xs.append(x); ys.append(y)
    caja = (max(min(xs) - margen, 0), max(min(ys) - margen, 0), min(max(xs) + margen, w), min(max(ys) + margen, h))
    im.crop(caja).save(destino)
    return caja


print("zona CU5_CU6", recortar_zona(cu56, os.path.join(IMG, "cu56_zona.png")))
print("zona CU8", recortar_zona(cu8, os.path.join(IMG, "cu8_zona.png")))
for n in ("gen_strategy", "gen_cor"):
    Image.open(rf"C:\tmp\arqui\png_prop14\{n}.png").convert("RGB").save(os.path.join(IMG, n + ".png"))

doc = Document()

# ---------------- estilos ----------------
st = doc.styles["Normal"]
st.font.name = "Times New Roman"; st.font.size = Pt(12)
st.element.rPr.rFonts.set(qn("w:eastAsia"), "Times New Roman")
for nombre, tam in (("Heading 1", 14), ("Heading 2", 13), ("Heading 3", 14)):
    h = doc.styles[nombre]
    h.font.name = "Arial"; h.font.size = Pt(tam); h.font.bold = True; h.font.color.rgb = RGBColor(0, 0, 0)
    h.element.rPr.rFonts.set(qn("w:eastAsia"), "Arial")
    h.paragraph_format.space_before = Pt(12); h.paragraph_format.space_after = Pt(6)


def configurar(sec, horizontal=False, margen=2.54):
    if horizontal:
        sec.orientation = WD_ORIENT.LANDSCAPE
        sec.page_width, sec.page_height = Cm(27.94), Cm(21.59)
    else:
        sec.orientation = WD_ORIENT.PORTRAIT
        sec.page_width, sec.page_height = Cm(21.59), Cm(27.94)
    sec.left_margin = sec.right_margin = Cm(margen)
    sec.top_margin = sec.bottom_margin = Cm(margen)


def parrafo(texto="", negrita=False, cursiva=False, tam=None, alin=None, fuente=None, espacio_despues=None):
    p = doc.add_paragraph()
    if texto:
        r = p.add_run(texto); r.bold = negrita; r.italic = cursiva
        if tam: r.font.size = Pt(tam)
        if fuente:
            r.font.name = fuente; r._element.rPr.rFonts.set(qn("w:eastAsia"), fuente)
    if alin is not None: p.alignment = alin
    if espacio_despues is not None: p.paragraph_format.space_after = Pt(espacio_despues)
    return p


def imagen(ruta, ancho_cm, alto_max_cm=None):
    w, h = Image.open(ruta).size
    ancho = ancho_cm
    if alto_max_cm and ancho * h / w > alto_max_cm:
        ancho = alto_max_cm * w / h
    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.add_run().add_picture(ruta, width=Cm(ancho))
    p.paragraph_format.space_after = Pt(4)
    return p


def cita(titulo_libro):
    p = doc.add_paragraph()
    p.paragraph_format.left_indent = Cm(1.27); p.paragraph_format.first_line_indent = Cm(-1.27)
    p.add_run("Shvets, A. (2021). ")
    r = p.add_run(titulo_libro); r.italic = True
    p.add_run(". Refactoring.Guru.")
    return p


def sombrear(celda, color):
    tcPr = celda._tc.get_or_add_tcPr()
    sh = OxmlElement("w:shd"); sh.set(qn("w:val"), "clear"); sh.set(qn("w:color"), "auto"); sh.set(qn("w:fill"), color)
    tcPr.append(sh)


def tabla_roles(filas):
    t = doc.add_table(rows=1, cols=3); t.style = "Table Grid"; t.alignment = WD_TABLE_ALIGNMENT.CENTER
    for i, tx in enumerate(("Rol en el patrón", "Clase en el sistema", "Archivo")):
        c = t.rows[0].cells[i]; c.text = ""; r = c.paragraphs[0].add_run(tx); r.bold = True; r.font.size = Pt(9); r.font.name = "Arial"
        sombrear(c, "D9D9D9")
    for fila in filas:
        cs = t.add_row().cells
        for i, tx in enumerate(fila):
            cs[i].text = ""; r = cs[i].paragraphs[0].add_run(tx); r.font.size = Pt(9); r.font.name = "Arial"
    for fila in t.rows:
        for i, ancho in enumerate((4.2, 8.0, 12.7)):
            fila.cells[i].width = Cm(ancho)
    return t


def campo_toc(parrafo_toc):
    r = parrafo_toc.add_run()
    for tipo, texto in (("begin", None), (None, ' TOC \\o "1-2" \\h \\z \\u '), ("separate", None), (None, "Actualiza este índice (clic derecho → Actualizar campo)."), ("end", None)):
        if tipo:
            e = OxmlElement("w:fldChar"); e.set(qn("w:fldCharType"), tipo); r._r.append(e)
        elif texto and texto.startswith(" TOC"):
            e = OxmlElement("w:instrText"); e.set(qn("xml:space"), "preserve"); e.text = texto; r._r.append(e)
        else:
            e = OxmlElement("w:t"); e.text = texto; r._r.append(e)


# ---------------- portada ----------------
s0 = doc.sections[0]; configurar(s0)
parrafo("[NOMBRE DE LA UNIVERSIDAD]", True, tam=14, alin=WD_ALIGN_PARAGRAPH.CENTER, fuente="Arial", espacio_despues=2)
parrafo("FACULTAD DE INGENIERÍA EN CIENCIAS DE LA", True, tam=14, alin=WD_ALIGN_PARAGRAPH.CENTER, fuente="Arial", espacio_despues=2)
parrafo("COMPUTACIÓN Y TELECOMUNICACIONES", True, tam=14, alin=WD_ALIGN_PARAGRAPH.CENTER, fuente="Arial")
for _ in range(9):
    parrafo()
for etiqueta, valor in (("Parcial: ", "Segundo Parcial"), ("Registro: ", "______________"), ("", ""),
                        ("Materia: ", "[MATERIA]"), ("Docente: ", "[DOCENTE]"), ("Nombre: ", "______________________________")):
    if not etiqueta:
        parrafo(); continue
    p = doc.add_paragraph(); p.paragraph_format.space_after = Pt(6)
    r = p.add_run(etiqueta); r.bold = True; r.font.name = "Arial"; r.font.size = Pt(12)
    r2 = p.add_run(valor); r2.font.name = "Arial"; r2.font.size = Pt(12)
doc.add_page_break()

# ---------------- índice ----------------
p = parrafo("ÍNDICE", True, tam=14, fuente="Arial", espacio_despues=10)
campo_toc(doc.add_paragraph())

# ---------------- sección 1 ----------------
s1 = doc.add_section(WD_SECTION.NEW_PAGE); configurar(s1)
doc.add_heading("1. DISEÑO DE DETALLE PROCEDIMENTAL Y DIAGRAMA GENÉRICO", level=1)


def caso(titulo, patron, gen_img, libro, especifico, zona, pie_especifico, pie_zona, roles, ultimo=False):
    doc.add_heading(titulo, level=2)
    doc.add_heading(patron, level=3)
    imagen(os.path.join(IMG, gen_img), 15.5)
    parrafo("Nota. Diagrama genérico elaborado en Enterprise Architect a partir de la estructura descrita en:", cursiva=True, tam=10, espacio_despues=2)
    cita(libro)
    # diagrama específico, página horizontal
    sh = doc.add_section(WD_SECTION.NEW_PAGE); configurar(sh, horizontal=True, margen=1.5)
    imagen(os.path.join(IMG, especifico), 24.5, 16.4)
    parrafo(pie_especifico, cursiva=True, tam=10, alin=WD_ALIGN_PARAGRAPH.CENTER)
    # zoom de la zona del patrón + roles
    doc.add_page_break()
    imagen(os.path.join(IMG, zona), 24.5, 9.2)
    parrafo(pie_zona, cursiva=True, tam=10, alin=WD_ALIGN_PARAGRAPH.CENTER, espacio_despues=8)
    tabla_roles(roles)
    if not ultimo:
        sp = doc.add_section(WD_SECTION.NEW_PAGE); configurar(sp)


caso("CU5_CU6: Clases y Asistencia", "Strategy", "gen_strategy.png", "Sumérgete en los patrones de diseño",
     "cu56.png", "cu56_zona.png",
     "Diagrama de clases del CU5_CU6 (Gestionar Clases y Asistencia) con el patrón Strategy. Las relaciones del patrón se resaltan en azul.",
     "Detalle de la zona del patrón: identificación del estudiante al marcar asistencia (manual, facial o QR).",
     [("Context", "ContextoIdentificacion", "ms-clases-asistencia/src/estrategias/ContextoIdentificacion.php"),
      ("Strategy (interfaz)", "IEstrategiaIdentificacion", "ms-clases-asistencia/src/estrategias/IEstrategiaIdentificacion.php"),
      ("ConcreteStrategy", "EstrategiaManual, EstrategiaFacial, EstrategiaQR", "ms-clases-asistencia/src/estrategias/EstrategiaManual.php, EstrategiaFacial.php, EstrategiaQR.php"),
      ("Client", "asistencia (elige la estrategia y crea el contexto)", "ms-clases-asistencia/src/asistencia.php")])

caso("CU8: Importar Estudiantes", "Chain of Responsibility", "gen_cor.png", "Sumérgete en los patrones de diseño",
     "cu8.png", "cu8_zona.png",
     "Diagrama de clases del CU8 (Importar Lista de Estudiantes) con el patrón Chain of Responsibility. Las relaciones del patrón se resaltan en azul.",
     "Detalle de la zona del patrón: cada fila del Excel recorre la cadena de manejadores (encabezados, registro, CI duplicado, guardar).",
     [("Handler", "ManejadorFilaBase (abstracta; se agrega a sí misma: guarda su siguiente)", "ms-estudiantes/src/cadena/ManejadorFilaBase.php"),
      ("ConcreteHandler", "ValidarEncabezadosHandler, ValidarRegistroHandler, ValidarCiNoDuplicadoHandler, GuardarEstudianteHandler", "ms-estudiantes/src/cadena/*.php"),
      ("Client", "importador_excel (arma la cadena con construirCadenaDeFila y la usa)", "ms-estudiantes/src/importador_excel.php")], ultimo=True)

out = r"C:\tmp\arqui\Segundo_Parcial_Arquitectura_borrador.docx"
doc.save(out)
print("guardado", out)
