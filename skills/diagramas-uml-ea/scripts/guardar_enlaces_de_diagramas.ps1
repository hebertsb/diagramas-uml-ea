param([string]$Archivo, [string]$Salida)
. "$PSScriptRoot\ea_lib.ps1"
$sw = New-Object System.IO.StreamWriter($Salida, $false, [Text.UTF8Encoding]::new($false))
$sw.AutoFlush = $true
function Log($t) { $sw.WriteLine($t) }
function Cnt($q) { $x = Sql-Rows $repo $q; return $x.Count }
try {
    $repo = New-Object -ComObject EA.Repository
    [void]$repo.OpenFile($Archivo)
    $ids = Sql-Rows $repo "SELECT Diagram_ID FROM t_diagram WHERE Diagram_ID >= 15 AND Diagram_Type <> 'Sequence'"
    foreach ($fila in $ids) {
        $id = [int]$fila.Diagram_ID
        $a = Cnt "SELECT ConnectorID FROM t_diagramlinks WHERE DiagramID = $id"
        [void]$repo.OpenDiagram($id); [void]$repo.SaveDiagram($id); [void]$repo.CloseDiagram($id)
        $b = Cnt "SELECT ConnectorID FROM t_diagramlinks WHERE DiagramID = $id"
        Log ("diagrama {0}: enlaces {1} -> {2}" -f $id, $a, $b)
    }
    $repo.CloseFile(); $repo.Exit()
} catch { Log ("ERROR: " + $_.Exception.Message) } finally { $sw.Close() }
