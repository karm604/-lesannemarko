# --- KONTROLLIME ADMIN ÕIGUSI ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Warning "See skript vajab administraatori õigusi! Palun käivita PowerShell 'Run as Administrator'."
    Break
}

# --- SEADISTUS ---
$csvFail = "new_users_accounts.csv"

# Kontrollime, kas CSV on olemas (ainult lisamise jaoks vajalik)
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
            
            # 1. Kasutajanimi liiga pikk? (Windowsi vanem piirang on 20 tähemärki, hoiame joont)
            if ($nimi.Length -gt 20) {
                Write-Host "$nimi - EI LISATUD: Kasutajanimi on liiga pikk (>20 märki)." -ForegroundColor Red
                Continue
            }

            # 2. Kas kasutaja on juba olemas?
            if (Get-LocalUser -Name $nimi -ErrorAction SilentlyContinue) {
                Write-Host "$nimi - EI LISATUD: Kasutaja on juba olemas (Duplikaat)." -ForegroundColor Red
                Continue
            }

            # 3. Kirjelduse pikkus ja lühendamine
            # Kui kirjeldus on ülipikk, lühendame seda (nt max 48 märki, et vältida vigu vanemates süsteemides)
            $lisaInfo = ""
            if ($kirjeldus.Length -gt 48) {
                $kirjeldus = $kirjeldus.Substring(0, 48)
                $lisaInfo = "(Kirjeldus lühendati)"
            }

            # -- LOOMINE --
            try {
                # Teeme parooli turvaliseks stringiks
                $securePass = ConvertTo-SecureString $paroolPlain -AsPlainText -Force

                # Loome kasutaja
                New-LocalUser -Name $nimi `
                              -FullName $taisnimi `
                              -Description $kirjeldus `
                              -Password $securePass `
                              -ErrorAction Stop | Out-Null
                
                # Sundime parooli muutmist järgmisel sisselogimisel
                net user $nimi /logonpasswordchg:yes 2>$null
                
                # Kasutaja lisatakse automaatselt gruppi "Users", aga veendume
                # Add-LocalGroupMember -Group "Users" -Member $nimi -ErrorAction SilentlyContinue

                Write-Host "OK: $nimi lisatud. $lisaInfo" -ForegroundColor Green
            }
            catch {
                Write-Host "$nimi - VIGA: $($_.Exception.Message)" -ForegroundColor Red
            }
        }

        # -- LÕPPTULEMUS --
        Write-Host "`n--- Hetkel süsteemis olevad loodud kasutajad ---"
        # Filtreerime välja sisseehitatud kontod
        $systemUsers = "Administrator", "Guest", "DefaultAccount", "WDAGUtilityAccount"
        Get-LocalUser | Where-Object { $_.Name -notin $systemUsers } | Format-Table Name, FullName, Description -AutoSize
    }

    "2" {
        # --- KASUTAJA KUSTUTAMINE ---
        Write-Host "`nVali kasutaja, keda kustutada:"
        
        # Näitame nimekirja (ilma süsteemikontodeta)
        $systemUsers = "Administrator", "Guest", "DefaultAccount", "WDAGUtilityAccount"
        $users = Get-LocalUser | Where-Object { $_.Name -notin $systemUsers }
        
        if ($users.Count -eq 0) {
            Write-Host "Kustutatavaid kasutajaid ei leitud." -ForegroundColor Yellow
            Break
        }

        $users | Select-Object Name, Description | Format-Table -AutoSize

        $kustutatavNimi = Read-Host "Sisesta täpne kasutajanimi"

        # Kontrollime kas selline kasutaja on nimekirjas
        if ($users.Name -contains $kustutatavNimi) {
            try {
                # 1. Kustutame kasutaja
                Remove-LocalUser -Name $kustutatavNimi -ErrorAction Stop
                Write-Host "Kasutaja '$kustutatavNimi' on süsteemist eemaldatud." -ForegroundColor Green

                # 2. Kustutame kodukausta (C:\Users\Nimi)
                # See tekib alles siis, kui kasutaja on korra sisse loginud
                $homePath = "C:\Users\$kustutatavNimi"
                if (Test-Path $homePath) {
                    Write-Host "Leiti kodukaust '$homePath', kustutan..." -NoNewline
                    Remove-Item -Path $homePath -Recurse -Force -ErrorAction Stop
                    Write-Host " TEHTUD." -ForegroundColor Green
                } else {
                    Write-Host "Kodukausta ei leitud (kasutaja polnud sisse loginud)." -ForegroundColor Gray
                }
            }
            catch {
                Write-Error "Viga kustutamisel: $($_.Exception.Message)"
            }
        } else {
            Write-Warning "Sellist kasutajanime ei leitud või on see süsteemne konto."
        }
    }

    Default {
        Write-Warning "Vale valik. Käivita skript uuesti."
    }
}