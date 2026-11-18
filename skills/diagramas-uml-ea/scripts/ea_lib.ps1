# Biblioteca para construir modelos UML en Enterprise Architect por COM (EA 15).
# Reglas aprendidas con los prototipos:
#  - Mensajes de secuencia: StyleEx de un diagrama de secuencia + SuppressBrackets=1 + coordenadas explicitas (+-5).
#  - Elementos anidados: ParentID + orden de apilado (Sequence): el contenedor con numero MAYOR queda atras.
#  - include/extend: Dependency con estereotipo. Dependencia entre paquetes: Dependency con estereotipo import.
#  - Fragmentos: InteractionFragment (Subtype 0=alt 1=opt 2=break 3=par 4=loop) y condiciones en t_xref (la primera es la de abajo).
#  - Operaciones: OpParams=3 en PDATA muestra los nombres de parametros; los parametros se guardan al reves.

$global:StyleSec = 'ExcludeRTF=0;DocAll=0;HideQuals=1;AttPkg=1;ShowTests=0;ShowMaint=0;SuppressFOC=0;INT_ARGS=;INT_RET=;INT_ATT=;SeqTopMargin=50;MatrixActive=0;SwimlanesActive=1;KanbanActive=0;MatrixLineWidth=1;MatrixLineClr=0;MatrixLocked=0;TConnectorNotation=UML 2.1;TExplicitNavigability=0;AdvancedElementProps=1;AdvancedFeatureProps=1;AdvancedConnectorProps=1;m_bElementClassifier=1;SPT=1;MDGDgm=;STBLDgm=;ShowNotes=0;VisibleAttributeDetail=0;ShowOpRetType=1;SuppressBrackets=1;SuppConnectorLabels=0;PrintPageHeadFoot=0;ShowAsList=0;SuppressedCompartments=;Theme=:119;'

$global:StyleBase = 'ExcludeRTF=0;DocAll=0;HideQuals=1;AttPkg=1;ShowTests=0;ShowMaint=0;SuppressFOC=1;MatrixActive=0;SwimlanesActive=1;KanbanActive=0;MatrixLineWidth=1;MatrixLineClr=0;MatrixLocked=0;TConnectorNotation=UML 2.1;TExplicitNavigability=0;AdvancedElementProps=1;AdvancedFeatureProps=1;AdvancedConnectorProps=1;m_bElementClassifier=1;SPT=1;MDGDgm=;STBLDgm=;ShowNotes=0;VisibleAttributeDetail=0;ShowOpRetType=1;SuppressBrackets=0;SuppConnectorLabels=0;PrintPageHeadFoot=0;ShowAsList=0;SuppressedCompartments=;Theme=:119;'

function Sq($s) { return ([string]$s) -replace "'", "''" }

