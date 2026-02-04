# --- KONTROLLIME ADMIN ÕIGUSI ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Warning "See skript vajab administraatori õigusi! Palun käivita PowerShell 'Run as Administrator'."
    Break
}

# --- SEADISTUS ---
# Veendu, et see fail on samas kaustas kus skript!
$csvFail = "new_users_accounts.csv"
$csvOlemas = Test-Path $csvFail

# --- VALIKUTE MENÜÜ ---
Clear-Host
Write-Host "=========================================="
Write-Host " KASUTAJATE HALDUS (ADMIN)"
Write-Host "=========================================="
Write-Host "1. LISA kasutajad failist '$csvFail'"
Write-Host "2. KUSTUTA üks kasutaja (Valik nimekirjast)"
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

                # SIIN ON NÜÜD PUHAS KÄSK ILMA SELLE PARAMEETRITA:
                New-LocalUser -Name $nimi `
                              -FullName $taisnimi `
                              -Description $kirjeldus `
                              -Password $securePass `
                              -ErrorAction Stop | Out-Null
                
                # See rida teeb parooli muutmise nõude eraldi käsuga:
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
        # --- KASUTAJA KUSTUTAMINE (MUGAVAM VERSIOON) ---
        Write-Host "`nLaen kasutajate nimekirja..."
        
        $systemUsers = "Administrator", "Guest", "DefaultAccount", "WDAGUtilityAccount"
        $users = Get-LocalUser | Where-Object { $_.Name -notin $systemUsers }
        
        if ($users.Count -eq 0) {
            Write-Host "Kustutatavaid kasutajaid ei leitud." -ForegroundColor Yellow
            Break
        }

        # AVAME HÜPIKAKNA
        Write-Host "Avaneb aken. Vali kasutaja ja vajuta all nurgas 'OK'." -ForegroundColor Cyan
        $valitudKasutaja = $users | Select-Object Name, FullName, Description | Out-GridView -Title "Vali kasutaja, keda soovid KUSTUTADA ja vajuta OK" -OutputMode Single

        if ($valitudKasutaja) {
            $kustutatavNimi = $valitudKasutaja.Name
            
            Write-Host "`nValitud kustutamiseks: $kustutatavNimi"
            
            $kinnitus = Read-Host "Oled kindel? (Y/N)"
            if ($kinnitus -ne 'Y' -and $kinnitus -ne 'y') {
                Write-Warning "Kustutamine katkestatud."
                Break
            }

            try {
                Remove-LocalUser -Name $kustutatavNimi -ErrorAction Stop
                Write-Host "Kasutaja '$kustutatavNimi' on süsteemist eemaldatud." -ForegroundColor Green

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
            Write-Warning "Kasutajat ei valitud. Kustutamine katkestatud."
        }
    }

    Default {
        Write-Warning "Vale valik."
    }
}