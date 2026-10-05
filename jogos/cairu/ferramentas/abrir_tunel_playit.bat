@echo off
chcp 65001 >nul
title Tunel do JOGO (playit.gg)
cd /d "%~dp0"
echo ============================================================
echo  Tunel gratis pro JOGO online (playit.gg)
echo  So o ANFITRIAO precisa disso. Deixe esta janela aberta
echo  enquanto todo mundo joga.
echo ============================================================
echo.
if not exist "playit.exe" (
  echo Baixando o programa do playit (so na primeira vez)...
  curl -L -o playit.exe "https://github.com/playit-cloud/playit-agent/releases/latest/download/playit-windows-x86_64-signed.exe"
)
if not exist "playit.exe" (
  echo Nao consegui baixar. Vou abrir o site: baixe o playit pra Windows,
  echo coloque o arquivo nesta pasta com o nome playit.exe e abra este .bat de novo.
  start https://playit.gg/download
  pause
  exit /b
)
echo.
echo Na primeira vez o playit mostra um link: abra, crie a conta gratis e ligue
echo este PC. Depois, no site: Add Tunnel, tipo UDP, porta local 7777.
echo O endereco que aparecer (tipo abc-123.gl.at.ply.gg:45678) voce passa pros amigos.
echo.
playit.exe
pause