function Add-Pkg($parent, $name) {
    $p = $parent.Packages.AddNew($name, "")
    [void]$p.Update()
    [void]$parent.Packages.Refresh()
    return $p
}
function Add-Diag($pkg, $name, $type) {
    $d = $pkg.Diagrams.AddNew($name, $type)
    $d.StyleEx = $(if ($type -eq 'Sequence') { $global:StyleSec } else { $global:StyleBase })
    [void]$d.Update()
    if ($global:Repo) { Set-OpParams $global:Repo $d 3 }
    [void]$pkg.Diagrams.Refresh()
    return $d
}
function Add-Elem($pkg, $name, $type, $stereo = '', $notes = '') {
    $e = $pkg.Elements.AddNew($name, $type)
    if ($stereo) { $e.Stereotype = $stereo }
    if ($notes) { $e.Notes = $notes }
    [void]$e.Update()
    [void]$pkg.Elements.Refresh()
    return $e
}
function Place($diag, $el, [int]$x, [int]$y, [int]$w, [int]$h, [int]$z = 0) {
    $s = "l=$x;r=$($x + $w);t=-$y;b=-$($y + $h);"
    $do = $diag.DiagramObjects.AddNew($s, "")
    $do.ElementID = $el.ElementID
    if ($z -gt 0) { $do.Sequence = $z }
    [void]$do.Update()
    return $do
}
function Add-Conn($src, $dst, $type, $name = '', $stereo = '') {
    $c = $src.Connectors.AddNew($name, $type)
    $c.SupplierID = $dst.ElementID
    if ($stereo) { $c.Stereotype = $stereo }
    [void]$c.Update()
    [void]$src.Connectors.Refresh()
    return $c
}
function Add-Attr($el, $name, $type, $vis = 'Public', [bool]$static = $false, [int]$pos = -1) {
    $a = $el.Attributes.AddNew($name, $type)
    $a.Visibility = $vis
    if ($static) { $a.IsStatic = $true }
    if ($pos -ge 0) { $a.Pos = $pos }   # sin Pos, EA ordena los atributos alfabeticamente
    [void]$a.Update()
}
function Add-Oper($el, $name, $ret = '', $params = @(), [int]$pos = -1) {
    $m = $el.Methods.AddNew($name, $ret)
    $m.Visibility = 'Public'
    if ($pos -ge 0) { $m.Pos = $pos }   # sin Pos, EA ordena las operaciones alfabeticamente
    [void]$m.Update()
    $k = 0
    foreach ($p in @($params)) {
        $par = ([string]$p) -split ':', 2
        $q = $m.Parameters.AddNew($par[0].Trim(), $(if ($par.Count -gt 1) { $par[1].Trim() } else { 'str' }))
        $q.Position = $k
        [void]$q.Update()
        $k++
    }
    [void]$m.Parameters.Refresh()
}
# Visibilidad, abstracta y estatica de una operacion YA creada (por SQL; cambiar $m.Abstract / $m.IsStatic en el objeto Method no persiste).
function Set-OpFlags($repo, $el, $nombre, $vis = 'Public', [bool]$abs = $false, [bool]$st = $false) {
    $sets = @("Scope = '$vis'")
    if ($abs) { $sets += "Abstract = '1'" }
    if ($st) { $sets += "IsStatic = '1'" }
    [void]$repo.Execute("UPDATE t_operation SET " + ($sets -join ', ') + " WHERE Object_ID = $($el.ElementID) AND Name = '$(Sq $nombre)'")
}
# Colores (EA usa BGR). Conectores: solo existen en el diagrama despues de Guardar-Enlaces.
function Set-ColorConectores($repo, $diag, $conectores, [int]$r, [int]$g, [int]$b) {
    Guardar-Enlaces $repo $diag
    $ids = @($conectores | ForEach-Object { $_.ConnectorID })
    $dd = $repo.GetDiagramByID($diag.DiagramID)
    foreach ($l in $dd.DiagramLinks) { if ($ids -contains $l.ConnectorID) { $l.LineColor = [int]($r + 256 * $g + 65536 * $b); [void]$l.Update() } }
    [void]$repo.ReloadDiagram($diag.DiagramID)
}
function Set-ColorElemento($repo, $diag, $el, [int]$r, [int]$g, [int]$b) {
    $dd = $repo.GetDiagramByID($diag.DiagramID)
    foreach ($o in $dd.DiagramObjects) { if ($o.ElementID -eq $el.ElementID) { $o.BackgroundColor = [int]($r + 256 * $g + 65536 * $b); [void]$o.Update() } }
    [void]$repo.ReloadDiagram($diag.DiagramID)
}
# Muestra los signos de visibilidad (+ - #) delante de atributos y operaciones.
function Mostrar-Visibilidad($diag) {
    $diag.StyleEx = ($diag.StyleEx -replace 'HideQuals=\d', 'HideQuals=0')
    [void]$diag.Update()
}
# ---------- Replicar un diseno que ya existe (zonas de color, orden, conectores) ----------
# Copia PROFUNDA de un paquete: elementos, conectores, zonas, estilos y diagramas quedan identicos (Package.Clone de EA).
# La copia se mueve bajo $idPadre y se renombra (tambien su primer diagrama). Probado en EA 15.
function Clonar-Paquete($repo, [int]$idPaquete, [int]$idPadre, [string]$nombre) {
    $c = $repo.GetPackageByID($idPaquete).Clone()
    $c.ParentID = $idPadre; $c.Name = $nombre; [void]$c.Update()
    [void]$repo.Models.Refresh()
    $p = $repo.GetPackageByID($c.PackageID)
    if ($p.Diagrams.Count -gt 0) { $d = $p.Diagrams.GetAt(0); $d.Name = $nombre; [void]$d.Update() }
    return $p
}
# Copia un elemento (con sus atributos y operaciones) dentro de otro paquete: sirve para traer clases ya definidas a la copia del diseno.
function Copiar-Elemento($repo, [int]$idElemento, [int]$idPaqueteDestino) {
    $c = $repo.GetElementByID($idElemento).Clone()
    $c.PackageID = $idPaqueteDestino; [void]$c.Update()
    return $repo.GetElementByID($c.ElementID)
}
# Desplaza todos los objetos de un diagrama (dy positivo = hacia abajo) o solo los de una lista de elementos.
function Mover-Objetos($repo, [int]$idDiagrama, [int]$dx, [int]$dy, $idsElementos = $null) {
    $f = "Diagram_ID = $idDiagrama"
    if ($idsElementos) { $f += " AND Object_ID IN (" + ((@($idsElementos) | ForEach-Object { [int]$_ }) -join ',') + ")" }
    [void]$repo.Execute("UPDATE t_diagramobjects SET RectLeft = RectLeft + $dx, RectRight = RectRight + $dx, RectTop = RectTop - $dy, RectBottom = RectBottom - $dy WHERE $f")
}
# Color de fondo de una ZONA (elemento Boundary) en un diagrama; las zonas guardan el color en ObjectStyle (BCol, en BGR).
function Set-ColorZona($repo, [int]$idDiagrama, [int]$idElemento, [int]$r, [int]$g, [int]$b) {
    $fila = (Sql-Rows $repo "SELECT ObjectStyle FROM t_diagramobjects WHERE Diagram_ID = $idDiagrama AND Object_ID = $idElemento")[0]
    $est = ([string]$fila.ObjectStyle) -replace 'BCol=-?\d+;', ''
    [void]$repo.Execute("UPDATE t_diagramobjects SET ObjectStyle = '" + $est + "BCol=" + [int]($r + 256 * $g + 65536 * $b) + ";' WHERE Diagram_ID = $idDiagrama AND Object_ID = $idElemento")
    [void]$repo.ReloadDiagram($idDiagrama)
}
# Agranda el lazo de una relacion de un elemento consigo mismo (autoagregacion, autoasociacion). Por defecto EA la dibuja diminuta en una esquina.
# El lazo sale del borde DERECHO del elemento (x = $xDer) a la altura $yArriba (negativa) y vuelve al mismo borde $alto unidades mas abajo.
# Hay que llamarlo despues de Guardar-Enlaces (el enlace debe existir en el diagrama).
function Set-LazoPropio($repo, [int]$idDiagrama, [int]$idConector, [int]$xDer, [int]$yArriba, [int]$ancho, [int]$alto, [bool]$invertir = $false) {
    $f = (Sql-Rows $repo "SELECT Geometry FROM t_diagramlinks WHERE DiagramID = $idDiagrama AND ConnectorID = $idConector")[0]
    $g = [string]$f.Geometry
    $g = $g -replace 'SCTR\.LEFT=-?\d+', "SCTR.LEFT=$xDer" -replace 'SCTR\.TOP=-?\d+', "SCTR.TOP=$yArriba" -replace 'SCTR\.RIGHT=-?\d+', ("SCTR.RIGHT=" + ($xDer + $ancho)) -replace 'SCTR\.BOTTOM=-?\d+', ("SCTR.BOTTOM=" + ($yArriba - $alto))
    $ruta = ("{0}:{1};{2}:{1};{2}:{3};" -f $xDer, $yArriba, ($xDer + $ancho), ($yArriba - $alto))
    # el extremo de origen (rombo en una agregacion) queda al FINAL del recorrido; con $invertir el rombo queda arriba y la flecha abajo
    if ($invertir) { $ruta = ("{0}:{1};{2}:{1};{2}:{3};" -f $xDer, ($yArriba - $alto), ($xDer + $ancho), $yArriba) }
    [void]$repo.Execute("UPDATE t_diagramlinks SET Geometry = '" + (Sq $g) + "', Path = '" + $ruta + "' WHERE DiagramID = $idDiagrama AND ConnectorID = $idConector")
    [void]$repo.ReloadDiagram($idDiagrama)
}
# Elemento Interface con varias operaciones; cada operacion: @(nombre, retorno, @('param:tipo', ...)).
function Add-Interfaz($pkg, $nombre, $ops) {
    $i = Add-Elem $pkg $nombre 'Interface'
    $k = 0
    foreach ($o in $ops) {
        $m = $i.Methods.AddNew($o[0], $o[1]); $m.Pos = $k; [void]$m.Update()
        $j = 0
        foreach ($p in $o[2]) { $q = ([string]$p) -split ':', 2; $pa = $m.Parameters.AddNew($q[0], $q[1]); $pa.Position = $j; [void]$pa.Update(); $j++ }
        [void]$m.Parameters.Refresh(); $k++
    }
    [void]$i.Refresh()
    return $i
}
# Separa dos lineas que unen el MISMO par de elementos (EA las dibuja encimadas): desplaza sus extremos en vertical (dy en unidades; usar +12 y -12).
# Llamarlo despues de Guardar-Enlaces.
function Separar-Enlace($repo, [int]$idDiagrama, [int]$idConector, [int]$dy) {
    $f = (Sql-Rows $repo "SELECT Geometry FROM t_diagramlinks WHERE DiagramID = $idDiagrama AND ConnectorID = $idConector")[0]
    $g = [string]$f.Geometry
    $off = "SX=0;SY=$dy;EX=0;EY=$dy;"
    if ($g -match 'SX=-?\d+;SY=-?\d+;EX=-?\d+;EY=-?\d+;') { $g = $g -replace 'SX=-?\d+;SY=-?\d+;EX=-?\d+;EY=-?\d+;', $off } else { $g = $g -replace '(EDGE=\d+;)', ('$1' + $off) }
    [void]$repo.Execute("UPDATE t_diagramlinks SET Geometry = '" + (Sq $g) + "' WHERE DiagramID = $idDiagrama AND ConnectorID = $idConector")
}
# Relacion de un elemento CONSIGO MISMO con rombo y flecha abierta (como en el libro de Chain of Responsibility: el manejador se agrega a si mismo).
# Truco probado: conector de tipo 'Association' con el rombo en el extremo de origen y navegabilidad hacia el destino (el tipo 'Aggregation' dibuja el rombo
# pero no la flecha). Devuelve el conector; luego llamar a Guardar-Enlaces y a Set-LazoPropioArriba para dibujar el lazo sobre el borde superior.
function Add-AutoAgregacion($el, $rotulo = '') {
    $c = $el.Connectors.AddNew($rotulo, 'Association')
    $c.SupplierID = $el.ElementID
    $c.ClientEnd.Aggregation = 1; $c.ClientEnd.Navigable = 'Unspecified'; $c.SupplierEnd.Navigable = 'Navigable'; $c.Direction = 'Source -> Destination'
    [void]$c.ClientEnd.Update(); [void]$c.SupplierEnd.Update(); [void]$c.Update()
    [void]$el.Connectors.Refresh()
    return $c
}
# Lazo sobre el borde SUPERIOR del elemento: sale en x = $x, sube $alto unidades, recorre $ancho y vuelve a bajar. $yTop = y del borde superior (negativa).
# Dejar espacio libre encima del elemento (alto + unas 15 unidades). Llamarlo despues de Guardar-Enlaces.
function Set-LazoPropioArriba($repo, [int]$idDiagrama, [int]$idConector, [int]$x, [int]$yTop, [int]$ancho, [int]$alto) {
    $f = (Sql-Rows $repo "SELECT Geometry FROM t_diagramlinks WHERE DiagramID = $idDiagrama AND ConnectorID = $idConector")[0]
    $g = [string]$f.Geometry
    $g = $g -replace 'EDGE=\d+', 'EDGE=1'
    $g = $g -replace 'SCTR\.LEFT=-?\d+', "SCTR.LEFT=$x" -replace 'SCTR\.TOP=-?\d+', ("SCTR.TOP=" + ($yTop + $alto)) -replace 'SCTR\.RIGHT=-?\d+', ("SCTR.RIGHT=" + ($x + $ancho)) -replace 'SCTR\.BOTTOM=-?\d+', "SCTR.BOTTOM=$yTop"
    $ruta = ("{0}:{1};{0}:{2};{3}:{2};" -f $x, $yTop, ($yTop + $alto), ($x + $ancho))
    [void]$repo.Execute("UPDATE t_diagramlinks SET Geometry = '" + (Sq $g) + "', Path = '" + $ruta + "' WHERE DiagramID = $idDiagrama AND ConnectorID = $idConector")
    [void]$repo.ReloadDiagram($idDiagrama)
}
function Sql-Rows($repo, $sql) {
    $x = [xml]$repo.SQLQuery($sql)
    $out = New-Object System.Collections.ArrayList
    foreach ($r in $x.EADATA.Dataset_0.Data.Row) { [void]$out.Add($r) }
    return , $out
}
function Find-Elem($repo, $name, $type, [int]$pkgId = 0) {
    $sql = "SELECT Object_ID FROM t_object WHERE Name = '$(Sq $name)' AND Object_Type = '$type'"
    if ($pkgId -gt 0) { $sql += " AND Package_ID = $pkgId" }
    $f = Sql-Rows $repo $sql
    if ($f.Count -gt 0) { return $repo.GetElementByID([int]$f[0].Object_ID) }
    return $null
}
function Find-Pkg($repo, $name) {
    $f = Sql-Rows $repo "SELECT Package_ID FROM t_package WHERE Name = '$(Sq $name)'"
    if ($f.Count -gt 0) { return $repo.GetPackageByID([int]$f[0].Package_ID) }
    return $null
}
function Get-Or-Add($repo, $pkg, $name, $type, $stereo = '') {
    $e = Find-Elem $repo $name $type
    if ($e) { return $e }
    return (Add-Elem $pkg $name $type $stereo)
}
function Set-OpParams($repo, $diag, [int]$op = 3) {
    $p = "HideRel=0;ShowTags=0;ShowReqs=0;ShowCons=0;OpParams=$op;ShowSN=0;ScalePI=0;PPgs.cx=0;PPgs.cy=0;PSize=9;ShowIcons=1;SuppCN=1;HideProps=0;HideParents=0;UseAlias=0;HideAtts=0;HideOps=0;HideStereo=0;HideEStereo=0;ShowRec=1;ShowRes=0;ShowShape=1;FormName=;"
    [void]$repo.Execute("UPDATE t_diagram SET PDATA = '$p' WHERE Diagram_ID = $($diag.DiagramID)")
    [void]$repo.Execute("UPDATE t_diagram SET ShowForeign = False WHERE Diagram_ID = $($diag.DiagramID)")
}
function Add-Class($pkg, $name, $stereo = '', $attrs = @(), $ops = @(), [bool]$abstract = $false, $type = 'Class') {
    $c = Add-Elem $pkg $name $type $stereo
    if ($abstract) { $c.Abstract = '1'; [void]$c.Update() }
    # Marcas opcionales al inicio de cada atributo/operacion:  '-' privado, '#' protegido, '$' estatico, '*' abstracta (solo operaciones)
    $ai = 0
    foreach ($a in $attrs) {
        $txt = [string]$a; $vis = 'Public'; $st = $false
        while ($txt.Length -gt 0 -and '-#$'.Contains([string]$txt[0])) { switch ([string]$txt[0]) { '-' { $vis = 'Private' } '#' { $vis = 'Protected' } '$' { $st = $true } }; $txt = $txt.Substring(1) }
        $p = $txt -split ':', 2
        Add-Attr $c $p[0] $(if ($p.Count -gt 1) { $p[1].Trim() } else { 'str' }) $vis $st $ai
        $ai++
    }
    $oi = 0
    foreach ($o in $ops) {
        # formato: "nombre(p1:tipo,p2:tipo):retorno", con marcas opcionales al inicio
        $otxt = [string]$o; $ovis = 'Public'; $oabs = $false; $ost = $false
        while ($otxt.Length -gt 0 -and '-#$*'.Contains([string]$otxt[0])) { switch ([string]$otxt[0]) { '-' { $ovis = 'Private' } '#' { $ovis = 'Protected' } '$' { $ost = $true } '*' { $oabs = $true } }; $otxt = $otxt.Substring(1) }
        $m = [regex]::Match($otxt, '^(?<n>[^(]+)(\((?<p>[^)]*)\))?(:(?<r>.+))?$')
        $pl = @(); if ($m.Groups['p'].Value.Trim()) { $pl = @($m.Groups['p'].Value -split ',') }
        $pl = @($pl | ForEach-Object { $_.Trim() })
        Add-Oper $c $m.Groups['n'].Value.Trim() $(if ($m.Groups['r'].Success) { $m.Groups['r'].Value.Trim() } else { '' }) $pl $oi
        $oi++
        if ($ovis -ne 'Public' -or $oabs -or $ost) { Set-OpFlags $global:Repo $c $m.Groups['n'].Value.Trim() $ovis $oabs $ost }
    }
    [void]$c.Refresh()
    return $c
}
# EA solo guarda en el archivo las LINEAS (conectores) de un diagrama que no es de secuencia cuando se abre y se guarda el diagrama.
# Sin esto, el PNG exportado en la misma sesion se ve bien, pero al abrir el .eapx en EA los elementos aparecen SIN lineas.
function Guardar-Enlaces($repo, $d) {
    if ($d.Type -ne 'Sequence') { [void]$repo.OpenDiagram($d.DiagramID); [void]$repo.SaveDiagram($d.DiagramID); [void]$repo.CloseDiagram($d.DiagramID) }
}
function Exporta($repo, $d, $nombre) {
    Guardar-Enlaces $repo $d
    $carpeta = $(if ($global:CarpetaImg) { $global:CarpetaImg } else { 'C:\tmp\ea\build_img' })
    New-Item -ItemType Directory -Force -Path $carpeta | Out-Null
    $ok = $repo.GetProjectInterface().PutDiagramImageToFile([string]$d.DiagramGUID, "$carpeta\$nombre.png", 1)
    return $ok
}
function Set-Guardas($repo, $frag, $guardas, $alturas) {
    # $guardas y $alturas de ARRIBA hacia ABAJO; EA guarda primero el operando de abajo.
    $g = @($guardas); [array]::Reverse($g)
    $h = @($alturas); [array]::Reverse($h)
    $desc = ''
    for ($i = 0; $i -lt $g.Count; $i++) {
        $desc += ('@PAR;Name={0};Size={1};GUID={2};@ENDPAR;' -f $g[$i], $h[$i], [guid]::NewGuid().ToString('B').ToUpper())
    }
    $xid = [guid]::NewGuid().ToString('B').ToUpper()
    $sql = "INSERT INTO t_xref (XrefID, [Name], [Type], Visibility, [Partition], Description, Client, Supplier) VALUES ('$xid', 'Partitions', 'element property', 'Public', 0, '$(Sq $desc)', '$($frag.ElementGUID)', '<none>')"
    [void]$repo.Execute($sql)
}

