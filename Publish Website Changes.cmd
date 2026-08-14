@echo off
setlocal
cd /d "%~dp0"
title Publish Website Changes

set "workflow_script=%~dp0scripts\authoring\Publish-Changes.ps1"

if not exist "%workflow_script%" (
	echo.
	echo The publishing script is missing.
	echo Expected: %workflow_script%
	if not "%WEBSITE_WORKFLOW_NO_PAUSE%"=="1" pause
	exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%workflow_script%" %*
set "workflow_exit=%ERRORLEVEL%"

echo.
if not "%workflow_exit%"=="0" (
	echo Publishing stopped with an error.
	echo Nothing was pushed. Read the message above, then run this launcher again when ready.
) else (
	echo Done.
)

if not "%WEBSITE_WORKFLOW_NO_PAUSE%"=="1" pause
exit /b %workflow_exit%
