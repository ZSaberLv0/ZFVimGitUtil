@echo off
setlocal
setlocal enabledelayedexpansion

set WORK_DIR=%~dp0
set PROJ_PATH=%~1%
set GIT_USER_EMAIL=%~2%
set GIT_USER_NAME=%~3%
set GIT_USER_TOKEN=%~4%
if not defined PROJ_PATH goto :usage
goto :run
:usage
echo hard remove all git history and branches (except HEAD)
echo usage:
echo   git_hard_remove_all_history.bat PROJ_PATH
echo NOTE:
echo   local changes would be discarded
echo   you would loose all history and all branches except HEAD
exit /b 1
:run

if not exist "%PROJ_PATH%\.git" (
    echo not a git repo
    exit /b 1
)

set _OLD_DIR=%cd%
cd /d "%PROJ_PATH%"

for /f "delims=" %%a in ('git remote -v ^| findstr "(push)"') do @set REMOTE_URL=%%a
set REMOTE_URL=!REMOTE_URL:origin	=!
set REMOTE_URL=!REMOTE_URL: (push)=!
set REMOTE_URL=!REMOTE_URL:://=://%GIT_USER_NAME%:%GIT_USER_TOKEN%@!

for /f "delims=" %%a in ('git rev-parse --abbrev-ref HEAD') do @set BRANCH=%%a
if not defined BRANCH (
    echo unable to parse git branch name
    exit /b 1
)
if "%BRANCH%" == "" (
    echo unable to parse git branch name
    exit /b 1
) else (
    if "%BRANCH%" == "HEAD" (
        echo unable to parse git branch name, maybe in detached HEAD?
        exit /b 1
    )
)

git checkout .
git fetch "%REMOTE_URL%" +refs/heads/*:refs/remotes/origin/*
git reset --hard origin/%BRANCH%
git clean -xdf
git pull "%REMOTE_URL%"

set _TMP_DIR=_git_hard_remove_all_history_tmp_
mkdir %_TMP_DIR%

REM the shitty dos batch unable to `move` dirs with dot prefix that has contents
REM move ".git" "%_TMP_DIR%\"
xcopy /s/e/y/r/h ".git" "%_TMP_DIR%\.git\" >nul 2>&1
del /f/s/q ".git" >nul 2>&1
rmdir /s/q ".git" >nul 2>&1

set _PROJ_DIR=%cd%
cd "%_TMP_DIR%"
git checkout .
git reset --hard
git clean -xdf

git filter-branch --force --index-filter "git rm --cached --ignore-unmatch *" --prune-empty --tag-name-filter cat -- --all

cd "%_PROJ_DIR%"

REM move "%_TMP_DIR%\.git" ".\"
mkdir .git
xcopy /s/e/y/r/h "%_TMP_DIR%\.git" ".git\" >nul 2>&1
del /f/s/q "%_TMP_DIR%\.git" >nul 2>&1
rmdir /s/q "%_TMP_DIR%\.git" >nul 2>&1

del /f/s/q "%_TMP_DIR%"
rmdir /s/q "%_TMP_DIR%"

git add -A
git commit -a -m "cleanup history"
git config push.default "simple"

set GIT_INFO_EXIST=1
if not defined GIT_USER_EMAIL set GIT_INFO_EXIST=
if not defined GIT_USER_NAME set GIT_INFO_EXIST=
if not defined GIT_USER_TOKEN set GIT_INFO_EXIST=

git config user.email "%GIT_USER_EMAIL%"
git config user.name "%GIT_USER_NAME%"
if not defined GIT_INFO_EXIST (
    git push --force
    goto :push_finish
)

git push --force "%REMOTE_URL%" HEAD

:push_finish
del /f/s/q ".git\refs\original" >nul 2>&1
rmdir /s/q ".git\refs\original" >nul 2>&1
git fetch "%REMOTE_URL%" +refs/heads/*:refs/remotes/origin/*
git reflog expire --expire=now --all
git gc --prune=now

cd "%_OLD_DIR%"