# ---------- Constructor generico de diagramas de secuencia ----------
# $part: lista de @{n='nombre'; t='actor'|'boundary'|'control'|'entity'; e=<elemento existente o $null>}
# $msgs: lista de @{d=indice_origen; a=indice_destino; t='texto'}
# $frags: lista de @{de=i; hasta=j; tipo=0; guardas=@('...'); cortes=@(k,...)}  (cortes: indice de mensaje donde empieza cada operando siguiente)
function Build-Sequence($repo, $pk, $nombre, $part, $msgs, $frags, [int]$sep = 190) {
    $d = Add-Diag $pk $nombre 'Sequence'
    # EA reparte los mensajes solo por orden: el primero en y=135 y 38 unidades entre cada uno (los autoenvios ocupan un poco mas).
    $ys = @(); $y = 136.0
    for ($i = 0; $i -lt $msgs.Count; $i++) {
        if ($i -gt 0) { $y += 34.8; if ($msgs[$i].d -eq $msgs[$i].a) { $y -= 6 } }
        $ys += [int][math]::Round($y)
    }
    $alto = $ys[$ys.Count - 1] + 90
    $cx = @(); $els = @()
    for ($i = 0; $i -lt $part.Count; $i++) {
        $p = $part[$i]
        if ($p.e) { $el = $p.e }
        elseif ($p.t -eq 'actor') { $el = Add-Elem $pk $p.n 'Actor' }
        else { $el = Add-Elem $pk $p.n 'Sequence' $p.t }
        $x = 50 + $i * $sep
        [void](Place $d $el $x 40 90 ($alto - 40))
        $cx += ($x + 45); $els += $el
    }
    for ($i = 0; $i -lt $msgs.Count; $i++) {
        $m = $msgs[$i]
        $txt = ([string]$m.t).Replace('(', [string][char]0xFF08).Replace(')', [string][char]0xFF09)
        $c = $els[$m.d].Connectors.AddNew($txt, 'Sequence')
        $c.SupplierID = $els[$m.a].ElementID
        $c.DiagramID = $d.DiagramID
        $c.SequenceNo = $i + 1
        [void]$c.Update()
    }
    # fragmentos: top 30 por encima del primer mensaje, separadores a mitad entre mensajes, base 24 bajo el ultimo
    $izq = 25; $der = $cx[$cx.Count - 1] + 95
    foreach ($f in $frags) {
        $fe = $pk.Elements.AddNew('', 'InteractionFragment')
        $fe.Subtype = [int]$f.tipo
        [void]$fe.Update()
        $top = $ys[[int]$f.de] - 26
        $bot = $ys[[int]$f.hasta] + 20
        [void](Place $d $fe $izq $top ($der - $izq) ($bot - $top))
        $lim = @($top)
        foreach ($c in @($f.cortes)) { if ($c -ne $null) { $lim += ($ys[[int]$c] - 17) } }
        $lim += $bot
        $alt = @(); for ($k = 0; $k -lt $lim.Count - 1; $k++) { $alt += ($lim[$k + 1] - $lim[$k]) }
        Set-Guardas $repo $fe @($f.guardas) $alt
    }
    [void]$repo.ReloadDiagram($d.DiagramID)
    return $d
}
$global:ExtraAutoenvio = 16

