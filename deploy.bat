@echo off
rem Copy this project into the WoW AddOns folder for local testing, then /reload in game.
set SRC=%~dp0
set DST=F:\World of Warcraft\_retail_\Interface\AddOns\OneClickFish

robocopy "%SRC%." "%DST%" *.toc *.lua *.xml /S /XD .git .claude tests docs /NFL /NDL /NJH /NJS /NP
if %ERRORLEVEL% GEQ 8 (
  echo Copy failed.
  exit /b 1
)
echo OneClickFish deployed to "%DST%"
