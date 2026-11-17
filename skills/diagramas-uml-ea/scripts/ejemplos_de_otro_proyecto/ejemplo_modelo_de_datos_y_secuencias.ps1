param([string]$Trabajo, [string]$Salida, [string]$Partes = 'todo')
. "$PSScriptRoot\..\ea_lib.ps1"
$ErrorActionPreference = 'Continue'
$sw = New-Object System.IO.StreamWriter($Salida, $false, [Text.UTF8Encoding]::new($false))
$sw.AutoFlush = $true
function Log($t) { $sw.WriteLine($t) }
function Pascal($t) { return ((($t -split '_') | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) }) -join '') }
function Cargar($ruta) { return (Get-Content -Path $ruta -Raw -Encoding UTF8 | ConvertFrom-Json) }
function Resumen($texto, [int]$max = 300) {
    $t = (($texto -replace '`', '') -replace '\s+', ' ').Trim()
    $i = $t.IndexOf('. ')
    if ($i -gt 40 -and $i -lt $max) { return $t.Substring(0, $i + 1) }
    if ($t.Length -gt $max) { return $t.Substring(0, $max).TrimEnd() + '...' }
    return $t
}
function Ordenar($cols) { $a = [string[]]@($cols); [Array]::Sort($a, [StringComparer]::Ordinal); return $a }
function Alto-Tabla($n) { return [int](42 + 13.4 * $n) }

# (hijo|padre) -> etiqueta, cardinalidad del lado hijo, cardinalidad del lado padre. Las FK repetidas entre el mismo par se dibujan en una sola linea.
$REL = @{
    'partida|usuario'              = @('juega (dueño, blancas, negras)', '0..*', '0..1')
    'partida|participante'         = @('asigna (reservada)', '0..*', '0..1')
    'partida|sesion'               = @('agrupa (reservada)', '0..*', '0..1')
    'jugada|partida'               = @('registra', '0..*', '1..1')
    'mensaje_tutor|usuario'        = @('conversa con Turing', '0..*', '1..1')
    'calibracion|usuario'          = @('calibra', '0..*', '1..1')
    'exportacion_dataset|usuario'  = @('descarga', '0..*', '1..1')
    'codigo_invitacion|usuario'    = @('genera y usa', '0..*', '0..1')
    'usuario|institucion'          = @('agrupa docentes y tiene administrador', '0..*', '0..1')
    'usuario|usuario'              = @('se vincula (modo evaluación)', '0..1', '0..1')
    'codigo_invitacion|institucion' = @('invita a', '0..*', '0..1')
    'suscripcion|institucion'      = @('contrata', '0..1', '1..1')
    'pago|institucion'             = @('avisa', '0..*', '1..1')
    'curso|usuario'                = @('crea', '0..*', '1..1')
    'inscripcion|curso'            = @('reúne', '0..*', '1..1')
    'inscripcion|usuario'          = @('se inscribe', '0..1', '1..1')
    'medalla_ganada|usuario'       = @('gana', '0..*', '1..1')
    'medalla_personalizada|usuario' = @('crea', '0..*', '1..1')
    'amistad|usuario'              = @('solicita y recibe', '0..*', '1..1')
    'elo_movimiento|usuario'       = @('tiene y enfrenta a', '0..*', '1..1')
    'denuncia|usuario'             = @('denuncia y es denunciado', '0..*', '1..1')
    'torneo|curso'                 = @('arma', '0..*', '1..1')
    'torneo_jugador|torneo'        = @('inscribe', '0..*', '1..1')
    'torneo_jugador|usuario'       = @('participa', '0..*', '1..1')
    'torneo_partida|torneo'        = @('programa', '0..*', '1..1')
    'torneo_partida|usuario'       = @('juega (blancas y negras)', '0..*', '1..1')
    'aviso_curso|curso'            = @('recibe', '0..*', '1..1')
    'tarea_curso|curso'            = @('recibe', '0..*', '1..1')
}

