@echo off
setlocal
title Cyberpunk theme for Steam
set "CP_SELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t=[IO.File]::ReadAllText($env:CP_SELF,[Text.Encoding]::UTF8); $m='#SCRIPT'+'#'; $e='#PAYLOAD'+'#'; $i=$t.IndexOf($m)+$m.Length; $j=$t.LastIndexOf($e); if($j -lt $i){$j=$t.Length}; & ([scriptblock]::Create($t.Substring($i,$j-$i)))"
echo.
pause
exit /b
#SCRIPT#
# Installs the Cyberpunk theme for Steam. Runs from the single-file Install-Cyberpunk.bat, which carries the theme.
param()
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$ThemeName = 'Cyberpunk'
$InstallerUrl = 'https://github.com/SteamClientHomebrew/Installer/releases/latest/download/MillenniumInstaller-Windows.exe'
$ExpectedSigner = 'SignPath Foundation'
$Self = $env:CP_SELF

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }
function Step($text) { Write-Host ''; Write-Host ">> $text" -ForegroundColor Yellow }
function Fail($text) { throw $text }

function Get-SteamPath {
  $p = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
  if (-not $p -or -not (Test-Path (Join-Path $p 'steam.exe'))) { Fail 'Steam не найден. Установи Steam и запусти установщик ещё раз.' }
  return (Resolve-Path $p).Path
}
function Test-GameRunning {
  $id = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).RunningAppID
  return ($id -and $id -ne 0)
}
function Stop-Steam($steam) {
  if (-not (Get-Process steam -ErrorAction SilentlyContinue)) { return }
  Say 'Закрываю Steam...'
  & (Join-Path $steam 'steam.exe') -shutdown
  $t = 0
  while ((Get-Process steam -ErrorAction SilentlyContinue) -and $t -lt 60) { Start-Sleep 1; $t++ }
  if (Get-Process steam -ErrorAction SilentlyContinue) { Fail 'Steam не закрылся за минуту. Закрой его вручную и запусти установщик ещё раз.' }
}
# Goes through Explorer so Steam never inherits administrator rights from this script.
function Start-Steam { Start-Process explorer.exe 'steam://open/main' }

