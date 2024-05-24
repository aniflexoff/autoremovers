# Установка списков директорий для поиска и удаления папок AutoDesk
$directories = @(
    "$env:ProgramFiles\Autodesk",
    "$env:ProgramFiles(x86)\Autodesk",
    "$env:ProgramData\Autodesk",
    "$env:LocalAppData\Autodesk",
    "$env:AppData\Autodesk",
    "$env:ProgramFiles\Common Files\Autodesk Shared",
    "$env:ProgramFiles(x86)\Common Files\Autodesk Shared"
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
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logMessage = "$timestamp - $message"
    Write-Host "$color$logMessage$colorReset"
    Add-Content -Path "C:\Backup\cleanup_log.txt" -Value $logMessage
}

# Функция для завершения процессов Autodesk
function Stop-AutodeskProcesses {
    Write-Log "--- Start stopping Autodesk processes ---" $colorYellow
    $processes = Get-Process | Where-Object { $_.Name -match "acad|autodesk|revit|3dsmax" }
    foreach ($process in $processes) {
        try {
            Stop-Process -Id $process.Id -Force
            Write-Log "  ┝ Stopped process: $($process.Name) (ID: $($process.Id))" $colorGreen
        } catch {
            Write-Log "  ┝ Failed to stop process: $($process.Name) (ID: $($process.Id))" $colorRed
        }
    }
    Write-Log "--- End stopping Autodesk processes ---" $colorYellow
}

# Функция для остановки и отключения служб Autodesk
function Stop-AutodeskServices {
    Write-Log "--- Start stopping Autodesk services ---" $colorYellow
    $services = Get-Service | Where-Object { $_.Name -eq "Autodesk" }
    foreach ($service in $services) {
        try {
            Stop-Service -Name $service.Name -Force
            Set-Service -Name $service.Name -StartupType Disabled
            Write-Log "  ┝ Stopped and disabled service: $($service.Name)" $colorGreen
        } catch {
            Write-Log "  ┝ Failed to stop or disable service: $($service.Name)" $colorRed
        }
    }
    Write-Log "--- End stopping Autodesk services ---" $colorYellow
}

# Определение функций для поиска и удаления папок
function Remove-Folders {
    param ([string[]]$folders)
    Write-Log "--- Start removing folders ---" $colorYellow
    foreach ($folder in $folders) {
        if (Test-Path -Path $folder) {
            Remove-Item -Path $folder -Recurse -Force
            Write-Log "  ┝ Removed folder: $folder" $colorGreen
        } else {
            Write-Log "  ┝ Folder not found: $folder" $colorRed
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
        Write-Log "  ┝ Registry backup saved: $backupPath" $colorGreen
    } catch {
        Write-Log "  ┝ Error backing up registry key: $key" $colorRed
    }
}

# Очистка реестра AutoDesk в HKEY_CURRENT_USER и HKEY_LOCAL_MACHINE
$registryPaths = @(
    "HKCU:\Software\Autodesk",
    "HKLM:\Software\Autodesk",
    "HKLM:\SOFTWARE\WOW6432Node\Autodesk"
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
            Write-Log "  ┝ Removed registry key: $key" $colorGreen
        } else {
            Write-Log "  ┝ Registry key not found: $key" $colorRed
        }
    }
    Write-Log "--- End cleaning registry ---" $colorYellow
}

# Удаление записей AutoDesk из списка установленных программ
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
            if ($displayName -like "*Autodesk*") {
                $backupPath = "C:\Backup\Uninstall_$(($subKey.PSChildName) -replace '\\', '_').reg"
                Backup-RegistryKey -key $subKey.PSPath -backupPath $backupPath

                Remove-Item -Path $subKey.PSPath -Recurse -Force
                Write-Log "  ┝ Removed uninstall entry: $displayName" $colorGreen
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

# Завершение процессов Autodesk
Stop-AutodeskProcesses

# Остановка и отключение служб Autodesk
Stop-AutodeskServices

# Запуск удаления папок
Remove-Folders -folders $directories

# Запуск очистки реестра
Remove-RegistryKeys -keys $registryPaths

# Запуск удаления записей из списка установленных программ
Remove-UninstallEntries -paths $uninstallPaths

Write-Log "--- Script completed ---" $colorYellow