# Crea las tablas como clases (solo nombres de columna, como el modelo del Sprint 1), las coloca y une con sus claves foraneas.
function Build-Modelo($repo, $pk, $nombreDiag, $tablas, $descripciones, $layout, [int]$ancho = 220) {
    $d = Add-Diag $pk $nombreDiag 'Logical'
    # Igual que el Sprint 1: HideQuals=0 hace que cada columna lleve el signo +
    $pdS1 = "HideRel=0;ShowTags=0;ShowReqs=0;ShowCons=0;OpParams=1;ShowSN=0;ScalePI=0;PPgs.cx=0;PPgs.cy=0;PSize=1;ShowIcons=1;SuppCN=0;HideProps=0;HideParents=0;UseAlias=0;HideAtts=0;HideOps=0;HideStereo=0;HideEStereo=0;ShowRec=1;ShowRes=0;ShowShape=1;FormName=;"
    $seS1 = ($global:StyleBase -replace 'HideQuals=\d', 'HideQuals=0')
    [void]$repo.Execute("UPDATE t_diagram SET PDATA = '$pdS1', StyleEx = '$seS1' WHERE Diagram_ID = $($d.DiagramID)")
    $els = @{}; $mostradas = @{}
    foreach ($t in $tablas) {
        $e = Add-Elem $pk (Pascal $t.tabla) 'Class'
        $nota = if ($descripciones.ContainsKey($t.tabla)) { $descripciones[$t.tabla] } else { Resumen $t.doc }
        $e.Notes = ("Tabla " + $t.tabla + ". " + $nota)
        [void]$e.Update()
        # Como en el Sprint 1: las claves foraneas no se escriben en la tabla (ya las muestra la linea de la relacion); queda la clave primaria (id) y el resto
        $fkc = @($t.fks | ForEach-Object { $_.col })
        $cols = @($t.columnas | Where-Object { $fkc -notcontains $_ })
        $mostradas[$t.tabla] = $cols
        foreach ($c in (Ordenar $cols)) { Add-Attr $e $c '' }
        [void]$e.Refresh()
        $els[$t.tabla] = $e
    }
    foreach ($t in $tablas) {
        if (-not $layout.ContainsKey($t.tabla)) { Log ("SIN POSICION: " + $t.tabla); continue }
        $p = $layout[$t.tabla]
        $w = if ($p.Count -gt 2) { $p[2] } else { $ancho }
        [void](Place $d $els[$t.tabla] $p[0] $p[1] $w (Alto-Tabla @($mostradas[$t.tabla]).Count))
    }
    $pares = [ordered]@{}
    foreach ($t in $tablas) { foreach ($f in @($t.fks)) { $pares[($t.tabla + '|' + $f.ref.Split('.')[0])] = $true } }
    $nc = 0
    foreach ($k in $pares.Keys) {
        if ($k -eq 'institucion|usuario') { continue }  # se dibuja junto con usuario|institucion
        if (-not $REL.ContainsKey($k)) { Log ("SIN ETIQUETA PARA " + $k); continue }
        $r = $REL[$k]; $hijo = $k.Split('|')[0]; $padre = $k.Split('|')[1]
        $c = Add-Conn $els[$hijo] $els[$padre] 'Association' $r[0]
        $c.ClientEnd.Cardinality = $r[1]; $c.SupplierEnd.Cardinality = $r[2]
        [void]$c.ClientEnd.Update(); [void]$c.SupplierEnd.Update(); [void]$c.Update()
        $nc++
    }
    [void]$repo.ReloadDiagram($d.DiagramID)
    Log ("  " + $nombreDiag + ": " + @($tablas).Count + " tablas, " + $nc + " conectores")
    return @{ d = $d; els = $els }
}

