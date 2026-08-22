@echo off
setlocal enabledelayedexpansion
title MediaDownloader

:: 設定 ANSI Escape Code 支援
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"

:: 設定 Config 路徑與臨時 Cookie 檔案
set "CONFIG_PATH=%USERPROFILE%\Documents\MediaDLConfigs.json"
set "TEMP_COOKIE_FILE=%TEMP%\yt_decrypted_cookie_%RANDOM%.txt"
set "VAULT_KEY=yt_dlp_assistant_secret_key_2026"

:: 初始化/讀取 JSON 配置
call :INIT_AND_LOAD_CONFIG

:: ========================================================
:: 初始化階段 (保留底部狀態列)
:: ========================================================
:INITIALIZATION
cls

for /f %%H in ('powershell -NoProfile -Command "[Console]::WindowHeight"') do set "WIN_HEIGHT=%%H"
set /a SCROLL_BOTTOM=%WIN_HEIGHT% - 2

echo %ESC%[1;%SCROLL_BOTTOM%r
echo %ESC%[%WIN_HEIGHT%;1HInitialization...
echo %ESC%[1;1H

winget install yt-dlp.yt-dlp --accept-source-agreements --accept-package-agreements
winget install yt-dlp.FFmpeg --accept-source-agreements --accept-package-agreements
yt-dlp -U
winget upgrade yt-dlp.FFmpeg --accept-source-agreements --accept-package-agreements

echo %ESC%[r
cls

:: ========================================================
:: 主選單 (置中渲染、狀態自適應)
:: ========================================================
:MAIN_MENU
cls
echo %ESC%[?25l

:: 動態判斷 Cookie 顯示狀態
if "%CFG_COOKIE_TOGGLE%"=="1" (
    if defined CFG_COOKIES (
        set "COOKIE_STATUS=Cookie: ON"
    ) else (
        set "COOKIE_STATUS=Cookie: NO FILE"
    )
) else (
    set "COOKIE_STATUS=Cookie: OFF"
)

for /f %%W in ('powershell -NoProfile -Command "[Console]::WindowWidth"') do set "WIN_WIDTH=%%W"
set /a MENU_COL=(!WIN_WIDTH! - 26) / 2 + 1

echo %ESC%[1;!MENU_COL!H
echo %ESC%[2;!MENU_COL!H  Welcome to use Media Downloader
echo %ESC%[3;!MENU_COL!H
echo %ESC%[4;!MENU_COL!H[ L ] Lazy Mode
echo %ESC%[5;!MENU_COL!H[ C ] Cookie Settings (!COOKIE_STATUS!)
echo %ESC%[6;!MENU_COL!H[ S ] Supported Sites
echo %ESC%[7;!MENU_COL!H[ H ] Helps
echo %ESC%[8;!MENU_COL!H[ Q ] Quit

:MAIN_MENU_WAIT
call :GET_KEY "L,C,S,H,Q" KEY_VAL

if /i "%KEY_VAL%"=="L" goto LAZY_TRANSITION
if /i "%KEY_VAL%"=="C" goto COOKIE_MENU
if /i "%KEY_VAL%"=="S" (
    start https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md
    goto MAIN_MENU
)
if /i "%KEY_VAL%"=="H" (
    start https://github.com/yt-dlp/yt-dlp/wiki/FAQ
    goto MAIN_MENU
)
if /i "%KEY_VAL%"=="Q" (
    <nul set /p "=%ESC%[5;!MENU_COL!H[ Q ] Quit (Are you sure?)"
    call :GET_KEY_TIMEOUT "Q" 3 TIMEOUT_KEY
    if /i "!TIMEOUT_KEY!"=="Q" (
        echo %ESC%[?25h
        exit /b
    )
    <nul set /p "=%ESC%[5;!MENU_COL!H[ Q ] Quit                 "
    goto MAIN_MENU_WAIT
)
goto MAIN_MENU_WAIT

:: ========================================================
:: Cookie 設定子選單
:: ========================================================
:COOKIE_MENU
cls
echo %ESC%[?25l

for /f %%W in ('powershell -NoProfile -Command "[Console]::WindowWidth"') do set "WIN_WIDTH=%%W"
set /a C_MENU_COL=(!WIN_WIDTH! - 30) / 2 + 1

if "%CFG_COOKIE_TOGGLE%"=="1" (
    set "TOGGLE_LABEL=[ T ] Disable Cookie"
) else (
    set "TOGGLE_LABEL=[ T ] Enable Cookie"
)

echo %ESC%[1;!C_MENU_COL!H=== Cookie Settings ===
echo %ESC%[2;!C_MENU_COL!H!TOGGLE_LABEL!
echo %ESC%[3;!C_MENU_COL!H[ I ] Import Vault (.ytdlp-vault)
echo %ESC%[4;!C_MENU_COL!H[ D ] Delete Stored Cookie
echo %ESC%[5;!C_MENU_COL!H[ B ] Back to Main Menu

:COOKIE_MENU_WAIT
call :GET_KEY "T,I,D,B" C_KEY

if /i "%C_KEY%"=="T" (
    if "%CFG_COOKIE_TOGGLE%"=="1" (
        set "CFG_COOKIE_TOGGLE=0"
    ) else (
        set "CFG_COOKIE_TOGGLE=1"
    )
    call :SAVE_CONFIG
    goto COOKIE_MENU
)
if /i "%C_KEY%"=="I" (
    cls
    echo %ESC%[?25l
    echo [Opening File Dialog...]
    
    :: 呼叫原生 GUI 選擇 .ytdlp-vault
    set "SELECTED_FILE="
    for /f "delims=" %%F in ('powershell -NoProfile -Command ^
        "Add-Type -AssemblyName System.Windows.Forms;" ^
        "$f = New-Object System.Windows.Forms.OpenFileDialog;" ^
        "$f.Filter = 'Vault Files (*.ytdlp-vault)|*.ytdlp-vault|All Files (*.*)|*.*';" ^
        "$f.Title = 'Select YouTube Encrypted Vault File';" ^
        "if ($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output $f.FileName }"') do (
        set "SELECTED_FILE=%%F"
    )

    if defined SELECTED_FILE (
        if exist "!SELECTED_FILE!" (
            :: 讀取加密字串存入變數
            for /f "delims=" %%D in ('powershell -NoProfile -Command "(Get-Content -LiteralPath '!SELECTED_FILE!' -Raw).Trim()"') do (
                set "CFG_COOKIES=%%D"
            )
            :: 刪除原始檔案
            del /f /q "!SELECTED_FILE!" >nul 2>&1
            set "CFG_COOKIE_TOGGLE=1"
            call :SAVE_CONFIG
            echo %ESC%[6;!C_MENU_COL!HVault imported ^& source deleted!
        )
    ) else (
        echo %ESC%[6;!C_MENU_COL!HImport cancelled.
    )
    powershell -NoProfile -Command "Start-Sleep -Milliseconds 800"
    goto COOKIE_MENU
)
if /i "%C_KEY%"=="D" (
    set "CFG_COOKIES="
    call :SAVE_CONFIG
    echo %ESC%[6;!C_MENU_COL!HStored Cookie deleted!
    powershell -NoProfile -Command "Start-Sleep -Milliseconds 600"
    goto COOKIE_MENU
)
if /i "%C_KEY%"=="B" goto MAIN_MENU
goto COOKIE_MENU_WAIT

:: ========================================================
:: 轉場效果
:: ========================================================
:LAZY_TRANSITION
echo %ESC%[8;1H%ESC%[2K
powershell -NoProfile -Command "Start-Sleep -Milliseconds 50"
echo %ESC%[7;1H%ESC%[2K
powershell -NoProfile -Command "Start-Sleep -Milliseconds 50"
echo %ESC%[6;1H%ESC%[2K
powershell -NoProfile -Command "Start-Sleep -Milliseconds 50"
echo %ESC%[5;1H%ESC%[2K
powershell -NoProfile -Command "Start-Sleep -Milliseconds 50"
echo %ESC%[4;1H%ESC%[2K
powershell -NoProfile -Command "Start-Sleep -Milliseconds 50"
echo %ESC%[2;1H%ESC%[2K
echo %ESC%[1;1H%ESC%[2K
powershell -NoProfile -Command "Start-Sleep -Milliseconds 50"
cls

:: ========================================================
:: Lazy Mode
:: ========================================================
:LAZY_MODE
cls
echo %ESC%[?25h
set "TARGET_URL="
set /p "TARGET_URL=Please paste content link here: "

if not defined TARGET_URL goto MAIN_MENU

set "TARGET_URL=%TARGET_URL:"=%"
if "%TARGET_URL%"=="" goto MAIN_MENU

echo.
echo You want save it as [ V ] Video or [ A ] audio or [ C ] cancel download?

echo %ESC%[?25l

:DOWNLOAD_TYPE_CHOICE
call :GET_KEY "V,A,C" FORMAT_CHOICE

if /i "%FORMAT_CHOICE%"=="C" goto MAIN_MENU

if /i "%FORMAT_CHOICE%"=="V" goto DOWNLOAD_VIDEO
if /i "%FORMAT_CHOICE%"=="A" goto DOWNLOAD_AUDIO
goto DOWNLOAD_TYPE_CHOICE

:: ========================================================
:: 下載音訊
:: ========================================================
:DOWNLOAD_AUDIO
cls
echo %ESC%[?25h
echo [Downloading Audio...]
echo.

call :PREPARE_VAULT
yt-dlp "%TARGET_URL%" -o "%CFG_DOWNLOAD_FOLDER%\%%(title)s.%%(ext)s" %ACTIVE_COOKIE_ARG% --extract-audio --audio-format mp3 --audio-quality 0 --no-playlist --embed-thumbnail --convert-thumbnails jpg --embed-metadata
call :CLEANUP_VAULT

goto POST_DOWNLOAD_MENU

:: ========================================================
:: 下載影片
:: ========================================================
:DOWNLOAD_VIDEO
cls
echo %ESC%[?25h
echo [Downloading Video...]
echo.

call :PREPARE_VAULT
yt-dlp "%TARGET_URL%" -o "%CFG_DOWNLOAD_FOLDER%\%%(title)s.%%(ext)s" %ACTIVE_COOKIE_ARG% -f "bv*[vcodec^=avc1]+ba[ext=m4a]/b[ext=mp4]/b" --no-playlist --embed-thumbnail --convert-thumbnails jpg --embed-metadata
call :CLEANUP_VAULT

goto POST_DOWNLOAD_MENU

:: ========================================================
:: 下載完成後的選單 (保留 Log，不溢位換行)
:: ========================================================
:POST_DOWNLOAD_MENU
echo.
echo.
echo.
echo.
echo.
echo %ESC%[?25l

for /f %%W in ('powershell -NoProfile -Command "[Console]::WindowWidth"') do set "WIN_WIDTH=%%W"
for /f %%R in ('powershell -NoProfile -Command "[Console]::CursorTop"') do set "CURRENT_ROW=%%R"

set /a POST_COL=(!WIN_WIDTH! - 24) / 2 + 1
set /a R1=!CURRENT_ROW! - 4
set /a R2=!CURRENT_ROW! - 3
set /a R3=!CURRENT_ROW! - 2
set /a R4=!CURRENT_ROW! - 1

<nul set /p "=%ESC%[!R1!;1H%ESC%[2K%ESC%[!R1!;!POST_COL!H------------------------"
<nul set /p "=%ESC%[!R2!;1H%ESC%[2K%ESC%[!R2!;!POST_COL!H[ K ] Keep use Lazy Mode"
<nul set /p "=%ESC%[!R3!;1H%ESC%[2K%ESC%[!R3!;!POST_COL!H[ O ] Open folder"
<nul set /p "=%ESC%[!R4!;1H%ESC%[2K%ESC%[!R4!;!POST_COL!H[ Q ] Quit"

:POST_MENU_WAIT
call :GET_KEY "K,O,Q" POST_CHOICE

if /i "%POST_CHOICE%"=="K" goto LAZY_MODE
if /i "%POST_CHOICE%"=="O" (
    explorer.exe "%CFG_DOWNLOAD_FOLDER%"
    goto POST_MENU_WAIT
)
if /i "%POST_CHOICE%"=="Q" (
    <nul set /p "=%ESC%[!R4!;1H%ESC%[2K%ESC%[!R4!;!POST_COL!H[ Q ] Quit (Are you sure?)"
    call :GET_KEY_TIMEOUT "Q" 3 TIMEOUT_KEY
    if /i "!TIMEOUT_KEY!"=="Q" (
        echo %ESC%[?25h
        exit /b
    )
    <nul set /p "=%ESC%[!R4!;1H%ESC%[2K%ESC%[!R4!;!POST_COL!H[ Q ] Quit"
    goto POST_MENU_WAIT
)
goto POST_MENU_WAIT

:: ========================================================
:: JSON 配置讀寫與即時解密系統
:: ========================================================
:INIT_AND_LOAD_CONFIG
powershell -NoProfile -Command ^
    "$path = '%CONFIG_PATH%';" ^
    "if (-not (Test-Path $path)) {" ^
    "  $init = @{ Cookies = ''; CookieToggle = 0; DownloadFolder = ($env:USERPROFILE + '\Downloads') };" ^
    "  $init | ConvertTo-Json | Set-Content -Path $path -Encoding UTF8;" ^
    "}"
:: 載入變數
for /f "delims=" %%A in ('powershell -NoProfile -Command ^
    "$cfg = Get-Content -Raw '%CONFIG_PATH%' | ConvertFrom-Json;" ^
    "Write-Output ('CFG_COOKIES=' + $cfg.Cookies);" ^
    "Write-Output ('CFG_COOKIE_TOGGLE=' + $cfg.CookieToggle);" ^
    "Write-Output ('CFG_DOWNLOAD_FOLDER=' + $cfg.DownloadFolder);"') do (
    set "%%A"
)
if not exist "%CFG_DOWNLOAD_FOLDER%" mkdir "%CFG_DOWNLOAD_FOLDER%" >nul 2>&1
goto :eof

:SAVE_CONFIG
powershell -NoProfile -Command ^
    "$cfg = @{" ^
    "  Cookies = '%CFG_COOKIES%';" ^
    "  CookieToggle = [int]'%CFG_COOKIE_TOGGLE%';" ^
    "  DownloadFolder = '%CFG_DOWNLOAD_FOLDER%';" ^
    "};" ^
    "$cfg | ConvertTo-Json | Set-Content -Path '%CONFIG_PATH%' -Encoding UTF8;" >nul 2>&1
goto :eof

:PREPARE_VAULT
set "ACTIVE_COOKIE_ARG="
if "%CFG_COOKIE_TOGGLE%"=="1" (
    if defined CFG_COOKIES (
        powershell -NoProfile -Command ^
            "try {" ^
            "  $keyStr = '%VAULT_KEY%'.PadRight(32, '0').Substring(0,32);" ^
            "  $key = [System.Text.Encoding]::UTF8.GetBytes($keyStr);" ^
            "  $data = [System.Convert]::FromBase64String('%CFG_COOKIES%');" ^
            "  $iv = New-Object byte[] 16;" ^
            "  [System.Array]::Copy($data, 0, $iv, 0, 16);" ^
            "  $cipher = New-Object byte[] ($data.Length - 16);" ^
            "  [System.Array]::Copy($data, 16, $cipher, 0, $cipher.Length);" ^
            "  $aes = [System.Security.Cryptography.Aes]::Create();" ^
            "  $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC;" ^
            "  $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7;" ^
            "  $dec = $aes.CreateDecryptor($key, $iv);" ^
            "  $plain = $dec.TransformFinalBlock($cipher, 0, $cipher.Length);" ^
            "  [System.IO.File]::WriteAllBytes('%TEMP_COOKIE_FILE%', $plain);" ^
            "} catch {}" >nul 2>&1
            
        if exist "%TEMP_COOKIE_FILE%" (
            set "ACTIVE_COOKIE_ARG=--cookies ^"%TEMP_COOKIE_FILE%^""
        )
    )
)
goto :eof

:CLEANUP_VAULT
if exist "%TEMP_COOKIE_FILE%" del /f /q "%TEMP_COOKIE_FILE%" >nul 2>&1
goto :eof

:GET_KEY
for /f "delims=" %%k in ('powershell -NoProfile -Command "$keys = '%~1' -split ','; do { $k = [Console]::ReadKey($true).KeyChar.ToString().ToUpper() } until ($keys -contains $k); Write-Host $k"') do set "%~2=%%k"
goto :eof

:GET_KEY_TIMEOUT
for /f "delims=" %%k in ('powershell -NoProfile -Command "$keys = '%~1' -split ','; $start = [DateTime]::Now; $timeout = %~2; while (([DateTime]::Now - $start).TotalSeconds -lt $timeout) { if ([Console]::KeyAvailable) { $k = [Console]::ReadKey($true).KeyChar.ToString().ToUpper(); if ($keys -contains $k) { Write-Host $k; exit } } Start-Sleep -Milliseconds 50 }; Write-Host 'TIMEOUT'"') do set "%~3=%%k"
goto :eof