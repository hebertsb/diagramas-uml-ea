param([string]$Archivo, [string]$Salida, [string]$ImgDir = '')
. "$PSScriptRoot\ea_lib.ps1"
$ErrorActionPreference = 'Continue'
$sw = New-Object System.IO.StreamWriter($Salida, $false, [Text.UTF8Encoding]::new($false))
$sw.AutoFlush = $true
function Log($t) { $sw.WriteLine($t) }
function Cnt($q) { $x = Sql-Rows $repo $q; return $x.Count }
function V($r, $n) { $x = $r.SelectSingleNode($n); if ($x -eq $null) { return '' } else { return [string]$x.InnerText } }
try {
    $repo = New-Object -ComObject EA.Repository
    [void]$repo.OpenFile($Archivo)
    Log "ARCHIVO: $Archivo"
    # ---- paquetes
    $pk = @{}
    foreach ($r in (Sql-Rows $repo "SELECT Package_ID, Name, Parent_ID FROM t_package")) { $pk[[int](V $r 'Package_ID')] = @{ n = (V $r 'Name'); p = [int](V $r 'Parent_ID') } }
    function Ruta($id) { $s = @(); $k = 0; while ($id -gt 0 -and $pk.ContainsKey($id) -and $k -lt 12) { $s = @($pk[$id].n) + $s; $id = $pk[$id].p; $k++ }; return ($s -join ' > ') }
    # ---- diagramas
    $diags = Sql-Rows $repo "SELECT Diagram_ID, Package_ID, Name, Diagram_Type FROM t_diagram"
    Log "TOTAL DIAGRAMAS: $(@($diags).Count)"
    Log "--- por tipo ---"
    $porTipo = @{}
    foreach ($r in $diags) { $t = V $r 'Diagram_Type'; if (-not $porTipo.ContainsKey($t)) { $porTipo[$t] = 0 }; $porTipo[$t]++ }
    foreach ($k in ($porTipo.Keys | Sort-Object)) { Log ("  {0}: {1}" -f $k, $porTipo[$k]) }
    Log "--- detalle (paquete | tipo | nombre | objetos | conectores) ---"
    $listaDiag = @()
    foreach ($r in $diags) {
        $id = [int](V $r 'Diagram_ID')
        $no = (Cnt "SELECT Object_ID FROM t_diagramobjects WHERE Diagram_ID = $id")
        $nl = (Cnt "SELECT ConnectorID FROM t_diagramlinks WHERE DiagramID = $id")
        $listaDiag += [pscustomobject]@{ id = $id; ruta = (Ruta ([int](V $r 'Package_ID'))); tipo = (V $r 'Diagram_Type'); nombre = (V $r 'Name'); no = $no; nl = $nl }
    }
    foreach ($d in ($listaDiag | Sort-Object ruta, nombre)) { Log ("  [{0}] {1} | {2} | {3} | obj={4} con={5}" -f $d.id, $d.ruta, $d.tipo, $d.nombre, $d.no, $d.nl) }
    # ---- paquetes vacios (sin elementos, sin diagramas, sin subpaquetes)
    Log "--- paquetes vacios ---"
    $vac = 0
    foreach ($id in $pk.Keys) {
        $e = (Cnt "SELECT Object_ID FROM t_object WHERE Package_ID = $id")
        $dd = (Cnt "SELECT Diagram_ID FROM t_diagram WHERE Package_ID = $id")
        $sp = (Cnt "SELECT Package_ID FROM t_package WHERE Parent_ID = $id")
        if (($e + $dd + $sp) -eq 0) { Log ("  VACIO: " + (Ruta $id)); $vac++ }
    }
    Log "  paquetes vacios: $vac"
    # ---- diagramas vacios
    Log "--- diagramas sin objetos ---"
    foreach ($d in $listaDiag) { if ($d.no -eq 0) { Log ("  SIN OBJETOS: " + $d.nombre) } }
    # ---- clases: atributos y operaciones
    Log "--- clases (paquete | clase | atributos | operaciones) ---"
    $cls = Sql-Rows $repo "SELECT Object_ID, Name, Package_ID, Stereotype FROM t_object WHERE Object_Type = 'Class'"
    foreach ($r in $cls) {
        $id = [int](V $r 'Object_ID')
        $na = (Cnt "SELECT ID FROM t_attribute WHERE Object_ID = $id")
        $no = (Cnt "SELECT OperationID FROM t_operation WHERE Object_ID = $id")
        Log ("  {0} | {1} | attr={2} ops={3}" -f (Ruta ([int](V $r 'Package_ID'))), (V $r 'Name'), $na, $no)
    }
    # ---- secuencias: orden de mensajes
    Log "--- diagramas de secuencia: mensajes por SeqNo ---"
    foreach ($d in ($listaDiag | Where-Object { $_.tipo -eq 'Sequence' })) {
        $ms = Sql-Rows $repo ("SELECT Connector_ID, Name, SeqNo, Start_Object_ID, End_Object_ID, Connector_Type FROM t_connector WHERE DiagramID = " + $d.id + " AND Connector_Type = 'Sequence' ORDER BY SeqNo")
        $n = @($ms).Count; $seqs = @(); foreach ($m in $ms) { $seqs += [int](V $m 'SeqNo') }
        $okSeq = $true; for ($i = 0; $i -lt $seqs.Count; $i++) { if ($seqs[$i] -ne ($i + 1)) { $okSeq = $false } }
        Log ("  {0}: mensajes={1} SeqNo consecutivos 1..n = {2}" -f $d.nombre, $n, $okSeq)
        foreach ($m in $ms) { Log ("      {0}. {1}" -f (V $m 'SeqNo'), (V $m 'Name')) }
        $fr = Sql-Rows $repo ("SELECT o.Object_ID, o.Name FROM t_object o, t_diagramobjects g WHERE g.Object_ID = o.Object_ID AND o.Object_Type = 'InteractionFragment' AND g.Diagram_ID = " + $d.id)
        foreach ($f in $fr) {
            $el = $repo.GetElementByID([int](V $f 'Object_ID'))
            $gs = @(Sql-Rows $repo ("SELECT Description FROM t_xref WHERE Client = '" + $el.ElementGUID + "' AND Name = 'Partitions'"))
            Log ("      FRAGMENTO: {0} subtype={1} operandos/guardas={2}" -f $el.Name, $el.Subtype, $gs.Count)
        }
    }
    # ---- objetos huerfanos (elementos nuevos que no estan en ningun diagrama)
    Log "--- elementos que no aparecen en ningun diagrama (excluye paquetes) ---"
    $huer = Sql-Rows $repo "SELECT Object_ID, Name, Object_Type, Package_ID FROM t_object WHERE Object_Type <> 'Package' AND Object_ID NOT IN (SELECT Object_ID FROM t_diagramobjects)"
    $nh = 0; $agr = @{}
    foreach ($r in $huer) { $k = (Ruta ([int](V $r 'Package_ID'))) + ' [' + (V $r 'Object_Type') + ']'; if (-not $agr.ContainsKey($k)) { $agr[$k] = 0 }; $agr[$k]++; $nh++ }
    foreach ($k in ($agr.Keys | Sort-Object)) { Log ("  {0}: {1}" -f $k, $agr[$k]) }
    Log "  huerfanos: $nh"
    # ---- imagenes
    if ($ImgDir) {
        New-Item -ItemType Directory -Force -Path $ImgDir | Out-Null
        $proj = $repo.GetProjectInterface()
        $k = 0
        foreach ($d in $listaDiag) {
            $dg = $repo.GetDiagramByID($d.id)
            $arch = Join-Path $ImgDir (("{0:00}_" -f $k) + (($d.nombre -replace '[^A-Za-z0-9]+', '_')) + '.png')
            $ok = $proj.PutDiagramImageToFile([string]$dg.DiagramGUID, $arch, 1)
            Log ("  imagen {0}: {1}" -f $ok, (Split-Path $arch -Leaf)); $k++
        }
    }
    $repo.CloseFile(); $repo.Exit()
} catch { Log ("ERROR: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) } finally { $sw.Close() }
