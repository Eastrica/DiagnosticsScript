<div align="center">
  
  ![PowerShell](https://img.shields.io/badge/PowerShell-%235391FE.svg?style=for-the-badge&logo=powershell&logoColor=white)
  ![Windows 10/11](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)
  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

  <h1>Eastrica OS Heal & Diagnostics</h1>
  <p>🇷🇺 Полное руководство на русском | 🇬🇧 English documentation below</p>

</div>

---

## 🇷🇺 Русский (Russian)

**Eastrica OS Heal** — это мощный, комплексный PowerShell-скрипт (41 этап) для глубокой диагностики, восстановления и оптимизации операционных систем Windows 10 и Windows 11. Скрипт предназначен для системных администраторов и продвинутых пользователей. Он автоматически устраняет критические сбои, восстанавливает системные компоненты к заводским параметрам и очищает систему от мусора.

### ⚙️ Основные возможности (8 Фаз работы)

1. **Безопасность, Среда и Криптография**
   - Активация WinRE и меню F8, перезапуск служб теневого копирования (VSS) и создание точки восстановления.
   - Синхронизация времени (NTP), обновление корневых сертификатов (Root CA) и сброс URL-кэша криптографии.
2. **Аппаратная диагностика и анализ журналов**
   - Опрос S.M.A.R.T. накопителей, проверка ошибок RAM (WHEA-Logger).
   - Умный анализ EventLog (сеть и диски) и автоматический анализатор дампов памяти (BSOD) с помощью BlueScreenView.
3. **Базы данных, Права доступа и Ядро**
   - Сброс прав доступа NTFS и реестра (SecEdit), удаление принудительных GPO.
   - Восстановление базы WMI, перерегистрация системных DLL, сброс кэшей (Search, эскизы, шрифты, уведомления).
   - Глубокое восстановление ядра через DISM и SFC, очистка WinSxS.
4. **Обновления, Сеть, Периферия и Службы**
   - Сброс BITS, кэша Windows Update и Оптимизации доставки.
   - Очистка HOSTS, сброс TCP/IP, прокси, брандмауэра и очередей печати.
   - Программный перезапуск сбойных устройств (Коды 43/10), сброс схем питания и отключение Быстрого запуска (Fast Startup).
5. **Приложения, Софт и Антивирус**
   - Сброс подсистемы UWP и кэша Microsoft Store.
   - Авто-обновление стороннего ПО через Winget, обновление баз и запуск сканирования Windows Defender.
6. **Системные службы и Планировщик (Default Restore)**
   - Возврат всех системных служб Windows к эталонным заводским параметрам (учитывается версия ОС).
   - Нормализация стандартных задач в Планировщике Windows (Task Scheduler).
7. **Файловая система, Память и Переменные**
   - Очистка очереди зависших файлов на удаление/переименование.
   - Удаление кэша фантомных устройств, исправление Проводника (ShellBags).
   - Настройка очистки Pagefile при выключении и ремонт переменных среды `%PATH%`.
8. **Финальная глубокая очистка**
   - Тотальное удаление системного мусора, Temp-файлов, Prefetch и отчетов об ошибках Windows (WER).

### 🚀 Как использовать

> **ВНИМАНИЕ:** Скрипт вносит глубокие системные изменения. Строго рекомендуется понимать, что именно делает код. 

1. Скачайте файл `EastricaDiagnosticsScript.ps1`.
2. Нажмите на файл правой кнопкой мыши и выберите **"Запустить с помощью PowerShell"** (или запустите консоль PowerShell от имени Администратора и укажите путь к файлу).
3. **Скрипт требует прав Администратора.** Если их нет, он автоматически остановит работу.
4. Дождитесь окончания работы (отчет будет сохранен в `C:\Eastrica_OS_Heal_Report.txt` и автоматически открыт в Блокноте).
5. **Обязательно перезагрузите компьютер** после завершения!

---

## 🇬🇧 English (Английский)

**Eastrica OS Heal** is a powerful, comprehensive PowerShell script (41 steps) for deep diagnostics, recovery, and optimization of Windows 10 and Windows 11 operating systems. Designed for system administrators and power users, it automatically resolves critical errors, resets system components to factory defaults, and performs deep cleanup.

### ⚙️ Core Features (8 Phases)

1. **Security, Environment & Cryptography**
   - Activation of WinRE & F8 boot menu, VSS service restart, and Restore Point creation.
   - Time synchronization (NTP), Root CA certificates update, and cryptographic URL cache reset.
2. **Hardware Diagnostics & Log Analysis**
   - S.M.A.R.T. disk health polling, RAM hardware error check (WHEA-Logger).
   - Smart EventLog analysis (Network & Disk) and automated BSOD dump analysis via BlueScreenView.
3. **Databases, Permissions & Kernel**
   - Factory reset of NTFS and Registry permissions (SecEdit), forced GPO removal.
   - WMI repository rebuild, critical system DLLs re-registration, cache resets (Search, Thumbnails, Fonts, Notifications).
   - Deep kernel repair using DISM and SFC, WinSxS component store cleanup.
4. **Updates, Network, Peripherals & Services**
   - Reset of BITS, Windows Update cache, and Delivery Optimization.
   - HOSTS file sanitization, TCP/IP tuning, proxy/firewall reset, and print spooler cleanup.
   - Soft restart of degraded devices (Code 43/10), power plan reset, and Fast Startup disabling.
5. **Applications, Software & Antivirus**
   - UWP subsystem and Microsoft Store cache reset.
   - Auto-update of third-party software via Winget, Windows Defender signatures update and scan.
6. **System Services & Task Scheduler (Default Restore)**
   - Reverts all Windows system services to their default factory startup types (OS version aware).
   - Normalization of standard tasks in Windows Task Scheduler.
7. **File System, Memory & Environment Variables**
   - Cleanup of pending file rename/delete operations.
   - Removal of ghost devices, File Explorer lag fix (ShellBags reset).
   - Pagefile clear-on-shutdown initialization and `%PATH%` environment variables repair.
8. **Final Deep Cleanup**
   - Complete removal of system junk, Temp files, Prefetch, and Windows Error Reporting (WER) caches.

### 🚀 How to Use

> **WARNING:** This script makes profound system changes. It is strictly recommended to understand what the code does before execution.

1. Download the `EastricaDiagnosticsScript.ps1` file.
2. Right-click the file and select **"Run with PowerShell"** (or open an elevated PowerShell console and run the script).
3. **The script requires Administrator privileges.** It will exit if not elevated.
4. Wait for the execution to finish (a report will be saved to `C:\Eastrica_OS_Heal_Report.txt` and automatically opened in Notepad).
5. **Reboot your PC** once the script finishes!

---

## 📄 Лицензия / License

Этот проект распространяется под лицензией **[MIT License](https://opensource.org/licenses/MIT)**.
This project is licensed under the **[MIT License](https://opensource.org/licenses/MIT)** - see the [LICENSE](LICENSE) file (if provided) or click the link for details.
