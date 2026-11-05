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
  Start-Process $file -WorkingDirectory $dir -Wait
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
