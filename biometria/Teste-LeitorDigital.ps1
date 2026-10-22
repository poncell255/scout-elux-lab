# Teste do leitor de digital (HID DigitalPersona U.are.U 4500) dentro da sessão Citrix.
# Usa o Windows Biometric Framework (winbio.dll): lista os sensores e captura a digital, mostrando a imagem.
# Pré-requisitos no Windows da sessão: driver WBF do U.are.U 4500 (HID) instalado; leitor redirecionado pelo Citrix.
# A captura de imagem bruta (WINBIO_FLAG_RAW) exige executar como Administrador.
# Uso: powershell -ExecutionPolicy Bypass -File .\Teste-LeitorDigital.ps1
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class WinBio
{
    const uint TYPE_FINGERPRINT = 0x00000008;
    const uint POOL_SYSTEM = 1;
    const uint FLAG_RAW = 0x00000001;
    const byte PURPOSE_IDENTIFY = 0x02;
    const byte DATA_FLAG_RAW = 0x20;

    [DllImport("winbio.dll")] static extern int WinBioEnumBiometricUnits(uint factor, out IntPtr schemaArray, out IntPtr count);
    [DllImport("winbio.dll")] static extern int WinBioOpenSession(uint factor, uint poolType, uint flags, IntPtr unitArray, IntPtr unitCount, IntPtr databaseId, out uint session);
    [DllImport("winbio.dll")] static extern int WinBioCaptureSample(uint session, byte purpose, byte flags, out uint unitId, out IntPtr sample, out IntPtr sampleSize, out uint rejectDetail);
    [DllImport("winbio.dll")] static extern int WinBioCloseSession(uint session);
    [DllImport("winbio.dll")] static extern int WinBioFree(IntPtr address);

    // WINBIO_UNIT_SCHEMA: UnitId, PoolType, BiometricFactor, SensorSubType, Capabilities (ULONGs), depois strings.
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct UnitSchema
    {
        public uint UnitId, PoolType, BiometricFactor, SensorSubType, Capabilities;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string DeviceInstanceId;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string Description;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string Manufacturer;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string Model;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string SerialNumber;
        public uint FirmwareMajor, FirmwareMinor;
    }

    public static string Erro(int hr)
    {
        switch ((uint)hr)
        {
            case 0x80070005: return "acesso negado (execute como Administrador para capturar a imagem)";
            case 0x80098003: return "nenhum sensor de digital disponível nesta sessão";
            case 0x80098004: return "a captura foi cancelada";
            case 0x80098008: return "leitura ruim, tente de novo";
            case 0x80098011: return "sensor ocupado";
            case 0x80098005: return "dedo não reconhecido";
            default: return "erro 0x" + ((uint)hr).ToString("X8");
        }
    }

    public static string[] ListarSensores(out int hr)
    {
        IntPtr arr, count;
        hr = WinBioEnumBiometricUnits(TYPE_FINGERPRINT, out arr, out count);
        if (hr != 0) return new string[0];
        int n = count.ToInt32();
        var res = new string[n];
        int size = Marshal.SizeOf(typeof(UnitSchema));
        for (int i = 0; i < n; i++)
        {
            var u = (UnitSchema)Marshal.PtrToStructure(new IntPtr(arr.ToInt64() + i * size), typeof(UnitSchema));
            res[i] = string.Format("Unidade {0}: {1} {2} ({3})", u.UnitId, u.Manufacturer, u.Model, u.Description);
        }
        WinBioFree(arr);
        return res;
    }

    // Captura uma digital e devolve a imagem em tons de cinza (registro ANSI INCITS 381 dentro do WINBIO_BIR).
    public static int Capturar(out byte[] pixels, out int largura, out int altura, out int qualidade, out uint rejeicao)
    {
        pixels = null; largura = altura = qualidade = 0; rejeicao = 0;
        uint session;
        int hr = WinBioOpenSession(TYPE_FINGERPRINT, POOL_SYSTEM, FLAG_RAW, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, out session);
        if (hr != 0) return hr;
        try
        {
            uint unit; IntPtr sample, sampleSize;
            hr = WinBioCaptureSample(session, PURPOSE_IDENTIFY, DATA_FLAG_RAW, out unit, out sample, out sampleSize, out rejeicao);
            if (hr != 0) return hr;
            try
            {
                var bir = new byte[sampleSize.ToInt32()];
                Marshal.Copy(sample, bir, 0, bir.Length);
                // WINBIO_BIR: HeaderBlock, StandardDataBlock, VendorDataBlock, SignatureBlock = {ULONG Size; ULONG Offset}
                int stdSize = BitConverter.ToInt32(bir, 8), stdOffset = BitConverter.ToInt32(bir, 12);
                if (stdSize < 50) return unchecked((int)0x80004005);
                int p = stdOffset;                      // registro ANSI 381 (big-endian)
                int compressao = bir[p + 35];
                p += 36;                                // cabeçalho geral
                qualidade = bir[p + 7];
                largura = (bir[p + 9] << 8) | bir[p + 10];
                altura = (bir[p + 11] << 8) | bir[p + 12];
                p += 14;                                // cabeçalho da digital
                if (compressao != 0) return unchecked((int)0x80004001); // imagem comprimida: não suportado aqui
                pixels = new byte[largura * altura];
                Array.Copy(bir, p, pixels, 0, Math.Min(pixels.Length, bir.Length - p));
                return 0;
            }
            finally { WinBioFree(sample); }
        }
        finally { WinBioCloseSession(session); }
    }
}
'@