try {
    $repo = New-Object -ComObject EA.Repository
    [void]$repo.OpenFile($Trabajo)
    $global:Repo = $repo
    $pkS1 = Find-Pkg $repo 'Casos de Uso Sprint 1'
    $jugador = Find-Elem $repo 'Jugador' 'Actor' $pkS1.PackageID
    $s2 = Find-Pkg $repo 'Sprint 2'
    $s3 = Find-Pkg $repo 'Sprint 3'
    $bd2 = Cargar 'C:\tmp\ea\bd\bd_s2.json'
    $bd3 = Cargar 'C:\tmp\ea\bd\bd_s3.json'
    $dic = Cargar 'C:\tmp\ea\bd\diccionario.json'
    $desc3 = @{}; foreach ($p in $dic.PSObject.Properties) { $desc3[$p.Name] = (Resumen $p.Value.desc 330) }

    # ======================= MODELO DE DATOS DEL SPRINT 2 =======================
    if ($Partes -in 'todo', 'bd2') {
        try {
            $pk = Add-Pkg $s2 'Modelo de Datos'
            $lay2 = @{
                'jugada' = @(40, 60); 'participante' = @(40, 300); 'sesion' = @(40, 420)
                'partida' = @(340, 60); 'usuario' = @(720, 60)
                'mensaje_tutor' = @(1040, 40); 'calibracion' = @(1040, 190)
                'exportacion_dataset' = @(700, 380); 'codigo_invitacion' = @(960, 380)
            }
            $r = Build-Modelo $repo $pk 'Modelo de Datos Sprint 2' $bd2 @{} $lay2
            Log ("BD Sprint 2: " + (Exporta $repo $r.d 'bd_s2'))
        } catch { Log ("ERROR BD S2: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }
    }

    # ======================= MODELO DE DATOS COMPLETO =======================
    if ($Partes -in 'todo', 'bd3') {
        try {
            $pk = Add-Pkg $s3 'Modelo de Datos Completo'
            $lay3 = @{
                'usuario' = @(720, 330, 240)
                'jugada' = @(40, 330); 'participante' = @(40, 550); 'sesion' = @(40, 650); 'auditoria' = @(40, 780)
                'partida' = @(300, 330); 'mensaje_tutor' = @(300, 700)
                'calibracion' = @(400, 70); 'exportacion_dataset' = @(640, 70); 'elo_movimiento' = @(850, 60)
                'institucion' = @(1070, 200); 'codigo_invitacion' = @(1070, 380)
                'suscripcion' = @(1350, 190); 'pago' = @(1350, 350)
                'curso' = @(1350, 580); 'inscripcion' = @(1070, 680)
                'tarea_curso' = @(1630, 540); 'aviso_curso' = @(1630, 740)
                'torneo' = @(1350, 800); 'torneo_jugador' = @(1070, 800); 'torneo_partida' = @(1020, 960)
                'amistad' = @(150, 920); 'denuncia' = @(370, 920); 'medalla_ganada' = @(590, 920); 'medalla_personalizada' = @(810, 920)
            }
            $r = Build-Modelo $repo $pk 'Modelo de Datos Completo (Sprint 3)' $bd3 $desc3 $lay3 200
            Log ("BD completa: " + (Exporta $repo $r.d 'bd_completa'))
            # Mapa conceptual: los mismos elementos, sin columnas, en cajas chicas (se lee en una hoja)
            $d2 = Add-Diag $pk 'Mapa conceptual de la base de datos (Sprint 3)' 'Logical'
            $pd = "HideRel=0;ShowTags=0;ShowReqs=0;ShowCons=0;OpParams=3;ShowSN=0;ScalePI=0;PPgs.cx=0;PPgs.cy=0;PSize=9;ShowIcons=1;SuppCN=1;HideProps=0;HideParents=0;UseAlias=0;HideAtts=1;HideOps=1;HideStereo=0;HideEStereo=0;ShowRec=1;ShowRes=0;ShowShape=1;FormName=;"
            [void]$repo.Execute("UPDATE t_diagram SET PDATA = '$pd' WHERE Diagram_ID = $($d2.DiagramID)")
            $lay4 = @{
                'usuario' = @(720, 380)
                'partida' = @(400, 380); 'jugada' = @(140, 290); 'participante' = @(140, 380); 'sesion' = @(140, 470); 'auditoria' = @(40, 580)
                'mensaje_tutor' = @(320, 520)
                'calibracion' = @(360, 100); 'exportacion_dataset' = @(570, 100); 'elo_movimiento' = @(780, 100)
                'institucion' = @(1000, 200); 'suscripcion' = @(1240, 140); 'pago' = @(1240, 250); 'codigo_invitacion' = @(1000, 320)
                'inscripcion' = @(1000, 480); 'curso' = @(1240, 400); 'tarea_curso' = @(1480, 340); 'aviso_curso' = @(1480, 460)
                'torneo' = @(1240, 560); 'torneo_jugador' = @(1060, 570); 'torneo_partida' = @(1060, 690)
                'amistad' = @(280, 640); 'denuncia' = @(480, 640); 'medalla_ganada' = @(680, 640); 'medalla_personalizada' = @(880, 640)
            }
            foreach ($t3 in $bd3) {
                $p = $lay4[$t3.tabla]
                [void](Place $d2 $r.els[$t3.tabla] $p[0] $p[1] 160 34)
            }
            [void]$repo.ReloadDiagram($d2.DiagramID)
            Log ("Mapa conceptual: " + (Exporta $repo $d2 'bd_mapa'))
        } catch { Log ("ERROR BD completa: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }
    }

    # ======================= SECUENCIA SPRINT 2: DIAGNOSTICO DE NIVEL (HU13) =======================
    if ($Partes -in 'todo', 'sec2') {
        try {
            $pk = Add-Pkg $s2 'Secuencia Diagnostico de Nivel'
            $part = @(
                @{ n = 'Jugador'; t = 'actor'; e = $jugador },
                @{ n = 'Sala de Control'; t = 'boundary' },
                @{ n = 'ruta_partida'; t = 'control' },
                @{ n = 'ServicioPartida'; t = 'control' },
                @{ n = 'Motor (Stockfish)'; t = 'control' },
                @{ n = 'Retroalimentación'; t = 'control' },
                @{ n = 'ServicioCalibracion'; t = 'control' },
                @{ n = 'PostgreSQL'; t = 'entity' })
            $msgs = @(
                @{ d = 0; a = 1; t = 'termina su partida de diagnóstico (1 de 3)' },
                @{ d = 1; a = 2; t = 'POST /partida/{id}/calibrar' },
                @{ d = 2; a = 3; t = 'obtener_partida(partida_id)' },
                @{ d = 3; a = 2; t = 'partida terminada' },
                @{ d = 2; a = 3; t = 'analisis_completo(partida_id, rango)' },
                @{ d = 3; a = 4; t = 'analizar_posiciones(fens)' },
                @{ d = 4; a = 3; t = 'evaluación de cada posición' },
                @{ d = 3; a = 5; t = 'clasificar_calidad_jugada(...) y generar_resumen_partida(...)' },
                @{ d = 5; a = 3; t = 'resumen (precisión del jugador y jugadas evaluadas)' },
                @{ d = 3; a = 2; t = 'resultado con el resumen' },
                @{ d = 2; a = 6; t = 'registrar_calibracion(db, dueño, partida_id, resumen)' },
                @{ d = 6; a = 7; t = 'INSERT calibracion (precisión, nivel y rango de la partida)' },
                @{ d = 6; a = 7; t = 'SELECT últimas 3 calibraciones' },
                @{ d = 7; a = 6; t = 'calibraciones recientes' },
                @{ d = 6; a = 6; t = 'calcular_rango_desde_precision(promedio)' },
                @{ d = 6; a = 7; t = 'UPDATE usuario SET nivel_estimado, rango_estimado' },
                @{ d = 6; a = 2; t = 'registrada = true, diagnóstico n de 3, nivel anterior y nuevo' },
                @{ d = 6; a = 2; t = 'registrada = false y su motivo' },
                @{ d = 2; a = 1; t = '200 CalibracionResponse' },
                @{ d = 1; a = 0; t = 'muestra el nivel provisional (diagnóstico 1 de 3)' })
            $frags = @(@{ de = 11; hasta = 17; tipo = 0; guardas = @('el jugador tiene 5 o más jugadas evaluadas y la partida aún no estaba registrada', 'menos de 5 jugadas evaluadas o partida ya registrada'); cortes = @(17) })
            $d = Build-Sequence $repo $pk 'Secuencia: diagnóstico de nivel por partidas (Sprint 2)' $part $msgs $frags 175
            Log ("Secuencia HU13: " + (Exporta $repo $d 'sec_hu13'))
        } catch { Log ("ERROR sec HU13: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }
    }

    # ======================= SECUENCIA SPRINT 3: UNIRSE A UN CURSO CON CODIGO (HU11) =======================
    if ($Partes -in 'todo', 'sec3') {
        try {
            $pk = Add-Pkg $s3 'Secuencia Unirse a Curso'
            $part = @(
                @{ n = 'Jugador'; t = 'actor'; e = $jugador },
                @{ n = 'App web del jugador'; t = 'boundary' },
                @{ n = 'ruta_curso'; t = 'control' },
                @{ n = 'servicio_invitaciones'; t = 'control' },
                @{ n = 'servicio_cursos'; t = 'control' },
                @{ n = 'servicio_suscripciones'; t = 'control' },
                @{ n = 'PostgreSQL'; t = 'entity' })
            $msgs = @(
                @{ d = 0; a = 1; t = 'escribe el código del curso' },
                @{ d = 1; a = 2; t = 'POST /cursos/unirse' },
                @{ d = 2; a = 3; t = 'intentos_bloqueados(cliente)' },
                @{ d = 3; a = 2; t = 'quedan intentos' },
                @{ d = 2; a = 4; t = 'unirse_con_codigo(db, usuario, codigo)' },
                @{ d = 4; a = 6; t = 'SELECT curso WHERE codigo' },
                @{ d = 6; a = 4; t = 'curso (o ninguno)' },
                @{ d = 4; a = 6; t = 'SELECT docente, institución e inscripción actual' },
                @{ d = 6; a = 4; t = 'datos del curso y del jugador' },
                @{ d = 4; a = 5; t = 'verificar_cupo_de_institucion(db, curso, usuario)' },
                @{ d = 5; a = 4; t = 'plan vigente y con lugar' },
                @{ d = 4; a = 6; t = 'INSERT inscripcion (o UPDATE curso_id si ya estaba en otro)' },
                @{ d = 4; a = 2; t = 'curso' },
                @{ d = 2; a = 1; t = '200 curso, docente y preset' },
                @{ d = 1; a = 0; t = 'muestra su curso' },
                @{ d = 4; a = 2; t = 'ErrorCurso (código inexistente o ingresos cerrados)' },
                @{ d = 2; a = 3; t = 'registrar_intento_fallido(cliente)' },
                @{ d = 2; a = 1; t = '400 «código no válido»' },
                @{ d = 4; a = 2; t = 'CursoCompleto (sin cupo, correo institucional o suscripción vencida)' },
                @{ d = 2; a = 1; t = '400 con el motivo' })
            $frags = @(@{ de = 7; hasta = 19; tipo = 0; guardas = @('código válido y hay lugar', 'código inexistente o curso con ingresos cerrados', 'curso completo, correo no autorizado o suscripción vencida'); cortes = @(15, 18) })
            $d = Build-Sequence $repo $pk 'Secuencia: unirse a un curso con código (Sprint 3)' $part $msgs $frags 190
            Log ("Secuencia HU11: " + (Exporta $repo $d 'sec_hu11'))
        } catch { Log ("ERROR sec HU11: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }
    }
    $repo.CloseFile(); $repo.Exit()
}
catch { Log ("ERROR general: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }
finally { $sw.Close() }
