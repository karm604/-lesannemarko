# --- KONTROLLIME ADMIN ÕIGUSI ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Warning "See skript vajab administraatori õigusi! Palun käivita PowerShell 'Run as Administrator'."
    Break
}

# --- SEADISTUS ---
$csvFail = "new_users_accounts.csv"
$csvOlemas = Test-Path $csvFail

# --- VALIKUTE MENÜÜ ---
Clear-Host
Write-Host "=========================================="
Write-Host " KASUTAJATE HALDUS (ADMIN)"
Write-Host "=========================================="
Write-Host "1. LISA kasutajad failist '$csvFail'"
Write-Host "2. KUSTUTA üks kasutaja"
Write-Host "------------------------------------------"
$valik = Read-Host "Sisesta valik (1 või 2)"

Switch ($valik) {
    "1" {
        # --- KASUTAJATE LISAMINE ---
        if (-not $csvOlemas) {
            Write-Error "Faili $csvFail ei leitud! Käivita enne esimene skript."
            Break
        }

        $kasutajad = Import-Csv -Path $csvFail -Delimiter ";" -Encoding UTF8
        Write-Host "`nAlustan kasutajate lisamist...`n"

        foreach ($rida in $kasutajad) {
            $nimi = $rida.Kasutajanimi
            $taisnimi = "$($rida.Eesnimi) $($rida.Perenimi)"
            $kirjeldus = $rida.Kirjeldus
            $paroolPlain = $rida.Parool

            # -- KONTROLLID --
            if ($nimi.Length -gt 20) {
                Write-Host "$nimi - EI LISATUD: Kasutajanimi on liiga pikk (>20 märki)." -ForegroundColor Red
                Continue
            }

            if (Get-LocalUser -Name $nimi -ErrorAction SilentlyContinue) {
                Write-Host "$nimi - EI LISATUD: Kasutaja on juba olemas." -ForegroundColor Red
                Continue
            }

            $lisaInfo = ""
            if ($kirjeldus.Length -gt 48) {
                $kirjeldus = $kirjeldus.Substring(0, 48)
                $lisaInfo = "(Kirjeldus lühendati)"
            }

            # -- LOOMINE --
            try {
                $securePass = ConvertTo-SecureString $paroolPlain -AsPlainText -Force

                # SIIT ON VIGANE RIDA EEMALDATUD:
                New-LocalUser -Name $nimi `
                              -FullName $taisnimi `
                              -Description $kirjeldus `
                              -Password $securePass `
                              -ErrorAction Stop | Out-Null
                
                # See rida sunnib parooli vahetama (töötab igas versioonis):
                net user $nimi /logonpasswordchg:yes 2>$null

                Write-Host "OK: $nimi lisatud. $lisaInfo" -ForegroundColor Green
            }
            catch {
                Write-Host "$nimi - VIGA: $($_.Exception.Message)" -ForegroundColor Red
            }
        }

        Write-Host "`n--- Süsteemis olevad loodud kasutajad ---"
        $systemUsers = "Administrator", "Guest", "DefaultAccount", "WDAGUtilityAccount"
        Get-LocalUser | Where-Object { $_.Name -notin $systemUsers } | Format-Table Name, FullName, Description -AutoSize
    }

    "2" {
        # --- KASUTAJA KUSTUTAMINE (NUMBRITEGA) ---
        Write-Host "`n--- Vali number, keda kustutada ---"
        
        $systemUsers = "Administrator", "Guest", "DefaultAccount", "WDAGUtilityAccount"
        # Teeme nimekirja massiiviks, et saaks numbriga valida
        $users = @(Get-LocalUser | Where-Object { $_.Name -notin $systemUsers })
        
        if ($users.Count -eq 0) {
            Write-Host "Kustutatavaid kasutajaid ei leitud." -ForegroundColor Yellow
            Break
        }

        # Kuvame nimekirja numbritega: 1. Nimi, 2. Nimi jne
        for ($i = 0; $i -lt $users.Count; $i++) {
            Write-Host "$($i+1). $($users[$i].Name) ($($users[$i].FullName))"
        }

        Write-Host "-----------------------------------"
        $sisestus = Read-Host "Sisesta number (või vajuta Enter katkestamiseks)"

        if ([string]::IsNullOrWhiteSpace($sisestus)) {
            Write-Warning "Katkestatud."
            Break
        }

        # Kontrollime, kas sisestati number ja kas see on õiges vahemikus
        if ($sisestus -match "^\d+$" -and [int]$sisestus -ge 1 -and [int]$sisestus -le $users.Count) {
            $valitudKasutaja = $users[[int]$sisestus - 1]
            $kustutatavNimi = $valitudKasutaja.Name

            Write-Host "Valitud: $kustutatavNimi"
            
            try {
                # 1. Kustutame kasutaja
                Remove-LocalUser -Name $kustutatavNimi -ErrorAction Stop
                Write-Host "Kasutaja '$kustutatavNimi' on süsteemist eemaldatud." -ForegroundColor Green

                # 2. Kustutame kodukausta
                $homePath = "C:\Users\$kustutatavNimi"
                if (Test-Path $homePath) {
                    Write-Host "Leiti kodukaust '$homePath', kustutan..." -NoNewline
                    Remove-Item -Path $homePath -Recurse -Force -ErrorAction Stop
                    Write-Host " TEHTUD." -ForegroundColor Green
                } else {
                    Write-Host "Kodukausta ei leitud (kasutaja polnud veel sisse loginud)." -ForegroundColor Gray
                }
            }
            catch {
                Write-Error "Viga kustutamisel: $($_.Exception.Message)"
            }
        } else {
            Write-Warning "Vigane number. Proovi uuesti."
        }
    }

    Default {
        Write-Warning "Vale valik."
    }
}