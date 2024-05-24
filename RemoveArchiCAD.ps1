# Установка списков директорий для поиска и удаления папок ArchiCAD
$directories = @(
    "$env:ProgramFiles\GRAPHISOFT",
    "$env:ProgramFiles(x86)\GRAPHISOFT",
    "$env:ProgramData\GRAPHISOFT",
    "$env:LocalAppData\GRAPHISOFT",
    "$env:AppData\GRAPHISOFT"
)

# Цветовые коды ANSI для подсветки
$colorReset = "`e[0m"
$colorGreen = "`e[32m"
$colorRed = "`e[31m"
$colorYellow = "`e[33m"

# Функция для логирования
function Write-Log {
    param (
        [string]$message,
        [string]$color = $colorReset
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $message"
    Write-Host "$color$logMessage$colorReset"
    Add-Content -Path "C:\Backup\cleanup_log.txt" -Value $logMessage
}

# Определение функций для поиска и удаления папок
function Remove-Folders {
    param ([string[]]$folders)
    Write-Log "--- Start removing folders ---" $colorYellow
    foreach ($folder in $folders) {
        if (Test-Path -Path $folder) {
            Remove-Item -Path $folder -Recurse -Force
            Write-Log "Removed folder: $folder" $colorGreen
        } else {
            Write-Log "Folder not found: $folder" $colorRed
        }
    }
    Write-Log "--- End removing folders ---" $colorYellow
}

# Функция для резервного копирования раздела реестра
function Backup-RegistryKey {
    param (
        [string]$key,
        [string]$backupPath
    )
    try {
        Export-RegistryKey -Path $key -LiteralPath $backupPath
        Write-Log "Registry backup saved: $backupPath" $colorGreen
    } catch {
        Write-Log "Error backing up registry key: $key" $colorRed
    }
}

# Очистка реестра ArchiCAD в HKEY_CURRENT_USER и HKEY_LOCAL_MACHINE
$registryPaths = @(
    "HKCU:\Software\GRAPHISOFT",
    "HKLM:\Software\GRAPHISOFT",
    "HKLM:\SOFTWARE\WOW6432Node\GRAPHISOFT"
)

# Функция для очистки реестра
function Remove-RegistryKeys {
    param ([string[]]$keys)
    Write-Log "--- Start cleaning registry ---" $colorYellow
    foreach ($key in $keys) {
        $backupPath = "C:\Backup\$(($key -replace ':', '') -replace '\\', '_').reg"
        Backup-RegistryKey -key $key -backupPath $backupPath

        if (Test-Path -Path $key) {
            Remove-Item -Path $key -Recurse -Force
            Write-Log "Removed registry key: $key" $colorGreen
        } else {
            Write-Log "Registry key not found: $key" $colorRed
        }
    }
    Write-Log "--- End cleaning registry ---" $colorYellow
}

# Удаление записей ArchiCAD из списка установленных программ
$uninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

# Функция для удаления записей из списка установленных программ
function Remove-UninstallEntries {
    param ([string[]]$paths)
    Write-Log "--- Start removing uninstall entries ---" $colorYellow
    foreach ($path in $paths) {
        $subKeys = Get-ChildItem -Path $path
        foreach ($subKey in $subKeys) {
            $displayName = (Get-ItemProperty -Path $subKey.PSPath).DisplayName
            if ($displayName -like "*GRAPHISOFT*") {
                $backupPath = "C:\Backup\Uninstall_$(($subKey.PSChildName) -replace '\\', '_').reg"
                Backup-RegistryKey -key $subKey.PSPath -backupPath $backupPath

                Remove-Item -Path $subKey.PSPath -Recurse -Force
                Write-Log "Removed uninstall entry: $displayName" $colorGreen
            }
        }
    }
    Write-Log "--- End removing uninstall entries ---" $colorYellow
}

# Создание директории для резервных копий, если она не существует
if (-not (Test-Path -Path "C:\Backup")) {
    New-Item -ItemType Directory -Path "C:\Backup"
    Write-Log "Created backup directory: C:\Backup" $colorGreen
}

# Запуск удаления папок
Remove-Folders -folders $directories

# Запуск очистки реестра
Remove-RegistryKeys -keys $registryPaths

# Запуск удаления записей из списка установленных программ
Remove-UninstallEntries -paths $uninstallPaths

Write-Log "--- Script completed ---" $colorYellow
