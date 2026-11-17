param([Parameter(Mandatory = $true)][string]$Archivo)
# Crea un .eapx NUEVO y vacio (con un modelo raiz llamado "Model") usando la instalacion local de Enterprise Architect.
# No sobrescribe: si el archivo ya existe, se detiene y avisa.
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File nuevo_eapx.ps1 -Archivo "C:\ruta\proyecto.eapx"
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $Archivo) { Write-Output "NO SE CREO: ya existe $Archivo (no se sobrescribe)"; exit 2 }
try { $repo = New-Object -ComObject EA.Repository } catch { Write-Output "NO SE CREO: Enterprise Architect o su interfaz COM no estan disponibles ($($_.Exception.Message))"; exit 3 }
try {
    $dir = Split-Path -Parent $Archivo
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $ok = $repo.CreateModel(0, $Archivo, 0)   # 0 = cmEAPFromBase (archivo nuevo a partir de la plantilla de EA)
    if (-not $ok -or -not (Test-Path -LiteralPath $Archivo)) { Write-Output "NO SE CREO: CreateModel fallo"; exit 4 }
    [void]$repo.OpenFile($Archivo)
    Write-Output ("CREADO: " + $Archivo + " | modelos raiz: " + $repo.Models.Count + " | primero: " + $repo.Models.GetAt(0).Name)
    $repo.CloseFile()
} finally { $repo.Exit() }
