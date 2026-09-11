@echo off
setlocal
cd /d "%~dp0"
title Website Content Workflow

if not exist "%~dp0scripts\authoring\launch-authoring-tools.mjs" (
	echo.
	echo The authoring tools launcher is missing.
	echo Expected: %~dp0scripts\authoring\launch-authoring-tools.mjs
	if not "%WEBSITE_WORKFLOW_NO_PAUSE%"=="1" pause
	exit /b 1
)

node "%~dp0scripts\authoring\launch-authoring-tools.mjs" %*
set "workflow_exit=%ERRORLEVEL%"

echo.
if not "%workflow_exit%"=="0" (
	echo The authoring tools stopped with an error.
) else (
	echo Done.
)

if not "%WEBSITE_WORKFLOW_NO_PAUSE%"=="1" pause
exit /b %workflow_exit%
