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

# Функция для логирования
function Write-Log {
    param (
        [string]$message,
        [string]$color
    )
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logMessage = "$timestamp - $message"
    Write-Host $logMessage -ForegroundColor $color
    Add-Content -Path "C:\Backup\cleanup_log.txt" -Value $logMessage
}

# Функция для завершения процессов Autodesk
function Stop-AutodeskProcesses {
    Write-Log "--- Start stopping Autodesk processes ---" Yellow
    $processes = Get-Process | Where-Object { $_.Name -match "acad|autodesk|revit|3dsmax" }
    foreach ($process in $processes) {
        try {
            Stop-Process -Id $process.Id -Force
            Write-Log "  ┝ Stopped process: $($process.Name) (ID: $($process.Id))" Green
        } catch {
            Write-Log "  ┝ Failed to stop process: $($process.Name) (ID: $($process.Id))" Red
        }
    }
    Write-Log "--- End stopping Autodesk processes ---" Yellow
    Write-Host  # Добавляем пустую строку
}

# Функция для остановки и отключения служб Autodesk
function Stop-AutodeskServices {
    Write-Log "--- Start stopping Autodesk services ---" Yellow
    $services = Get-Service | Where-Object { $_.Name -eq "Autodesk" }
    foreach ($service in $services) {
        try {
            Stop-Service -Name $service.Name -Force
            Set-Service -Name $service.Name -StartupType Disabled
            Write-Log "  ┝ Stopped and disabled service: $($service.Name)" Green
        } catch {
            Write-Log "  ┝ Failed to stop or disable service: $($service.Name)" Red
        }
    }
    Write-Log "--- End stopping Autodesk services ---" Yellow
    Write-Host  # Добавляем пустую строку
}

# Определение функций для поиска и удаления папок
function Remove-Folders {
    param ([string[]]$folders)
    Write-Log "--- Start removing folders ---" Yellow
    foreach ($folder in $folders) {
        if (Test-Path -Path $folder) {
            Remove-Item -Path $folder -Recurse -Force
            Write-Log "  ┝ Removed folder: $folder" Green
        } else {
            Write-Log "  ┝ Folder not found: $folder" Red
        }
    }
    Write-Log "--- End removing folders ---" Yellow
    Write-Host  # Добавляем пустую строку
}

# Функция для резервного копирования раздела реестра
function Backup-RegistryKey {
    param (
        [string]$key,
        [string]$backupPath
    )
    try {
        Export-RegistryKey -Path $key -LiteralPath $backupPath
        Write-Log "  ┝ Registry backup saved: $backupPath" Green
    } catch {
        Write-Log "  ┝ Error backing up registry key: $key" Red
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
    Write-Host  # Добавляем пустую строку
    Write-Log "--- Start cleaning registry ---" Yellow
    foreach ($key in $keys) {
        $backupPath = "C:\Backup\$(($key -replace ':', '') -replace '\\', '_').reg"
        Backup-RegistryKey -key $key -backupPath $backupPath

        if (Test-Path -Path $key) {
            Remove-Item -Path $key -Recurse -Force
            Write-Log "  ┝ Removed registry key: $key" Green
        } else {
            Write-Log "  ┝ Registry key not found: $key" Red
        }
    }
    Write-Log "--- End cleaning registry ---" Yellow
    Write-Host  # Добавляем пустую строку
}

# Удаление записей AutoDesk из списка установленных программ
$uninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

# Функция для удаления записей из списка установленных программ
function Remove-UninstallEntries {
    param ([string[]]$paths)
    Write-Log "--- Start removing uninstall entries ---" Yellow
    foreach ($path in $paths) {
        $subKeys = Get-ChildItem -Path $path
        foreach ($subKey in $subKeys) {
            $displayName = (Get-ItemProperty -Path $subKey.PSPath).DisplayName
            if ($displayName -like "*Autodesk*") {
                $backupPath = "C:\Backup\Uninstall_$(($subKey.PSChildName) -replace '\\', '_').reg"
                Backup-RegistryKey -key $subKey.PSPath -backupPath $backupPath

                Remove-Item -Path $subKey.PSPath -Recurse -Force
                Write-Log "  ┝ Removed uninstall entry: $displayName" Green
            }
        }
    }
    Write-Log "--- End removing uninstall entries ---" Yellow
    Write-Host  # Добавляем пустую строку
}

# Создание директории для резервных копий, если она не существует
if (-not (Test-Path -Path "C:\Backup")) {
    New-Item -ItemType Directory -Path "C:\Backup"
    Write-Log "Created backup directory: C:\Backup" Green
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

Write-Log "--- Script completed ---" Yellow
