<#
.SYNOPSIS
    Script para configurar automáticamente un entorno de desarrollo en PowerShell.
    Instala herramientas, configura oh-my-posh, fastfetch y Windows Terminal.
#>

# --- INICIO: CONFIGURACIÓN DEL SCRIPT ---
Clear-Host
Write-Host "=====================================================" -ForegroundColor Yellow
Write-Host "    INICIANDO CONFIGURACIÓN AUTOMÁTICA DEL ENTORNO    " -ForegroundColor Yellow
Write-Host "=====================================================" -ForegroundColor Yellow
Write-Host

# URL base de tu repositorio de GitHub
$repoUrl = "https://raw.githubusercontent.com/BrandonSepulveda/mypowershellconfig/main/config-files"

# --- PASO 1: Establecer política de ejecución y verificar Winget ---
Write-Host "[Paso 1/5] Preparando el sistema..." -ForegroundColor Cyan
Set-ExecutionPolicy Bypass -Scope Process -Force
try {
    Get-Command winget | Out-Null
    Write-Host "  -> Winget encontrado." -ForegroundColor Green
} catch {
    Write-Host "  -> Winget no encontrado. Por favor, instálalo desde la Microsoft Store." -ForegroundColor Red
    exit
}

# --- PASO 2: Instalar aplicaciones y fuentes ---
Write-Host "[Paso 2/5] Instalando herramientas y fuentes..." -ForegroundColor Cyan
# 2a: Instalar Oh My Posh y Fastfetch con Winget
Write-Host "  -> Actualizando fuentes de Winget..."
winget source update
$packages = @(
    @{ Name = "Oh My Posh"; Id = "JanDeDobbeleer.OhMyPosh" },
    @{ Name = "Fastfetch"; Id = "fastfetch-cli.fastfetch" }
)
foreach ($pkg in $packages) {
    Write-Host "  -> Instalando $($pkg.Name)..."
    winget install --id $pkg.Id --source winget --accept-package-agreements --accept-source-agreements
}

# 2b: Instalar JetBrains Mono Nerd Font manualmente
Write-Host "  -> Instalando JetBrainsMono Nerd Font manualmente..."
$fontZipUrl = "https://download.jetbrains.com/fonts/JetBrainsMono-2.304.zip"
$tempDir = Join-Path -Path $env:TEMP -ChildPath "JetBrainsMonoFont"
$fontZipPath = Join-Path -Path $tempDir -ChildPath "JetBrainsMono.zip"

try {
    if (-not (Test-Path -Path $tempDir)) { New-Item -Path $tempDir -ItemType Directory | Out-Null }
    
    Write-Host "    -> Descargando el archivo de fuentes..."
    Invoke-WebRequest -Uri $fontZipUrl -OutFile $fontZipPath
    
    Write-Host "    -> Extrayendo fuentes..."
    Expand-Archive -Path $fontZipPath -DestinationPath $tempDir -Force
    
    $fontFiles = Get-ChildItem -Path (Join-Path $tempDir "fonts\ttf") -Filter "*.ttf" -Recurse
    if ($fontFiles) {
        Write-Host "    -> Instalando $($fontFiles.Count) archivos de fuente..."
        $fontsDir = "$env:SystemRoot\Fonts"
        foreach ($fontFile in $fontFiles) {
            Copy-Item -Path $fontFile.FullName -Destination $fontsDir -Force
        }
        Write-Host "  -> Fuentes de JetBrains Mono instaladas correctamente." -ForegroundColor Green
    } else {
        Write-Host "  -> No se encontraron archivos .ttf en el ZIP descargado." -ForegroundColor Red
    }
} catch {
    Write-Host "  -> Ocurrió un error al instalar las fuentes: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if (Test-Path -Path $tempDir) {
        Write-Host "    -> Limpiando archivos temporales..."
        Remove-Item -Path $tempDir -Recurse -Force
    }
}


# --- PASO 3: Configurar el perfil de PowerShell 7 ---
Write-Host "[Paso 3/5] Configurando el perfil de PowerShell 7..." -ForegroundColor Cyan
$themeUrl = "$repoUrl/toolbox-theme.omp.json"
$themePath = Join-Path -Path $HOME -ChildPath "toolbox-theme.omp.json"
Invoke-WebRequest -Uri $themeUrl -OutFile $themePath
$profilePath = $PROFILE
$profileUrl = "$repoUrl/profile.ps1"
if (Test-Path $profilePath) {
    Move-Item -Path $profilePath -Destination "$profilePath.bak" -Force
}
Invoke-WebRequest -Uri $profileUrl -OutFile $profilePath
Write-Host "  -> Perfil de PowerShell 7 configurado." -ForegroundColor Green

# --- PASO 4: Configurar Fastfetch ---
Write-Host "[Paso 4/5] Configurando Fastfetch..." -ForegroundColor Cyan
$configDir = Join-Path -Path $HOME -ChildPath ".config"
$fastfetchDir = Join-Path -Path $configDir -ChildPath "fastfetch"
New-Item -Path $configDir -ItemType Directory -Force | Out-Null
(Get-Item -Path $configDir).Attributes += 'Hidden'
New-Item -Path $fastfetchDir -ItemType Directory -Force | Out-Null
Invoke-WebRequest -Uri "$repoUrl/fastfetch/ascii.txt" -OutFile (Join-Path $fastfetchDir "ascii.txt")
Invoke-WebRequest -Uri "$repoUrl/fastfetch/config.jsonc" -OutFile (Join-Path $fastfetchDir "config.jsonc")
Write-Host "  -> Fastfetch configurado." -ForegroundColor Green

# --- PASO 5: Configurar Windows Terminal ---
Write-Host "[Paso 5/5] Configurando Windows Terminal..." -ForegroundColor Cyan
$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$wtSettingsUrl = "$repoUrl/settings.json"
if (Test-Path $wtSettingsPath) {
    Move-Item -Path $wtSettingsPath -Destination "$wtSettingsPath.bak" -Force
}
Invoke-WebRequest -Uri $wtSettingsUrl -OutFile $wtSettingsPath
Write-Host "  -> Windows Terminal configurado." -ForegroundColor Green

# --- FINALIZACIÓN ---
Write-Host
Write-Host "=====================================================" -ForegroundColor Green
Write-Host "          ¡CONFIGURACIÓN COMPLETADA CON ÉXITO!         " -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green
Write-Host "Por favor, CIERRA y VUELVE A ABRIR la terminal para ver todos los cambios." -ForegroundColor White
