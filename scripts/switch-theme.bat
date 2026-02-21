@echo off
REM Bank of Mantle Theme Switcher Script (Windows)
REM Usage: scripts\switch-theme.bat <theme-name>

setlocal

set THEME=%1
set FRONTEND_DIR=frontend
set GLOBALS_CSS=%FRONTEND_DIR%\app\globals.css
set THEMES_DIR=%FRONTEND_DIR%\styles\themes

if "%THEME%"=="" (
  echo Error: No theme specified
  echo.
  echo Usage: scripts\switch-theme.bat ^<theme-name^>
  echo.
  echo Available themes:
  echo   classic      - Classic Banking ^(navy ^& gold^)
  echo   cyberpunk    - DeFi Cyberpunk ^(neon future^)
  echo   terminal     - Terminal Hacker ^(Matrix green^)
  echo   nordic       - Minimalist Nordic ^(Scandinavian clean^)
  echo   maximalist   - Gradient Maximalist ^(bold ^& colorful^)
  echo   neumorphic   - Dark Neumorphic ^(soft ^& tactile^)
  exit /b 1
)

REM Map theme names to files
if "%THEME%"=="classic" (
  set THEME_FILE=classic-banking.css
  set THEME_NAME=Classic Banking
) else if "%THEME%"=="cyberpunk" (
  set THEME_FILE=defi-cyberpunk.css
  set THEME_NAME=DeFi Cyberpunk
) else if "%THEME%"=="terminal" (
  set THEME_FILE=terminal-hacker.css
  set THEME_NAME=Terminal Hacker
) else if "%THEME%"=="nordic" (
  set THEME_FILE=minimalist-nordic.css
  set THEME_NAME=Minimalist Nordic
) else if "%THEME%"=="maximalist" (
  set THEME_FILE=gradient-maximalist.css
  set THEME_NAME=Gradient Maximalist
) else if "%THEME%"=="neumorphic" (
  set THEME_FILE=dark-neumorphic.css
  set THEME_NAME=Dark Neumorphic
) else (
  echo Error: Unknown theme '%THEME%'
  echo Available themes: classic, cyberpunk, terminal, nordic, maximalist, neumorphic
  exit /b 1
)

REM Check if theme file exists
if not exist "%THEMES_DIR%\%THEME_FILE%" (
  echo Error: Theme file not found: %THEMES_DIR%\%THEME_FILE%
  exit /b 1
)

REM Backup current globals.css
echo Creating backup...
copy "%GLOBALS_CSS%" "%GLOBALS_CSS%.backup" >nul

REM Create new globals.css with Tailwind directives
echo Applying theme: %THEME_NAME%

(
echo @import "@fontsource/inter/400.css";
echo @import "@fontsource/inter/500.css";
echo @import "@fontsource/inter/600.css";
echo @import "@fontsource/inter/700.css";
echo @import "@fontsource/space-grotesk/400.css";
echo @import "@fontsource/space-grotesk/500.css";
echo @import "@fontsource/space-grotesk/600.css";
echo @import "@fontsource/space-grotesk/700.css";
echo.
echo @tailwind base;
echo @tailwind components;
echo @tailwind utilities;
echo.
) > "%GLOBALS_CSS%"

REM Append theme content
type "%THEMES_DIR%\%THEME_FILE%" >> "%GLOBALS_CSS%"

echo.
echo [SUCCESS] Theme switched to: %THEME_NAME%
echo.
echo Next steps:
echo 1. Restart dev server: cd frontend ^&^& npm run dev
echo 2. Backup saved to: %GLOBALS_CSS%.backup
echo.
echo Note: Some themes may require additional font installations.
echo See THEME_SWITCHER_GUIDE.md for details.

endlocal
