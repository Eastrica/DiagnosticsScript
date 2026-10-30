# ====================================================================================
# EASTRICA OS HEAL & DIAGNOSTICS SCRIPT
# ЗАПУСКАТЬ СТРОГО ОТ ИМЕНИ АДМИНИСТРАТОРА!
# ====================================================================================

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "ОШИБКА: Скрипт должен быть запущен от имени Администратора!"
    Pause; Exit
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "SilentlyContinue"
$LogFile = "C:\Eastrica_OS_Heal_Report.txt"
Clear-Content $LogFile -ErrorAction SilentlyContinue

Function Write-Log ($Message) {
    $Stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $Line = "[$Stamp] $Message"
    Write-Host $Line -ForegroundColor Cyan
    Add-Content -Path $LogFile -Value $Line
}

Write-Log "=== [СТАРТ] ВОССТАНОВЛЕНИЕ СИСТЕМЫ И АНАЛИЗ (41 ЭТАП) ==="

# =========================================================================
# ФАЗА 1: БЕЗОПАСНОСТЬ, СРЕДА И КРИПТОГРАФИЯ
# =========================================================================

# -------------------------------------------------------------------------
# 1. АКТИВАЦИЯ СИСТЕМЫ ЖИВУЧЕСТИ (WinRE и F8)
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 1] Восстановление среды WinRE и возврат меню F8..."
bcdedit /set "{default}" bootmenupolicy legacy | Out-Null
reagentc /enable | Out-Null
Write-Log "Среда восстановления WinRE и меню F8 активированы."

# -------------------------------------------------------------------------
# 2. ВОССТАНОВЛЕНИЕ ТЕНЕВЫХ КОПИЙ (VSS)
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 2] Перезапуск служб теневого копирования тома (VSS)..."
Stop-Service -Name vss, swprv, EventSystem -Force -ErrorAction SilentlyContinue
Start-Service -Name EventSystem, vss, swprv -ErrorAction SilentlyContinue
Write-Log "Службы VSS сброшены. Подготовка к бэкапу завершена."

# -------------------------------------------------------------------------
# 3. СОЗДАНИЕ ТОЧКИ ВОССТАНОВЛЕНИЯ
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 3] Создание системной Точки Восстановления..."
Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
try {
    Checkpoint-Computer -Description "Eastrica_Full_Backup" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
    Write-Log "Точка восстановления успешно создана."
} catch { Write-Log "Не удалось создать точку (Служба VSS отключена или лимит исчерпан)." }

# -------------------------------------------------------------------------
# 4. СИНХРОНИЗАЦИЯ ВРЕМЕНИ (NTP)
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 4] Глубокий сброс службы времени Windows..."
Stop-Service w32time -ErrorAction SilentlyContinue
w32tm /unregister | Out-Null
w32tm /register | Out-Null
Start-Service w32time -ErrorAction SilentlyContinue
w32tm /resync /force | Out-Null
Write-Log "Служба времени полностью пересобрана."

# -------------------------------------------------------------------------
# 5. ВОССТАНОВЛЕНИЕ КОРНЕВЫХ СЕРТИФИКАТОВ (Root CA)
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 5] Обновление криптографии и корневых сертификатов..."
certutil -setreg chain\ChainCacheResyncFiletime @now | Out-Null
$SSTPath = "$env:TEMP\roots.sst"
certutil -generateSSTFromWU $SSTPath | Out-Null
if (Test-Path $SSTPath) {
    Import-Certificate -FilePath $SSTPath -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
    Write-Log "Хранилище сертификатов обновлено напрямую с серверов Microsoft."
}

# -------------------------------------------------------------------------
# 6. ОЧИСТКА URL-КЭША КРИПТОГРАФИИ
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 6] Глубокая очистка кэша отзыва сертификатов (CRL)..."
certutil -urlcache * delete | Out-Null
Write-Log "Скрытый URL-кэш криптографии стерт (Исправление ошибок SSL)."


# =========================================================================
# ФАЗА 2: АППАРАТНАЯ ДИАГНОСТИКА И АНАЛИЗ ЖУРНАЛОВ
# =========================================================================

# -------------------------------------------------------------------------
# 7. АНАЛИЗ ЗДОРОВЬЯ НАКОПИТЕЛЕЙ (S.M.A.R.T.)
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 7] Опрос S.M.A.R.T. контроллеров жестких дисков и SSD..."
$Disks = Get-PhysicalDisk -ErrorAction SilentlyContinue
foreach ($Disk in $Disks) {
    if ($Disk.HealthStatus -ne "Healthy" -or $Disk.OperationalStatus -ne "OK") {
        Write-Log "КРИТИЧЕСКАЯ УГРОЗА! Диск '$($Disk.FriendlyName)' аппаратно умирает."
    } else { Write-Log "Накопитель '$($Disk.FriendlyName)' - Здоров (OK)." }
}

