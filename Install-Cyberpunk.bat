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
