# ARASAKA: тема для Steam

Корпоративный интерфейс Arasaka для Steam: графитовые панели, прямоугольная геометрия, серебристая типографика и точечные красные акценты. Эмблема в шапке, компактная строка состояния и короткая заставка терминала.

Работает через загрузчик [Millennium](https://steambrew.app/).

## Установка

1. Скачай [`Install-Cyberpunk.bat`](Install-Cyberpunk.bat) (кнопка **Download raw file**).
2. Запусти его двойным кликом.

Если Windows покажет предупреждение SmartScreen, нажми «Подробнее» → «Выполнить в любом случае». Такое бывает с любым скачанным `.bat`.

Что делает установщик:

- находит Steam;
- если Millennium ещё нет, скачивает официальный установщик и проверяет его подпись (в окне Millennium нужно будет нажать установку);
- закрывает Steam, копирует тему, включает её и запускает Steam снова.

Запущенную игру он не трогает: попросит сначала её закрыть. Если папка Steam закрыта для записи, Windows спросит права администратора.

## Настройки

В настройках темы в Millennium можно выбрать цветовую схему (кислотный жёлтый, кровавый красный, ледяной голубой, токсичный зелёный, неоновый фиолетовый, горячий розовый) и отключить заставку и HUD. После смены схемы перезапусти Steam.

## Удаление

Запусти [`Uninstall-Cyberpunk.bat`](Uninstall-Cyberpunk.bat). Он удалит тему и вернёт стандартный вид. Сам Millennium останется, его можно удалить по [инструкции проекта](https://docs.steambrew.app/users/getting-started/installation).

## Что нужно знать

- Millennium и такие темы Valve официально не поддерживает.
- После обновлений Steam часть стилей может слетать, особенно в магазине: там классы генерируются автоматически.
- В первые мгновения экран входа остаётся стандартным: окно открывается раньше, чем Millennium подключает стиль.

## Разработка

Стили лежат в `theme/`, скрипты установщика в `installer/`. После правок пересобери `.bat`:

```bash
powershell -ExecutionPolicy Bypass -File build.ps1
```

Изменения темы применяются после перезапуска Steam.

## Arasaka edition (1.2.0)

Красно-чёрное оформление в одном стиле с Windows Cyberdeck: красный ED2438, графитовые панели, серебристый текст, эмблема и корпоративная заставка Arasaka. Схема Arasaka выбрана по умолчанию; остальные цветовые варианты, переключатели заставки и HUD сохранены. Внутреннее имя Cyberpunk оставлено для совместимости установщика: новая версия обновляет существующую тему. Если раньше выбиралась другая схема, выбери Arasaka в настройках Millennium.

Исходная база: 7e40071. Изменены все пять поверхностей (библиотека/диалоги, друзья/чат, вход, уведомления, веб-страницы). Внешний вид в запущенном Steam требуется проверить после установки.

## Corporate redesign (2.0.0)

Интерфейс переработан вокруг спокойного рабочего пространства Arasaka. Убраны сканлайны, случайные разрывы сигнала, мерцание, двоение обложек и бегущая лента. Навигация использует тонкие маркеры, выделения — тёмные подложки, обложки — прямоугольники. Новый JS создаёт эмблему, служебную строку с настоящим временем и длительностью сеанса, короткую заставку. Таймеры освобождаются при pagehide; reduced-motion отключает заставку. Никаких запросов к сети или чтения данных Steam.

Проверено на текущем ПК в Steam: магазин, главная библиотеки и страница игры. Переключатели, уведомления, чат и уменьшенное окно отдельно визуально не проверены. Имя Cyberpunk и имена файлов установщика сохранены для обновления прежней установки.

## Branding and sign-in loading

The sign-in spinner is replaced with the Arasaka emblem and a narrow animated connection indicator, with reduced-motion support. Known Steam logo selectors in the menu, website header and notifications receive the emblem. Avatar and game images are not targeted. Hashed fallback selectors come from this installed Steam build and can change after updates.

System tray and running application's taskbar icons are controlled by Steam's native executable, outside Millennium CSS. This theme does not patch the executable. Replacing every Steam icon is therefore not guaranteed. The login window is transient; the new spinner still needs a visual check during the next sign-in.
