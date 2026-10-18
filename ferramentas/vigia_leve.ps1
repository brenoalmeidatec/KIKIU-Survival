param([switch]$Parar)
# Vigia: enquanto roda, todo Godot/Blender fica com prioridade Idle, preso nos núcleos 10-11, com o som mudo e com a janela fora da tela
# (sem ativar); se uma janela dele roubar o foco, o foco volta para a janela que estava na frente (o jogo do Alisson).
# Uso (PC do Alisson, quando ele for jogar e houver agentes rodando Godot/Blender):
#   Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ferramentasigia_leve.ps1' -WindowStyle Hidden
# Para: apague o arquivo %TEMP%\kikiu_vigia_leve.ligado (ou rode com -Parar).
# Conferido em 18/10/2026: partida da v2 aberta sem restrição ficou Idle, núcleos 10-11 (0xC00), muda e fora da tela; foto do teste sai normal.
$ErrorActionPreference = "SilentlyContinue"
$liga = Join-Path $env:TEMP "kikiu_vigia_leve.ligado"
if ($Parar) { Remove-Item $liga -ErrorAction SilentlyContinue; exit 0 }
Set-Content $liga "1"
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
[Guid("BCDE0395-E52F-467C-8E3D-C4579291692E"), ComImport] class MMDeviceEnumerator {}
[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator { int NotImpl1(); int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice ppDevice); }
[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice { int Activate(ref Guid iid, int dwClsCtx, IntPtr pActivationParams, [MarshalAs(UnmanagedType.IUnknown)] out object ppInterface); }
[Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionManager2 { int NotImpl1(); int NotImpl2(); int GetSessionEnumerator(out IAudioSessionEnumerator SessionEnum); }
[Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionEnumerator { int GetCount(out int SessionCount); int GetSession(int SessionCount, out IAudioSessionControl2 Session); }
[Guid("bfb7ff88-7239-4fc9-8fa2-07c950be9c6d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionControl2 { int N1(); int N2(); int N3(); int N4(); int N5(); int N6(); int N7(); int N8(); int N9(); int N10(); int N11(); int GetProcessId(out uint pRetVal); }
[Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface ISimpleAudioVolume { int SetMasterVolume(float fLevel, ref Guid EventContext); int GetMasterVolume(out float pfLevel); int SetMute(bool bMute, ref Guid EventContext); int GetMute(out bool pbMute); }
public static class Janela {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  // tira da tela (sem ativar) toda janela visível dos pids; devolve quantas moveu
  public static int Esconder(int[] pids) {
    int n = 0;
    EnumWindows((h, l) => { uint pid; GetWindowThreadProcessId(h, out pid);
      if (Array.IndexOf(pids, (int)pid) >= 0 && IsWindowVisible(h)) { RECT r; GetWindowRect(h, out r);
        if (r.L > -20000) { SetWindowPos(h, IntPtr.Zero, -32000, -32000, 0, 0, 0x0001 | 0x0004 | 0x0010); n++; } }
      return true; }, IntPtr.Zero);
    return n;
  }
  public static int PidDaFrente() { uint pid; GetWindowThreadProcessId(GetForegroundWindow(), out pid); return (int)pid; }
}
public static class Mudo {
  public static int Silenciar(int[] pids) {
    var en = (IMMDeviceEnumerator)(new MMDeviceEnumerator()); IMMDevice dev; en.GetDefaultAudioEndpoint(0, 1, out dev);
    Guid iid = typeof(IAudioSessionManager2).GUID; object o; dev.Activate(ref iid, 23, IntPtr.Zero, out o);
    var mgr = (IAudioSessionManager2)o; IAudioSessionEnumerator se; mgr.GetSessionEnumerator(out se); int n; se.GetCount(out n); int feitos = 0;
    for (int i = 0; i < n; i++) { IAudioSessionControl2 c; se.GetSession(i, out c); uint pid; c.GetProcessId(out pid);
      if (Array.IndexOf(pids, (int)pid) >= 0) { var v = (ISimpleAudioVolume)c; Guid g = Guid.Empty; v.SetMute(true, ref g); feitos++; } }
    return feitos;
  }
}
"@
$frente = [IntPtr]::Zero  # a última janela da frente que não era Godot/Blender (o jogo do Alisson)
$volta = 0
$frente_t = Get-Date
while (Test-Path $liga) {
	$ps = Get-Process | Where-Object { $_.Name -like "Godot*" -or $_.Name -like "blender*" }
	$pids = [int[]]@($ps | ForEach-Object { $_.Id })
	$fp = [Janela]::PidDaFrente()
	if ($pids -contains $fp) {
		# devolve o foco só para a janela que estava na frente até agora há pouco (no máximo 1,5 s), nunca para uma antiga
		if ($frente -ne [IntPtr]::Zero -and ((Get-Date) - $frente_t).TotalSeconds -lt 1.5) { [void][Janela]::SetForegroundWindow($frente) }
	} else {
		$frente = [Janela]::GetForegroundWindow()
		$frente_t = Get-Date
	}
	if ($pids.Count -gt 0) { [void][Janela]::Esconder($pids) }
	foreach ($p in $ps) {
		if ($p.PriorityClass -ne "Idle") { $p.PriorityClass = "Idle" }
		if ([int64]$p.ProcessorAffinity -ne 0xC00) { $p.ProcessorAffinity = [IntPtr]0xC00 }
	}
	$volta++
	if ($ps -and ($volta % 6 -eq 0)) { [void][Mudo]::Silenciar($pids) }
	Start-Sleep -Milliseconds 300
}
