# Establecer codificación a UTF-8 para compatibilidad
try {
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    chcp 65001 > $null
} catch {}

# --- INICIO DE LA CONFIGURACIÓN DEL PROMPT ---

# 1. Inicializa Oh My Posh con tu tema personalizado.
#    Asegúrate de que el archivo 'toolbox-theme.omp.json' también esté en tu repo.
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/jandedobbeleer.omp.json" | Invoke-Expression
# 2. Limpia la pantalla después de cargar el prompt.
Clear-Host

# 3. Muestra la información del sistema con Fastfetch.
if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
    fastfetch -c "$HOME/.config/fastfetch/config.jsonc"
}

