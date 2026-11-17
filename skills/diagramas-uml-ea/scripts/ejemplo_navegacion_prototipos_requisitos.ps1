param([string]$Trabajo, [string]$Salida, [string]$ImgDir = 'C:\tmp\ea_ejemplo_navegacion')
# Ejemplo autonomo (dominio neutro: pedidos) de tres tipos de diagrama:
#   1) NAVEGACION web por actor (WAE / Conallen): paginas cliente, formularios, paginas servidor y tablas de BD.
#   2) PROTOTIPO DE INTERFAZ (pantalla con controles).
#   3) REQUISITOS trazados a casos de uso.
# Corre solo sobre una COPIA del .eapx y con EA cerrado.
. "$PSScriptRoot\ea_lib.ps1"
$ErrorActionPreference = 'Continue'
$global:CarpetaImg = $ImgDir
$sw = New-Object System.IO.StreamWriter($Salida, $false, [Text.UTF8Encoding]::new($false))
$sw.AutoFlush = $true
function Log($t) { $sw.WriteLine($t) }

# Atributo de navegacion: privado, sin tipo y marcado como coleccion (EA lo muestra como "- nombre {bag}").
function Add-AttrNav($el, $nombres) {
    $i = 0
    foreach ($n in $nombres) {
        $a = $el.Attributes.AddNew($n, '')
        $a.Visibility = 'Private'
        $a.IsCollection = $true
        $a.AllowDuplicates = $true
        $a.Pos = $i
        [void]$a.Update(); $i++
    }
    [void]$el.Attributes.Refresh()
}
# EA agrega los parentesis: el nombre se guarda sin "()" (si no, se ve "guardar()()").
function Add-OpsNav($el, $ops) { $i = 0; foreach ($o in $ops) { Add-Oper $el (([string]$o) -replace '\(\)$', '') '' @() $i; $i++ } }
# Elemento de navegacion: Class con estereotipo, atributos {bag} y operaciones sin parametros.
# Las tablas van como 'Artifact' con estereotipo 'database' (EA las pinta verdes con icono de documento).
function Add-Nav($pk, $nombre, $estereo, $attrs, $ops) {
    $tipo = $(if ($estereo -eq 'database') { 'Artifact' } else { 'Class' })
    $e = Add-Elem $pk $nombre $tipo $estereo
    Add-AttrNav $e $attrs
    Add-OpsNav $e $ops
    [void]$e.Refresh()
    return $e
}

