# --- SEADISTUS JA FAILIDE LUGEMINE ---

# Pildil olevad failinimed (suured algustähed on olulised, kui Linuxit kasutaksid, aga Windowsis töötab nii või naa)
$eesnimedFail = "Eesnimed.txt"
$perenimedFail = "Perenimed.txt"
$kirjeldusedFail = "Kirjeldused.txt"
$valjundFail = "new_users_accounts.csv"

# Kontrollime, kas failid on olemas
if (-not (Test-Path $eesnimedFail) -or -not (Test-Path $perenimedFail) -or -not (Test-Path $kirjeldusedFail)) {
    Write-Warning "Viga: Mõni vajalik tekstifail on kaustast puudu!"
    break
}

# Loeme sisu (Encoding UTF8 on kriitiline "Õie" ja "Nadežda" jaoks)
$eesnimed = Get-Content $eesnimedFail -Encoding UTF8
$perenimed = Get-Content $perenimedFail -Encoding UTF8
$kirjeldused = Get-Content $kirjeldusedFail -Encoding UTF8


# --- ABIFUNKTSIOONID ---

function Clean-StringForUsername {
    param ([string]$sisend)
    
    # Teeme väikseks
    $txt = $sisend.ToLower()

    # Asendame täpitähed ja š/ž
    $txt = $txt -replace 'õ', 'o'
    $txt = $txt -replace 'ä', 'a'
    $txt = $txt -replace 'ö', 'o'
    $txt = $txt -replace 'ü', 'u'
    $txt = $txt -replace 'š', 's'
    $txt = $txt -replace 'ž', 'z'

    # Eemaldame tühikud ja sidekriipsud (Karl Kristjan -> karlkristjan)
    $txt = $txt -replace ' ', ''
    $txt = $txt -replace '-', ''
    
    return $txt
}

function Generate-Password {
    # Pikkus 5 kuni 8 (Maximum 9 tähendab, et võtab kuni 8)
    $len = Get-Random -Minimum 5 -Maximum 9
    $chars = "abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789" # Segaduse vältimiseks ilma O, 0, I, l
    $pass = ""
    for ($i=0; $i -lt $len; $i++) {
        $pass += $chars[(Get-Random -Maximum $chars.Length)]
    }
    return $pass
}


# --- PÕHITÖÖ (LOOME 5 KASUTAJAT) ---

$kasutajateList = @()

for ($i = 1; $i -le 5; $i++) {
    # 1. Võtame suvalised andmed
    $randEesnimi = $eesnimed | Get-Random
    $randPerenimi = $perenimed | Get-Random
    $randKirjeldus = $kirjeldused | Get-Random

    # 2. Töötleme kasutajanime
    # "Hanna-Maria" -> "hannamaria" ja "Männik" -> "mannik" => "hannamaria.mannik"
    $cleanEesnimi = Clean-StringForUsername -sisend $randEesnimi
    $cleanPerenimi = Clean-StringForUsername -sisend $randPerenimi
    $kasutajanimi = "$cleanEesnimi.$cleanPerenimi"

    # 3. Genereerime parooli
    $parool = Generate-Password

    # 4. Loome objekti
    $kasutaja = [PSCustomObject]@{
        Eesnimi      = $randEesnimi
        Perenimi     = $randPerenimi
        Kasutajanimi = $kasutajanimi
        Parool       = $parool
        Kirjeldus    = $randKirjeldus
    }

    $kasutajateList += $kasutaja
}


# --- SALVESTAMINE JA VÄLJUND ---

# Kirjutame CSV faili (Delimiter semikoolon, Encoding UTF8)
$kasutajateList | Export-Csv -Path $valjundFail -Delimiter ";" -NoTypeInformation -Encoding UTF8 -Force

# Kuvame konsooli info
Write-Host "----------------------------------------------------"
Write-Host "Fail '$valjundFail' on loodud järgmiste andmetega:"
Write-Host "----------------------------------------------------"

foreach ($k in $kasutajateList) {
    # Võtame kirjeldusest esimesed 10 märki (kontrollime, et string oleks piisavalt pikk)
    $luhikeKirjeldus = if ($k.Kirjeldus.Length -gt 10) { $k.Kirjeldus.Substring(0, 10) } else { $k.Kirjeldus }
    
    Write-Host "Nimi:   $($k.Eesnimi) $($k.Perenimi)"
    Write-Host "User:   $($k.Kasutajanimi)"
    Write-Host "Pass:   $($k.Parool)"
    Write-Host "Desc:   $luhikeKirjeldus..."
    Write-Host "- - -"
}