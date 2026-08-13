@echo off
setlocal
cd /d "%~dp0"
title Website Content Workflow

if not exist "%~dp0Start Website Content Workflow.ps1" (
	echo.
	echo The PowerShell workflow entry point is missing.
	echo Expected: %~dp0Start Website Content Workflow.ps1
	if not "%WEBSITE_WORKFLOW_NO_PAUSE%"=="1" pause
	exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start Website Content Workflow.ps1" %*
set "workflow_exit=%ERRORLEVEL%"

echo.
if not "%workflow_exit%"=="0" (
	echo The website workflow stopped with an error.
	echo Read the message above, then run this launcher again when ready.
) else (
	echo This workflow step is complete.
	echo Double-click this launcher again to continue the saved batch.
)

if not "%WEBSITE_WORKFLOW_NO_PAUSE%"=="1" pause
exit /b %workflow_exit%