try {
    $repo = New-Object -ComObject EA.Repository
    [void]$repo.OpenFile($Trabajo)
    $global:Repo = $repo
    $raiz = $repo.Models.GetAt(0)
    $pk = Add-Pkg $raiz 'Ejemplo navegacion, prototipos y requisitos'

    # ---------------- 1) NAVEGACION (un diagrama por actor) ----------------
    try {
        $d = Add-Diag $pk 'Diagrama de Navegacion - Vendedor' 'Logical'
        $d.StyleEx = $global:StyleBase -replace 'HideQuals=1', 'HideQuals=0'; [void]$d.Update()
        $act   = Add-Elem $pk 'Vendedor' 'Actor'
        $login = Add-Nav $pk 'Login' 'Client Page' @('email', 'password') @('submitLogin()')
        $panel = Add-Nav $pk 'Panel Vendedor' 'Client Page' @('totalPedidos') @('navigateTo()')
        $lista = Add-Nav $pk 'Lista Pedidos' 'Client Page' @('pedidos', 'filtros') @('abrirCrear()', 'buscar()')
        $form  = Add-Nav $pk 'Registrar Pedido' 'Formulario' @('id_cliente', 'fecha', 'total') @('guardar()', 'cerrarForm()')
        $psAut = Add-Nav $pk 'ps Autenticar' 'Server Page' @('email', 'password') @('login()')
        $psLis = Add-Nav $pk 'ps Listar Pedidos' 'Server Page' @('pedidos') @('index()')
        $psReg = Add-Nav $pk 'ps Registrar Pedido' 'Server Page' @('id_cliente', 'fecha', 'total') @('store()')
        $bdUsu = Add-Nav $pk 'BD: usuarios' 'database' @('id_usuario', 'email', 'id_rol') @()
        $bdPed = Add-Nav $pk 'BD: pedidos' 'database' @('id_pedido', 'id_cliente', 'fecha', 'total') @()

        [void](Place $d $act   30 230 60 90)
        [void](Place $d $login 150 220 170 90)
        [void](Place $d $panel 400 220 170 80)
        [void](Place $d $lista 400 420 170 100)
        [void](Place $d $form  680 420 180 110)
        [void](Place $d $psAut 680 60 170 90)
        [void](Place $d $psLis 950 300 170 75)
        [void](Place $d $psReg 950 600 170 100)
        [void](Place $d $bdUsu 1220 60 170 90)
        [void](Place $d $bdPed 1220 360 170 105)

        # Nombre del conector = "<tipo> <accion>": link (navegar), submit (enviar formulario),
        # build (la pagina servidor construye/redirige a la pagina cliente), access (pagina servidor -> tabla, con la operacion SQL).
        [void](Add-Conn $act   $login 'Association' 'link usa el sistema')
        [void](Add-Conn $login $psAut 'Association' 'submit submitLogin()')
        [void](Add-Conn $psAut $bdUsu 'Association' 'access SELECT')
        [void](Add-Conn $psAut $panel 'Association' 'build redirect auth ok')
        [void](Add-Conn $panel $lista 'Association' 'link pedidos')
        [void](Add-Conn $psLis $lista 'Association' 'build page load')
        [void](Add-Conn $psLis $bdPed 'Association' 'access SELECT')
        [void](Add-Conn $lista $form  'Association' 'link abrirCrear()')
        [void](Add-Conn $form  $psReg 'Association' 'submit guardar()')
        [void](Add-Conn $psReg $bdPed 'Association' 'access INSERT')
        [void](Add-Conn $psReg $lista 'Association' 'build redirect back')
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("navegacion: " + (Exporta $repo $d 'n1_navegacion'))
    } catch { Log ("ERROR navegacion: " + $_.Exception.Message) }

    # ---------------- 2) PROTOTIPO DE INTERFAZ ----------------
    # Pantalla = elemento 'Screen'; controles = 'GUIElement' con estereotipo (label, text, button, list...) y ParentID = pantalla.
    try {
        $d = Add-Diag $pk 'Prototipo - Registrar Pedido' 'Custom'
        $scr = Add-Elem $pk 'Registrar Pedido' 'Screen'
        [void](Place $d $scr 40 40 420 320 50)
        $ctrls = @(
            @('Cliente:', 'label', 70, 100, 90, 25), @('cmbCliente', 'combobox', 180, 100, 240, 25),
            @('Fecha:', 'label', 70, 145, 90, 25), @('txtFecha', 'text', 180, 145, 240, 25),
            @('Total:', 'label', 70, 190, 90, 25), @('txtTotal', 'text', 180, 190, 240, 25),
            @('Guardar', 'button', 180, 280, 110, 35), @('Cancelar', 'button', 310, 280, 110, 35))
        foreach ($c in $ctrls) {
            $g = Add-Elem $pk $c[0] 'GUIElement' $c[1]
            $g.ParentID = $scr.ElementID; [void]$g.Update()
            [void](Place $d $g $c[2] $c[3] $c[4] $c[5] 1)
        }
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("prototipo: " + (Exporta $repo $d 'n2_prototipo'))
    } catch { Log ("ERROR prototipo: " + $_.Exception.Message) }

    # ---------------- 3) REQUISITOS ----------------
    # Requisito = 'Requirement' (alias = codigo RF/RNF); traza = 'Realisation' del caso de uso al requisito.
    try {
        $d = Add-Diag $pk 'Requisitos - Pedidos' 'Custom'
        $r1 = Add-Elem $pk 'RF01 Registrar pedido' 'Requirement'
        $r2 = Add-Elem $pk 'RF02 Listar pedidos' 'Requirement'
        $r3 = Add-Elem $pk 'RNF01 Responder en menos de 2 s' 'Requirement'
        $cu1 = Add-Elem $pk 'CU01 Registrar pedido' 'UseCase'
        $cu2 = Add-Elem $pk 'CU02 Consultar pedidos' 'UseCase'
        [void](Place $d $r1 40 40 200 70); [void](Place $d $r2 280 40 200 70); [void](Place $d $r3 520 40 220 70)
        [void](Place $d $cu1 60 240 180 70); [void](Place $d $cu2 300 240 180 70)
        [void](Add-Conn $cu1 $r1 'Realisation')
        [void](Add-Conn $cu2 $r2 'Realisation')
        [void](Add-Conn $cu1 $r3 'Realisation')
        [void](Add-Conn $cu2 $r3 'Realisation')
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("requisitos: " + (Exporta $repo $d 'n3_requisitos'))
    } catch { Log ("ERROR requisitos: " + $_.Exception.Message) }
} catch { Log ("ERROR general: " + $_.Exception.Message) }
finally { if ($repo) { $repo.CloseFile(); $repo.Exit() }; $sw.Close() }