# ---------- Comunicacion (colaboracion en UML 1.x) con mensajes numerados 1, 1.1, 1.2, 2... ----------
# Probado en EA 15 copiando la estructura de un .eapx hecho a mano: los enlaces son Association y cada mensaje es un
# conector 'Collaboration' (Synchronous/Call) con el numero de nivel en PDATA4. EA colorea cada grupo (1, 2, 3...) solo.
# Limitacion: la flechita de direccion junto a cada mensaje NO aparece cuando el mensaje se crea por COM (el numero si).
# Uso: crea objetos y Association, luego Add-MsgCom por mensaje, y al final Build-Comunicacion (guarda y acomoda).
function Add-MsgCom($repo, $diag, $de, $a, $nombre, [int]$seq, [string]$nivel, $params = '') {
    $c = $de.Connectors.AddNew($nombre, 'Collaboration')
    $c.SupplierID = $a.ElementID
    $c.SequenceNo = $seq
    $c.DiagramID = $diag.DiagramID
    $c.Direction = 'Source -> Destination'
    $c.TransitionEvent = 'Synchronous'; $c.TransitionAction = 'Call'
    if ($params) { $c.TransitionGuard = "params=;paramsDlg=$params;" }
    [void]$c.Update()
    [void]$repo.Execute("UPDATE t_connector SET PDATA1='Synchronous', PDATA2='$(Sq $c.TransitionGuard)', PDATA3='Call', PDATA4='$(Sq $nivel)', StateFlags='IsReturn=false;', DestIsNavigable=TRUE, SourceTS='instance', DestTS='instance' WHERE Connector_ID=$($c.ConnectorID)")
    return $c
}
# Guarda los enlaces, muestra los numeros (SuppCN=0) y apila los mensajes encima de su enlace: un renglon por grupo.
function Build-Comunicacion($repo, $diag) {
    Guardar-Enlaces $repo $diag
    [void]$repo.Execute("UPDATE t_diagram SET PDATA=REPLACE(PDATA,'SuppCN=1','SuppCN=0') WHERE Diagram_ID=$($diag.DiagramID)")
    $x = [xml]$repo.SQLQuery("SELECT Connector_ID, PDATA4 FROM t_connector WHERE DiagramID=$($diag.DiagramID) AND Connector_Type='Collaboration'")
    foreach ($r in $x.EADATA.Dataset_0.Data.Row) {
        $g = [int](([string]$r.PDATA4).Split('.')[0]); $sy = 85 - 19 * ($g - 1); $ey = $sy - 15
        $geo = "SX=-15;SY=$sy;EX=-15;EY=$ey;EDGE=2;"
        [void]$repo.Execute("UPDATE t_connector SET PDATA5='$geo', RouteStyle=1, Top_Start_Label=PDATA4 & ': <call>()' WHERE Connector_ID=$($r.Connector_ID)")
        [void]$repo.Execute("UPDATE t_diagramlinks SET Geometry='$geo`$LLB=;LLT=;LMT=;LMB=;LRT=;LRB=;IRHS=;ILHS=;', Style=REPLACE(Style,'Mode=3','Mode=1') WHERE ConnectorID=$($r.Connector_ID) AND DiagramID=$($diag.DiagramID)")
    }
    [void]$repo.ReloadDiagram($diag.DiagramID)
}
