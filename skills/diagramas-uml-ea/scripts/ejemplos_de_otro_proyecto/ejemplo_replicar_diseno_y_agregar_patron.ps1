param([string]$Trabajo, [string]$Salida, [string]$ImgDir = 'C:\tmp\ea_replicar',
      [int]$PaqueteOrigen = 51, [int]$PaqueteDestino = 60, [string]$Nombre = 'CU5_CU6 - Clases Asistencia (Strategy)')
# TÉCNICA: duplicar un diseño que ya existe (zonas de color, orden, conectores, estilos) y agregarle un patrón de diseño.
# Se escribió para un .eapx concreto (microservicios con zonas Cliente / API Gateway / ms-*): los números por defecto
# (paquete 51 = caso de uso original, 60 = paquete de destino, 746..750 = clases del patrón ya definidas) son de ese archivo.
# Para otro archivo, averigua los ids con inspeccionar_eapx.ps1 o con SQL (t_package, t_object) y cámbialos.
# Pasos: 1) Package.Clone  2) hacer lugar (bajar todo)  3) traer las clases del patrón  4) zona nueva copiada de una zona existente
#        5) conectores del patrón  6) colores  7) exportar.   Corre solo sobre una COPIA del .eapx y con EA cerrado.
. "$PSScriptRoot\..\ea_lib.ps1"
$global:CarpetaImg = $ImgDir
$sw = New-Object System.IO.StreamWriter($Salida, $false, [Text.UTF8Encoding]::new($false)); $sw.AutoFlush = $true
function Log($t) { $sw.WriteLine($t) }
function Cls-H($na, $no) { return [int](38 + 17 * ($na + $no) + $(if ($na -gt 0 -and $no -gt 0) { 10 } else { 0 })) }
try {
    $repo = New-Object -ComObject EA.Repository
    [void]$repo.OpenFile($Trabajo)
    $global:Repo = $repo

    # 1) copia profunda del caso de uso original, debajo del paquete de destino
    $pkg = Clonar-Paquete $repo $PaqueteOrigen $PaqueteDestino $Nombre
    $pid2 = $pkg.PackageID; $did = $pkg.Diagrams.GetAt(0).DiagramID
    Log ("clon: paquete $pid2, diagrama $did")

    # 2) hacer lugar arriba para la zona del patrón: bajar todo 520 unidades y correr 'index' 130 a la derecha (pasillo libre)
    Mover-Objetos $repo $did 0 520
    $idx = Find-Elem $repo 'index' 'Class' $pid2
    Mover-Objetos $repo $did 130 0 @($idx.ElementID)

    # 3) clases del patrón (definidas en un borrador): se copian con sus atributos y operaciones
    $n = @{}
    foreach ($par in @(@('IEstrategiaIdentificacion', 746), @('ContextoIdentificacion', 747), @('EstrategiaManual', 748), @('EstrategiaFacial', 749), @('EstrategiaQR', 750))) {
        $n[$par[0]] = Copiar-Elemento $repo $par[1] $pid2
    }
    $ctx = $n['ContextoIdentificacion']; $itf = $n['IEstrategiaIdentificacion']
    $man = $n['EstrategiaManual']; $fac = $n['EstrategiaFacial']; $qr = $n['EstrategiaQR']
    $asis = Find-Elem $repo 'asistencia' 'Class' $pid2
    $cext = Find-Elem $repo 'clientes_externos' 'Class' $pid2

    # 4) zona nueva copiada de una zona existente (hereda borde discontinuo y estilo); luego nombre y color
    $zsrc = Find-Elem $repo 'ms-Clases-Asistencia' 'Boundary' $pid2
    $z0 = $zsrc.Clone(); $z0.Name = 'ms-Clases-Asistencia: patrón Strategy (identificación del estudiante)'; $z0.PackageID = $pid2; [void]$z0.Update()
    $zona = $repo.GetElementByID($z0.ElementID)
    $dg = $repo.GetDiagramByID($did)
    [void](Place $dg $zona 900 90 1100 390 40)      # z alto = queda detrás de las clases
    [void](Place $dg $ctx 915 135 350 (Cls-H 1 3) 1)
    [void](Place $dg $itf 1345 150 260 60 1)
    [void](Place $dg $man 1180 330 240 55 1); [void](Place $dg $fac 1480 330 240 55 1); [void](Place $dg $qr 1740 330 240 55 1)

    # 5) conectores del patrón (el resto del diseño conserva los suyos)
    $azul = @()
    $azul += (Add-Conn $asis $ctx 'Dependency' '' 'create')
    $c = Add-Conn $ctx $itf 'Aggregation'; $c.ClientEnd.Aggregation = 1; $c.ClientEnd.Navigable = 'Unspecified'; $c.Direction = 'Source -> Destination'
    [void]$c.ClientEnd.Update(); [void]$c.SupplierEnd.Update(); [void]$c.Update(); $azul += $c
    foreach ($k in @($man, $fac, $qr)) { $azul += (Add-Conn $k $itf 'Realization') }
    $azul += (Add-Conn $fac $cext 'Dependency' 'reconocerEstudiantePorRostro')
    $azul += (Add-Conn $qr $cext 'Dependency' 'leerCodigoQr')
    [void]$repo.ReloadDiagram($did)

    # 6) colores: relaciones del patrón en azul; zona e interfaz en lila
    Guardar-Enlaces $repo $dg
    Set-ColorConectores $repo $dg $azul 0 0 255
    Set-ColorZona $repo $did $zona.ElementID 230 220 250
    Set-ColorElemento $repo $dg $itf 230 220 250
    Log ("export: " + (Exporta $repo $dg 'replicar_y_patron'))
    $repo.CloseFile(); $repo.Exit()
} catch { Log ("ERROR: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) } finally { $sw.Close() }
