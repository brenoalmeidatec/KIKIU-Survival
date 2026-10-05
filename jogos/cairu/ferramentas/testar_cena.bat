@echo off
rem Abre o jogo ja tocando uma cena, sem jogar o capitulo todo (nao mexe no save).
rem Uso: de dois cliques e digite o nome da cena, ou no terminal: testar_cena.bat h3_lucas
cd /d "%~dp0"
set CENA=%~1
if "%CENA%"=="" set /p CENA=Nome da cena (ex.: h3_lucas): 
start "" JOGO.exe --cena %CENA%