function Test-Millennium($steam) {
  return (Test-Path (Join-Path $steam 'millennium\lib\millennium.dll')) -or (Test-Path (Join-Path $steam 'wsock32.dll'))
}
function Install-Millennium($steam) {
  Step 'Millennium не найден, скачиваю официальный установщик'
  $dir = Join-Path $env:TEMP ('cyberpunk-millennium-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $dir | Out-Null
  $file = Join-Path $dir 'MillenniumInstaller-Windows.exe'
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest $InstallerUrl -OutFile $file -UseBasicParsing
  $sig = Get-AuthenticodeSignature $file
  if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch [regex]::Escape($ExpectedSigner)) {
    Remove-Item $dir -Recurse -Force
    Fail "Подпись установщика Millennium не прошла проверку ($($sig.Status)). Ничего не установлено."
  }
  Say "Подпись в порядке: $ExpectedSigner" 'Green'
  Say ''
  Say 'Сейчас откроется окно Millennium: нажми в нём кнопку установки и закрой окно, когда закончит.' 'White'
  # Not -Wait: it also waits for child processes, and the Millennium window starts Steam, which keeps running.
  (Start-Process $file -WorkingDirectory $dir -PassThru).WaitForExit()
  Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
  if (-not (Test-Millennium $steam)) { Fail 'Millennium не установился. Запусти установщик ещё раз.' }
  Say 'Millennium установлен.' 'Green'
}
function Wait-MillenniumConfig($steam) {
  $cfg = Join-Path $steam 'millennium\config\config.json'
  if (Test-Path $cfg) { return $cfg }
  Say 'Запускаю Steam, чтобы Millennium создал настройки. Если Steam попросит войти, войди в аккаунт...'
  if (-not (Get-Process steam -ErrorAction SilentlyContinue)) { Start-Steam }
  $t = 0
  while (-not (Test-Path $cfg) -and $t -lt 300) { Start-Sleep 2; $t += 2 }
  if (-not (Test-Path $cfg)) { Fail 'Настройки Millennium не появились за 5 минут. Запусти Steam, дождись входа и запусти установщик ещё раз.' }
  Start-Sleep 5
  return $cfg
}
function Test-Writable($dir) {
  $f = Join-Path $dir ('.cp-write-test-' + [guid]::NewGuid().ToString('N'))
  try { [IO.File]::WriteAllText($f, 'x'); Remove-Item $f -Force; return $true } catch { return $false }
}
function Get-ThemesDir($steam) {
  $new = Join-Path $steam 'millennium\themes'
  $old = Join-Path $steam 'steamui\skins'
  if (Test-Path $new) { return $new }
  if (Test-Path $old) { return $old }
  if (Test-Path (Join-Path $steam 'millennium')) { New-Item -ItemType Directory -Path $new | Out-Null; return $new }
  New-Item -ItemType Directory -Path $old | Out-Null
  return $old
}
function Set-ActiveTheme($cfg, $name) {
  Copy-Item $cfg "$cfg.before-cyberpunk.bak" -Force
  $txt = [IO.File]::ReadAllText($cfg)
  if ($txt -notmatch '"activeTheme"\s*:') { Fail 'В настройках Millennium нет параметра activeTheme: похоже, формат изменился. Выбери тему Cyberpunk вручную в настройках Millennium.' }
  $txt = $txt -replace '"activeTheme"\s*:\s*"[^"]*"', ('"activeTheme": "' + $name + '"')
  $txt = $txt -replace '"allowedStyles"\s*:\s*false', '"allowedStyles": true'
  $txt = $txt -replace '"allowedScripts"\s*:\s*false', '"allowedScripts": true'
  $null = $txt | ConvertFrom-Json   # refuses to save a broken file
  [IO.File]::WriteAllText($cfg, $txt, (New-Object Text.UTF8Encoding $false))
}
function Expand-Theme($target) {
  $text = [IO.File]::ReadAllText($Self, [Text.Encoding]::UTF8)
  $mark = '#PAYLOAD' + '#'
  $i = $text.LastIndexOf($mark)
  if ($i -lt 0) { Fail 'Файл установщика повреждён: внутри нет темы. Скачай его заново.' }
  $b64 = ($text.Substring($i + $mark.Length) -replace '[^A-Za-z0-9+/=]', '')
  $tmp = Join-Path $env:TEMP ('cyberpunk-theme-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $tmp | Out-Null
  $zip = Join-Path $tmp 'theme.zip'
  [IO.File]::WriteAllBytes($zip, [Convert]::FromBase64String($b64))
  Expand-Archive $zip -DestinationPath (Join-Path $tmp 'x')
  if (-not (Test-Path (Join-Path $tmp 'x\skin.json'))) { Remove-Item $tmp -Recurse -Force; Fail 'Файл установщика повреждён: в теме нет skin.json. Скачай его заново.' }
  $dest = Join-Path $target $ThemeName
  if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
  New-Item -ItemType Directory -Path $dest | Out-Null
  Copy-Item (Join-Path $tmp 'x\*') $dest -Recurse -Force
  Remove-Item $tmp -Recurse -Force
  return $dest
}

try {
  Write-Host ''
  Write-Host '  CYBER//DECK :: тема Cyberpunk для Steam' -ForegroundColor Yellow

  $steam = Get-SteamPath
  Say "Steam: $steam"
  if (Test-GameRunning) { Fail 'Сейчас запущена игра. Закрой её и запусти установщик ещё раз.' }

  if (-not (Test-Millennium $steam)) { Install-Millennium $steam } else { Say 'Millennium уже установлен.' 'Green' }

  # Program Files can be read-only for a normal user: ask for rights only when they are really needed.
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin -and -not (Test-Writable $steam)) {
    Say 'Для записи в папку Steam нужны права администратора, Windows спросит разрешение.' 'White'
    Start-Process $Self -Verb RunAs
    return
  }

  $cfg = Wait-MillenniumConfig $steam
  Step 'Ставлю тему'
  Stop-Steam $steam
  $dest = Expand-Theme (Get-ThemesDir $steam)
  Say "Тема скопирована: $dest"
  Set-ActiveTheme $cfg $ThemeName
  Say 'Тема включена.' 'Green'

  Step 'Запускаю Steam'
  Start-Steam
  Write-Host ''
  Write-Host 'Готово! Эффекты можно отключить в настройках темы в Millennium.' -ForegroundColor Green
}
catch {
  Write-Host ''
  Write-Host "Ошибка: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}

#PAYLOAD#
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
