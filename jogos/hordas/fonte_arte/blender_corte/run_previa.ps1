param([string]$Gif = "$PSScriptRoot\previa_corte.gif", [string]$Tira = "$PSScriptRoot\previa_tira.png")
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b -P "$PSScriptRoot\previa.py" -- "$PSScriptRoot\corte_hazaki_folha.png" $Gif $Tira
