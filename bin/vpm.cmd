@echo off
setlocal enabledelayedexpansion

:: Try to find git.exe in path
for /f "tokens=*" %%G in ('where git 2^>nul') do set "vpm_git_path=%%~dpG"
if not defined vpm_git_path (
  :: Try to find git.exe in GitHub Desktop, oldest first so we end with newest
  for /f "tokens=*" %%d in ('dir /b /s /a:d /od "%LOCALAPPDATA%\GitHub\PortableGit*" 2^>nul') do (
    if exist "%%d\cmd\git.exe" set "vpm_git_path=%%d\cmd"
  )
  :: Found one, add it to the path
  if defined vpm_git_path set "Path=!vpm_git_path!;!PATH!"
)

set "maybe_node_gyp_path=%~dp0\..\node_modules\node-gyp\bin\node-gyp.js"
if exist "%maybe_node_gyp_path%" (
  set "npm_config_node_gyp=%maybe_node_gyp_path%"
)

if exist "%~dp0\node.exe" (
  "%~dp0\node.exe" "%~dp0/../lib/cli.js" %*
) else (
  node.exe "%~dp0/../lib/cli.js" %*
)
