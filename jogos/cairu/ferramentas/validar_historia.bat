@echo off
rem Confere as historias (capitulos\*.txt e *.json) e abre a lista de erros.
cd /d "%~dp0"
start "" /wait JOGO.exe --validar
start "" notepad ERROS_HISTORIA.txt