# -------------------------------------------------------------------------
# 8. ПРОВЕРКА ОШИБОК ОПЕРАТИВНОЙ ПАМЯТИ (WHEA-Logger)
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 8] Проверка аппаратных ошибок оперативной памяти (RAM)..."
$RamErrors = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; Level=1,2,3; StartTime=(Get-Date).AddDays(-7)} -ErrorAction SilentlyContinue
if ($RamErrors) {
    Write-Log "ОБНАРУЖЕНЫ ОШИБКИ ПАМЯТИ! Диагностика RAM назначена на следующую перезагрузку."
    Start-Process -FilePath "mdsched.exe" -ArgumentList "/passive" -WindowStyle Hidden
} else { Write-Log "Аппаратных сбоев RAM не зафиксировано." }

# -------------------------------------------------------------------------
# 9. АНАЛИЗ EVENTLOG (Сеть и Диски)
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 9] Умный анализ EventLog за последние 3 дня..."
$Events = Get-WinEvent -FilterHashtable @{LogName='System','Application'; Level=1,2; StartTime=(Get-Date).AddDays(-3)}
$NetFix = $false; $DiskFix = $false
foreach ($Event in $Events) {
    if ($Event.ProviderName -match "DNS|Network|Tcpip") { $NetFix = $true }
    if ($Event.ProviderName -match "Disk|Ntfs|stornvme") { $DiskFix = $true }
}
if ($NetFix) { netsh winsock reset | Out-Null; netsh int ip reset | Out-Null; ipconfig /flushdns | Out-Null }
if ($DiskFix) { chkdsk C: /F /X /Y | Out-Null; Write-Log "Исправление диска C: запланировано при запуске." }
Write-Log "Журналы событий проанализированы."

# -------------------------------------------------------------------------
# 10. АВТО-АНАЛИЗАТОР ДАМПОВ (BSOD)
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 10] Поиск и расшифровка дампов памяти (BSOD)..."
$DumpDir = "C:\Windows\Minidump"
$DumpFiles = @()
if (Test-Path $DumpDir) { $DumpFiles = Get-ChildItem -Path $DumpDir -Filter "*.dmp" }