function Imagem([byte[]]$px, [int]$w, [int]$h) {
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) { $v = $px[$y * $w + $x]; $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($v, $v, $v)) } }
    $bmp
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Teste do leitor de digital - POPULOS'; $form.Size = New-Object System.Drawing.Size 760, 560; $form.StartPosition = 'CenterScreen'
$log = New-Object System.Windows.Forms.TextBox; $log.Multiline = $true; $log.ScrollBars = 'Vertical'; $log.ReadOnly = $true
$log.Location = New-Object System.Drawing.Point 10, 60; $log.Size = New-Object System.Drawing.Size 420, 440; $log.Font = New-Object System.Drawing.Font 'Consolas', 9
$foto = New-Object System.Windows.Forms.PictureBox; $foto.Location = New-Object System.Drawing.Point 440, 60; $foto.Size = New-Object System.Drawing.Size 290, 440
$foto.SizeMode = 'Zoom'; $foto.BorderStyle = 'FixedSingle'
function Escrever($t) { $log.AppendText("$(Get-Date -Format HH:mm:ss)  $t`r`n") }

$b1 = New-Object System.Windows.Forms.Button; $b1.Text = '1. Verificar leitor'; $b1.Location = New-Object System.Drawing.Point 10, 15; $b1.Size = New-Object System.Drawing.Size 200, 32
$b1.Add_Click({
    $dev = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match 'VID_05BA&PID_000A' }
    if ($dev) { $dev | ForEach-Object { Escrever "USB OK: $($_.FriendlyName) [$($_.Status)] $($_.InstanceId)" } }
    else { Escrever 'Leitor USB 05BA:000A NÃO chegou nesta sessão (ver regra USB do Citrix e política "Client USB device redirection").' }
    $hr = 0; $s = [WinBio]::ListarSensores([ref]$hr)
    if ($hr -ne 0) { Escrever "Windows Biometric: $([WinBio]::Erro($hr))" }
    elseif ($s.Count -eq 0) { Escrever 'Windows Biometric: nenhum sensor de digital (falta o driver WBF da HID?).' }
    else { $s | ForEach-Object { Escrever "Sensor: $_" } }
})
$b2 = New-Object System.Windows.Forms.Button; $b2.Text = '2. Capturar digital'; $b2.Location = New-Object System.Drawing.Point 220, 15; $b2.Size = New-Object System.Drawing.Size 200, 32
$b2.Add_Click({
    Escrever 'Coloque o dedo no leitor...'; $form.Refresh()
    $px = $null; $w = 0; $h = 0; $q = 0; $rej = [uint32]0
    $hr = [WinBio]::Capturar([ref]$px, [ref]$w, [ref]$h, [ref]$q, [ref]$rej)
    if ($hr -ne 0) { Escrever "Captura: $([WinBio]::Erro($hr)) (detalhe $rej)"; return }
    $foto.Image = Imagem $px $w $h
    $arq = Join-Path ([Environment]::GetFolderPath('MyDocuments')) ("digital-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".png")
    $foto.Image.Save($arq, [System.Drawing.Imaging.ImageFormat]::Png)
    Escrever "Digital capturada: ${w}x${h}, qualidade $q. Imagem salva em $arq"
})
$form.Controls.AddRange(@($b1, $b2, $log, $foto))
Escrever 'Passo 1 confere se o leitor chegou à sessão; passo 2 lê a digital e mostra a imagem.'
[void]$form.ShowDialog()
