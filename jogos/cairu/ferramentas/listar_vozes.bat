@echo off
rem Lista as falas do Breno com o nome do audio de cada uma (VOZES_BRENO.txt).
rem Os audios vao em audio\vozes\<arquivo>.ogg ao lado do JOGO.exe.
cd /d "%~dp0"
start "" /wait JOGO.exe --listar_vozes breno
start "" notepad VOZES_BRENO.txt