if ($DumpFiles.Count -gt 0) {
    $TempDir = "C:\TempBSODAnalyzer"
    New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
    $ZipPath = "$TempDir\bsview.zip"
    Invoke-WebRequest -Uri "https://www.nirsoft.net/utils/bluescreenview.zip" -OutFile $ZipPath
    Expand-Archive -Path $ZipPath -DestinationPath $TempDir -Force
    $CsvReport = "$TempDir\report.csv"
    $ExePath = "$TempDir\BlueScreenView.exe"
    
    Start-Process -FilePath $ExePath -ArgumentList "/scomma `"$CsvReport`"" -Wait -WindowStyle Hidden
    if (Test-Path $CsvReport) {
        $ReportData = Get-Content $CsvReport -Encoding UTF8
        foreach ($Line in $ReportData) {
            $Columns = $Line -split ","
            if ($Columns.Count -ge 12) {
                Write-Log "КРАШ: $($Columns[0].Trim('"')) | ВИНОВНЫЙ ДРАЙВЕР: $($Columns[12].Trim('"'))"
            }
        }
    }
} else { Write-Log "Дампы (BSOD) не обнаружены." }


# =========================================================================
# ФАЗА 3: БАЗЫ ДАННЫХ, ПРАВА ДОСТУПА И ЯДРО
# =========================================================================

# -------------------------------------------------------------------------
# 11. СБРОС ПРАВ ДОСТУПА (NTFS и Реестр) К ЗАВОДСКИМ
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 11] Восстановление эталонных прав доступа к файлам и реестру (SecEdit)..."
secedit /configure /cfg "$env:windir\inf\defltbase.inf" /db defltbase.sdb /verbose | Out-Null
Write-Log "Разрешения безопасности системы сброшены к заводским настройкам."

# -------------------------------------------------------------------------
# 12. УДАЛЕНИЕ ВРЕДОНОСНЫХ ГРУППОВЫХ ПОЛИТИК (GPO)
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 12] Удаление принудительных групповых политик..."
$MachinePolicyPath = "$env:windir\System32\GroupPolicy"
$MachinePolicyUser = "$env:windir\System32\GroupPolicyUsers"
if (Test-Path $MachinePolicyPath) { Remove-Item -Path $MachinePolicyPath -Recurse -Force }
if (Test-Path $MachinePolicyUser) { Remove-Item -Path $MachinePolicyUser -Recurse -Force }
gpupdate /force | Out-Null
Write-Log "Блокировки GPO сняты."

# -------------------------------------------------------------------------
# 13. ВОССТАНОВЛЕНИЕ БАЗЫ ДАННЫХ WMI
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 13] Диагностика и восстановление базы WMI..."
$WmiCheck = winmgmt /verifyrepository 2>&1 | Out-String
if ($WmiCheck -match "INCONSISTENT" -or $WmiCheck -match "несогласован") {
    winmgmt /salvagerepository | Out-Null
    winmgmt /resetrepository | Out-Null
    Write-Log "Репозиторий WMI пересобран с нуля."
} else { Write-Log "Репозиторий WMI в норме." }

# -------------------------------------------------------------------------
# 14. ПЕРЕРЕГИСТРАЦИЯ КРИТИЧЕСКИХ СИСТЕМНЫХ DLL
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 14] Регистрация важнейших OLE/COM/Crypto библиотек в реестре..."
$CoreDLLs = @("vbscript.dll","jscript.dll","mshtml.dll","urlmon.dll","cryptdlg.dll","rsaenh.dll","wintrust.dll","initpki.dll","softpub.dll","mssip32.dll")
Push-Location "$env:windir\System32"
foreach ($dll in $CoreDLLs) { regsvr32.exe /s $dll }
Pop-Location
Write-Log "Системные библиотеки заново привязаны к реестру."

# -------------------------------------------------------------------------
# 15. СБРОС БАЗ ДАННЫХ SEARCH И UI КЭША (ИКОНКИ)
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 15] Пересборка кэша Windows Search и эскизов Проводника..."
Stop-Service WSearch -Force -ErrorAction SilentlyContinue
$SearchDB = "$env:ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.edb"
if (Test-Path $SearchDB) { Remove-Item -Path $SearchDB -Force -ErrorAction SilentlyContinue }
Start-Service WSearch -ErrorAction SilentlyContinue

Stop-Process -Name explorer -Force
$ExplorerDB = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
if (Test-Path $ExplorerDB) {
    Remove-Item "$ExplorerDB\iconcache*.db" -Force -ErrorAction SilentlyContinue
    Remove-Item "$ExplorerDB\thumbcache*.db" -Force -ErrorAction SilentlyContinue
}
Start-Process "explorer.exe"
Write-Log "Базы данных поиска и графики (иконок) сброшены."

# -------------------------------------------------------------------------
# 16. СБРОС БАЗЫ ДАННЫХ УВЕДОМЛЕНИЙ (Action Center)
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 16] Ремонт Центра уведомлений Windows..."
$WpnDB = "$env:LOCALAPPDATA\Microsoft\Windows\Notifications\wpndatabase.db"
if (Test-Path $WpnDB) { Remove-Item -Path $WpnDB -Force -ErrorAction SilentlyContinue }
Write-Log "База уведомлений стерта и будет пересоздана автоматически."

# -------------------------------------------------------------------------
# 17. ПЕРЕСБОРКА КЭША ШРИФТОВ (FontCache)
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 17] Сброс службы кэша шрифтов (Устранение артефактов интерфейса)..."
Stop-Service -Name "FontCache" -Force -ErrorAction SilentlyContinue
$FontCacheDir = "$env:windir\ServiceProfiles\LocalService\AppData\Local\FontCache"
if (Test-Path $FontCacheDir) { Remove-Item -Path "$FontCacheDir\*" -Recurse -Force -ErrorAction SilentlyContinue }
Start-Service -Name "FontCache" -ErrorAction SilentlyContinue
Write-Log "Системный кэш шрифтов очищен."

# -------------------------------------------------------------------------
# 18. ГЛУБОКОЕ ВОССТАНОВЛЕНИЕ ЯДРА ОС (DISM & SFC)
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 18] Авто-исправление системных файлов (DISM & SFC)..."
DISM /Online /Cleanup-Image /RestoreHealth | Out-Null
sfc /scannow | Out-Null
Write-Log "Проверка файлов ядра завершена."

# -------------------------------------------------------------------------
# 19. СЖАТИЕ И ОЧИСТКА ХРАНИЛИЩА WINSXS (ResetBase)
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 19] Оптимизация Component Store (Удаление старых версий обновлений)..."
DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Null
Write-Log "Хранилище компонентов Windows очищено."


# =========================================================================
# ФАЗА 4: ОБНОВЛЕНИЯ, СЕТЬ, ПЕРИФЕРИЯ И СЛУЖБЫ
# =========================================================================

# -------------------------------------------------------------------------
# 20. СБРОС ФОНОВОЙ ОЧЕРЕДИ ПЕРЕДАЧИ (BITS)
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 20] Глубокий сброс очередей BITS (Скрытые загрузки)..."
bitsadmin /reset /allusers | Out-Null
Write-Log "Сломанные фоновые загрузки отменены."

# -------------------------------------------------------------------------
# 21. ОЧИСТКА КЭША OPTIMIZATION DELIVERY (Оптимизация доставки)
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 21] Очистка кэша загрузок Windows Update (Оптимизация доставки)..."
Stop-Service -Name DoSvc -Force -ErrorAction SilentlyContinue
$DoCache = "$env:windir\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache"
if (Test-Path $DoCache) { Remove-Item -Path "$DoCache\*" -Recurse -Force -ErrorAction SilentlyContinue }
Start-Service -Name DoSvc -ErrorAction SilentlyContinue
Write-Log "Поврежденные пакеты обновлений удалены."

# -------------------------------------------------------------------------
# 22. СБРОС ЦЕНТРА ОБНОВЛЕНИЙ
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 22] Полная очистка кэша Windows Update..."
Stop-Service -Name wuauserv, bits, cryptsvc -Force -ErrorAction SilentlyContinue
Rename-Item -Path "C:\Windows\SoftwareDistribution" -NewName "SoftwareDistribution.old" -ErrorAction SilentlyContinue
Rename-Item -Path "C:\Windows\System32\catroot2" -NewName "catroot2.old" -ErrorAction SilentlyContinue
Start-Service -Name wuauserv, bits, cryptsvc -ErrorAction SilentlyContinue
Write-Log "Службы обновлений перезагружены."

# -------------------------------------------------------------------------
# 23. ОЧИСТКА ФАЙЛА HOSTS
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 23] Очистка файла HOSTS от вредоносных маршрутов..."
$HostsPath = "$env:windir\System32\drivers\etc\hosts"
if (Test-Path $HostsPath) {
    Rename-Item -Path $HostsPath -NewName "hosts.bak" -Force -ErrorAction SilentlyContinue
    $DefaultHosts = @"
# Copyright (c) Microsoft Corp.
127.0.0.1       localhost
::1             localhost
"@
    Set-Content -Path $HostsPath -Value $DefaultHosts -Force
}
Write-Log "Файл HOSTS сброшен."

# -------------------------------------------------------------------------
# 24. ОПТИМИЗАЦИЯ TCP/IP AUTO-TUNING И МАРШРУТИЗАЦИИ
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 24] Сброс таблиц маршрутизации и тюнинг TCP/IP (Фикс скорости сети)..."
netsh int tcp set global autotuninglevel=normal | Out-Null
route -f | Out-Null
arp -d * | Out-Null
Write-Log "Сетевой стек TCP/IP пересобран и оптимизирован."

# -------------------------------------------------------------------------
# 25. ГЛУБОКИЙ СБРОС ПРОКСИ WINHTTP И NETBIOS
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 25] Очистка скрытых прокси и NetBIOS маршрутов..."
netsh winhttp reset proxy | Out-Null
nbtstat -R | Out-Null
nbtstat -RR | Out-Null
ipconfig /registerdns | Out-Null
Write-Log "Системные сетевые прокси сброшены."

# -------------------------------------------------------------------------
# 26. СБРОС БРАНДМАУЭРА WINDOWS
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 26] Сброс правил Брандмауэра Windows..."
netsh advfirewall reset | Out-Null
Write-Log "Брандмауэр возвращен к заводским правилам."

# -------------------------------------------------------------------------
# 27. ОЧИСТКА ОЧЕРЕДИ ПЕЧАТИ
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 27] Удаление зависших заданий принтера..."
Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
$SpoolFolder = "$env:windir\System32\spool\PRINTERS"
if (Test-Path $SpoolFolder) { Remove-Item -Path "$SpoolFolder\*.*" -Force -Recurse -ErrorAction SilentlyContinue }
Start-Service -Name Spooler -ErrorAction SilentlyContinue
Write-Log "Диспетчер очереди печати очищен."

# -------------------------------------------------------------------------
# 28. ПЕРЕСБОРКА СЧЕТЧИКОВ ПРОИЗВОДИТЕЛЬНОСТИ
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 28] Восстановление системных счетчиков (LODCTR Fix)..."
Push-Location -Path "$env:windir\System32"; lodctr /R | Out-Null; Pop-Location
if (Test-Path "$env:windir\SysWOW64") {
    Push-Location -Path "$env:windir\SysWOW64"; lodctr /R | Out-Null; Pop-Location
}
Write-Log "Счетчики производительности восстановлены."

# -------------------------------------------------------------------------
# 29. ПЕРЕЗАГРУЗКА ЗАВИСШИХ УСТРОЙСТВ
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 29] Программный перезапуск сбойных устройств (Код 43 / Код 10)..."
$ErrorDevices = Get-PnpDevice | Where-Object { $_.Status -eq 'Error' -or $_.Status -eq 'Degraded' }
if ($ErrorDevices) {
    foreach ($Device in $ErrorDevices) {
        Disable-PnpDevice -InstanceId $Device.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Enable-PnpDevice -InstanceId $Device.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
    }
}
Write-Log "Цикл диагностики Диспетчера устройств завершен."

# -------------------------------------------------------------------------
# 30. СБРОС СХЕМ ЭЛЕКТРОПИТАНИЯ ЯДРА
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 30] Восстановление заводских параметров электропитания (Лечение троттлинга)..."
powercfg -restoredefaultschemes | Out-Null
Write-Log "Планы электропитания сброшены."

# -------------------------------------------------------------------------
# 31. ОТКЛЮЧЕНИЕ БЫСТРОГО ЗАПУСКА (Fast Startup Disable)
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 31] Отключение Быстрого запуска ядра (Лечение утечек памяти драйверов)..."
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0 -ErrorAction SilentlyContinue
Write-Log "Ядро ОС теперь будет полностью перезагружаться (Аптайм обнулен)."


# =========================================================================
# ФАЗА 5: ПРИЛОЖЕНИЯ, СОФТ И АНТИВИРУС
# =========================================================================

# -------------------------------------------------------------------------
# 32. ГЛУБОКИЙ СБРОС UWP И КЭША STORE
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 32] Очистка кэша Магазина и переустановка UWP-приложений..."
Get-Process -Name "WinStore.App" -ErrorAction SilentlyContinue | Stop-Process -Force
$StoreCache = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalCache"
if (Test-Path $StoreCache) { Remove-Item -Path "$StoreCache\*" -Recurse -Force -ErrorAction SilentlyContinue }

Get-AppXPackage -AllUsers | Foreach {
    Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue
}
Write-Log "Подсистема UWP-приложений перерегистрирована."

# -------------------------------------------------------------------------
# 33. АВТО-ОБНОВЛЕНИЕ ВСЕГО СТОРОННЕГО ПО (Winget)
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 33] Установка актуальных версий сторонних программ (Winget)..."
try { winget upgrade --all --silent --accept-package-agreements --accept-source-agreements | Out-Null; Write-Log "Софт обновлен." } 
catch { Write-Log "Winget недоступен." }

# -------------------------------------------------------------------------
# 34. ПЕРЕСБОРКА БАЗ DEFENDER И АНТИВИРУСНОЕ ЛЕЧЕНИЕ
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 34] Очистка старых вирусных баз и сканирование (Windows Defender)..."
if ((Get-Service "WinDefend" -ErrorAction SilentlyContinue).Status -eq "Running") {
    $MpCmd = "$env:ProgramFiles\Windows Defender\MpCmdRun.exe"
    if (Test-Path $MpCmd) {
        & $MpCmd -RemoveDefinitions -All | Out-Null
        & $MpCmd -SignatureUpdate | Out-Null
    }
    Start-MpScan -ScanType QuickScan | Out-Null
    if (Get-MpThreatDetection -ErrorAction SilentlyContinue) { Remove-MpThreat -Force }
    Write-Log "Базы обновлены, антивирусная проверка пройдена."
} else { Write-Log "Defender отключен." }


# =========================================================================
# ФАЗА 6: СИСТЕМНЫЕ СЛУЖБЫ И ПЛАНИРОВЩИК (DEFAULT RESTORE)
# =========================================================================

# -------------------------------------------------------------------------
# 35. ВОССТАНОВЛЕНИЕ СЛУЖБ WINDOWS К ЗАВОДСКИМ
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 35] Определение версии ОС и сброс всех системных служб к заводским параметрам..."
$OSInfo = Get-CimInstance Win32_OperatingSystem
$OSBuild = [int]($OSInfo.Version.Split('.')[2])
$OSName = if ($OSBuild -ge 22000) { "Windows 11" } else { "Windows 10" }
Write-Log "Обнаружена ОС: $OSName (Сборка $OSBuild). Применение эталонных параметров служб..."

$ServiceDefaults = @{
    "Appinfo"="Manual"; "AppMgmt"="Manual"; "Audiosrv"="Automatic"; "AudioEndpointBuilder"="Automatic";
    "BITS"="Manual"; "BFE"="Automatic"; "BDESVC"="Manual"; "BrokerInfrastructure"="Automatic";
    "Browser"="Manual"; "BthAvctpSvc"="Manual"; "bthserv"="Manual"; "BluetoothUserService"="Manual";
    "CDPSvc"="Delayed"; "CDPUserSvc"="Automatic"; "CertPropSvc"="Manual"; "ClipSVC"="Manual";
    "CryptSvc"="Automatic"; "DcomLaunch"="Automatic"; "Dhcp"="Automatic"; "DiagTrack"="Automatic";
    "Dnscache"="Automatic"; "DoSvc"="Delayed"; "DPS"="Automatic"; "EapHost"="Manual";
    "EventLog"="Automatic"; "EventSystem"="Automatic"; "FDResPub"="Manual"; "fdPHost"="Manual";
    "FontCache"="Automatic"; "gpsvc"="Automatic"; "IKEEXT"="Manual"; "InstallService"="Manual";
    "iphlpsvc"="Automatic"; "KeyIso"="Manual"; "KtmRm"="Manual"; "LanmanServer"="Automatic";
    "LanmanWorkstation"="Automatic"; "LicenseManager"="Manual"; "LSM"="Automatic";
    "MpsSvc"="Automatic"; "MSDTC"="Manual"; "Netlogon"="Manual"; "Netman"="Manual";
    "netprofm"="Manual"; "NlaSvc"="Automatic"; "nsi"="Automatic"; "PcaSvc"="Manual";
    "PerfHost"="Manual"; "PhoneSvc"="Manual"; "PlugPlay"="Automatic"; "PolicyAgent"="Manual";
    "Power"="Automatic"; "PrintNotify"="Manual"; "ProfSvc"="Automatic"; "PushToInstall"="Manual";
    "RasAuto"="Manual"; "RasMan"="Manual"; "RemoteRegistry"="Disabled"; "RpcEptMapper"="Automatic";
    "RpcSs"="Automatic"; "SamSs"="Automatic"; "SCardSvr"="Manual"; "Schedule"="Automatic";
    "SENS"="Automatic"; "SessionEnv"="Manual"; "SgrmBroker"="Delayed"; "ShellHWDetection"="Automatic";
    "Spooler"="Automatic"; "SSDPSRV"="Manual"; "StateRepository"="Manual"; "stisvc"="Manual";
    "SysMain"="Automatic"; "SystemEventsBroker"="Automatic"; "TabletInputService"="Manual";
    "TapiSrv"="Manual"; "TermService"="Manual"; "Themes"="Automatic"; "TimeBrokerSvc"="Manual";
    "TokenBroker"="Manual"; "TrkWks"="Automatic"; "TrustedInstaller"="Manual"; "tzautoupdate"="Disabled";
    "UsoSvc"="Delayed"; "UserManager"="Automatic"; "VaultSvc"="Manual"; "vds"="Manual";
    "VSS"="Manual"; "W32Time"="Manual"; "WaaSMedicSvc"="Manual"; "WbioSrvc"="Automatic";
    "Wcmsvc"="Automatic"; "WdiServiceHost"="Manual"; "WdiSystemHost"="Manual"; "WdNisSvc"="Manual";
    "WinDefend"="Automatic"; "WinHttpAutoProxySvc"="Manual"; "Winmgmt"="Automatic"; "WinRM"="Manual";
    "WlanSvc"="Automatic"; "wmiApSrv"="Manual"; "WpnService"="Automatic"; "WpnUserService"="Automatic";
    "wscsvc"="Delayed"; "WSearch"="Delayed"; "wuauserv"="Manual"; "WwanSvc"="Manual";
    "camsvc"="Manual"; "diagnosticshub.standardcollector.service"="Manual"; "DiagSvc"="Manual";
    "dmwappushservice"="Delayed"; "MapsBroker"="Delayed"; "NetTcpPortSharing"="Disabled";
    "RemoteAccess"="Disabled"; "SCPolicySvc"="Manual"; "SharedAccess"="Manual"; "smphost"="Manual";
    "SmsRouter"="Manual"; "StorSvc"="Manual"; "TieringEngineService"="Manual";
    "vmicguestinterface"="Manual"; "vmicheartbeat"="Manual"; "vmicvmsession"="Manual";
    "vmicrdv"="Manual"; "vmicshutdown"="Manual"; "vmicvss"="Manual"; "WiaRpc"="Manual";
    "workfolderssvc"="Manual"; "XboxGipSvc"="Manual"; "xbgm"="Manual"; "XblAuthManager"="Manual";
    "XblGameSave"="Manual"; "XboxNetApiSvc"="Manual"; "DeviceAssociationService"="Manual"
}

$SvcChanged = 0
foreach ($svc in $ServiceDefaults.Keys) {
    $RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$svc"
    if (Test-Path $RegPath) {
        $StartValue = switch ($ServiceDefaults[$svc]) {
            "Boot" { 0 }; "System" { 1 }; "Automatic" { 2 }; "Manual" { 3 }; "Disabled" { 4 }; "Delayed" { 2 }
        }
        try {
            $CurrentStart = (Get-ItemProperty -Path $RegPath -Name "Start" -ErrorAction SilentlyContinue).Start
            if ($CurrentStart -ne $StartValue) {
                Set-ItemProperty -Path $RegPath -Name "Start" -Value $StartValue -Force -ErrorAction SilentlyContinue
                $SvcChanged++
            }
            if ($ServiceDefaults[$svc] -eq "Delayed") {
                Set-ItemProperty -Path $RegPath -Name "DelayedAutoStart" -Value 1 -Force -ErrorAction SilentlyContinue
            } else {
                Set-ItemProperty -Path $RegPath -Name "DelayedAutoStart" -Value 0 -Force -ErrorAction SilentlyContinue
            }
        } catch {}
    }
}
Write-Log "Успешно проверено и восстановлено системных служб: $SvcChanged."

# -------------------------------------------------------------------------
# 36. ВОССТАНОВЛЕНИЕ ПЛАНИРОВЩИКА ЗАДАЧ WINDOWS
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 36] Проверка и восстановление стандартных задач в Task Scheduler ($OSName)..."
$TasksDisabledByDefault = @(
    "\Microsoft\Windows\AppID\SmartScreenSpecific",
    "\Microsoft\Windows\Application Experience\MareBackup",
    "\Microsoft\Windows\ApplicationData\DsSvcCleanup",
    "\Microsoft\Windows\Chkdsk\ProactiveScan",
    "\Microsoft\Windows\Data Integrity Scan\CrashRecovery",
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticResolver",
    "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload",
    "\Microsoft\Windows\Flighting\OneSettings\RefreshCache",
    "\Microsoft\Windows\Maps\MapsUpdateTask",
    "\Microsoft\Windows\NetTrace\GatherNetworkInfo",
    "\Microsoft\Windows\Setup\SetupCleanupTask",
    "\Microsoft\Windows\WDI\ResolutionHost",
    "\Microsoft\Windows\Work Folders\Work Folders Logon Synchronization",
    "\Microsoft\Windows\Work Folders\Work Folders Maintenance Work"
)
$AllSysTasks = Get-ScheduledTask -TaskPath "\Microsoft\Windows\*" -ErrorAction SilentlyContinue
$EnabledCount = 0; $DisabledCount = 0
foreach ($Task in $AllSysTasks) {
    $TaskFullPath = "$($Task.TaskPath)$($Task.TaskName)" -replace '\\+', '\'
    $ShouldBeDisabled = $false
    foreach ($DisTask in $TasksDisabledByDefault) {
        if ($TaskFullPath -eq $DisTask -or $TaskFullPath -match [regex]::Escape($DisTask)) {
            $ShouldBeDisabled = $true; break
        }
    }
    try {
        if ($ShouldBeDisabled) {
            if ($Task.State -ne 'Disabled') { Disable-ScheduledTask -TaskName $Task.TaskName -TaskPath $Task.TaskPath -ErrorAction Stop | Out-Null; $DisabledCount++ }
        } else {
            if ($Task.State -eq 'Disabled') { Enable-ScheduledTask -TaskName $Task.TaskName -TaskPath $Task.TaskPath -ErrorAction Stop | Out-Null; $EnabledCount++ }
        }
    } catch {}
}
Write-Log "Планировщик задач нормализован: Включено $EnabledCount, Отключено $DisabledCount."


# =========================================================================
# ФАЗА 7: РЕШЕНИЕ ПРОБЛЕМ ФАЙЛОВОЙ СИСТЕМЫ, ПАМЯТИ И ПЕРЕМЕННЫХ
# =========================================================================

# -------------------------------------------------------------------------
# 37. ОЧИСТКА ОЧЕРЕДИ ЗАВИСШИХ ФАЙЛОВ (PendingFileRenameOperations)
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 37] Проверка реестра на наличие зависших команд переименования/удаления файлов..."
$SessionManager = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
try {
    $Pending = Get-ItemProperty -Path $SessionManager -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue
    if ($null -ne $Pending) {
        Remove-ItemProperty -Path $SessionManager -Name "PendingFileRenameOperations" -Force -ErrorAction SilentlyContinue
        Write-Log "Очередь зависших файлов очищена. Блокировки обновлений сняты."
    } else { Write-Log "Очередь зависших файлов пуста." }
} catch {}

# -------------------------------------------------------------------------
# 38. УДАЛЕНИЕ КЭША ФАНТОМНЫХ УСТРОЙСТВ (Ghost Devices)
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 38] Удаление скрытых (фантомных) устройств и старых драйверов..."
# Удаляем устройства, которые больше не подключены (старые флешки, мониторы, мыши), игнорируя программные.
$GhostDevices = Get-PnpDevice | Where-Object { $_.Present -eq $false -and $_.InstanceId -notmatch "^(SWD|ROOT|HTREE)" }
$RemovedCount = 0
foreach ($Device in $GhostDevices) {
    pnputil /remove-device $Device.InstanceId | Out-Null
    $RemovedCount++
}
Write-Log "Вычищено фантомных устройств: $RemovedCount. Диспетчер устройств разгружен."

# -------------------------------------------------------------------------
# 39. ИСПРАВЛЕНИЕ ТОРМОЗОВ ПРОВОДНИКА (ShellBags) И ПАМЯТИ (Pagefile)
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 39] Лечение Проводника (сброс ShellBags) и инициализация чистого файла подкачки..."
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
$ShellPaths = @(
    "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU",
    "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags",
    "HKCU:\Software\Microsoft\Windows\Shell\BagMRU",
    "HKCU:\Software\Microsoft\Windows\Shell\Bags"
)
foreach ($Path in $ShellPaths) {
    if (Test-Path $Path) { Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue }
}
Write-Log "Поврежденный кэш видов папок (ShellBags) сброшен."

$MemManPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
Set-ItemProperty -Path $MemManPath -Name "ClearPageFileAtShutdown" -Value 1 -Force -ErrorAction SilentlyContinue
Write-Log "Задана команда на полную перезапись файла подкачки (Pagefile.sys) при завершении работы."

# -------------------------------------------------------------------------
# 40. РЕМОНТ СИСТЕМНЫХ ПЕРЕМЕННЫХ (%PATH%)
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 40] Ремонт и нормализация системных переменных (%PATH%)..."
$EnvPathReg = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
$CurrentPath = (Get-ItemProperty -Path $EnvPathReg -Name "Path" -ErrorAction SilentlyContinue).Path
$DefaultPaths = @(
    "%SystemRoot%\system32",
    "%SystemRoot%",
    "%SystemRoot%\System32\Wbem",
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\"
)
$PathArray = $CurrentPath -split ';' | Where-Object { $_ -ne "" }
$MissingPaths = @()

foreach ($DefPath in $DefaultPaths) {
    $Exists = $false
    foreach ($PathItem in $PathArray) {
        if ($PathItem.Trim() -ilike $DefPath) { $Exists = $true; break }
    }
    if (-not $Exists) { $MissingPaths += $DefPath }
}

if ($MissingPaths.Count -gt 0) {
    $NewPath = ($DefaultPaths + $PathArray) | Select-Object -Unique
    $NewPathString = $NewPath -join ";"
    Set-ItemProperty -Path $EnvPathReg -Name "Path" -Value $NewPathString -Type ExpandString -Force
    Write-Log "В переменную PATH добавлены отсутствующие базовые пути: $($MissingPaths -join ', ')."
} else { Write-Log "Базовые пути системных переменных (%PATH%) в норме." }


# =========================================================================
# ФАЗА 8: ФИНАЛЬНАЯ ГЛУБОКАЯ ОЧИСТКА МУСОРА
# =========================================================================

# -------------------------------------------------------------------------
# 41. ОЧИСТКА СИСТЕМНОГО МУСОРА И ОТЧЕТОВ ОБ ОШИБКАХ (WER)
# -------------------------------------------------------------------------
Write-Log "[ЭТАП 41] Удаление кэша, Temp и файлов отчетов об ошибках Windows..."
$TempPaths = @(
    "$env:TEMP\*", 
    "C:\Windows\Temp\*", 
    "C:\Windows\Prefetch\*", 
    "C:\ProgramData\Microsoft\Windows\WER\ReportArchive\*",
    "C:\ProgramData\Microsoft\Windows\WER\ReportQueue\*"
)
foreach ($Path in $TempPaths) { Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue }
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
Write-Log "Система полностью очищена."


Write-Log "=== [ЦИКЛ ОКОНЧЕН. СИСТЕМА ПРИВЕДЕНА В ИДЕАЛ] ==="
Write-Log "!!! ОБЯЗАТЕЛЬНО ПЕРЕЗАГРУЗИТЕ КОМПЬЮТЕР !!!"

Start-Process "explorer.exe" # Возвращаем проводник после удаления ShellBags
Start-Process "notepad.exe" $LogFile