# Bambu Lab Filament Profile Extractor
## DISCLAIMER:
### ALL PROFILES IN THIS REPO WERE DEVELOPED BY [3Dmanufactory.italy](https://makerworld.com/en/@Carlo.st) I AM NOT THE CREATOR OF THE PROFILES, ALL CREDIT GOES TO HIM. I AM ONLY THE CREATOR OF THE BASH AND POWERSHELL SCRIPTS


# WHAT THIS IS
A pair of scripts (Bash and PowerShell) that extract third-party filament profiles from the
Bambu Lab community profile pack and consolidate them into a single folder for a specific
printer, ready to import into Bambu Studio or Orca Slicer.

---

## Why Does This Exist?

The community filament profile packs contain profiles for every Bambu Lab printer across
dozens of filament brands. If you only own one printer, importing the entire pack is
impractical. These scripts let you pull just the profiles that are relevant to your machine
in one shot.

---

## Supported Printers

| Argument | Matches |
|----------|---------|
| `A1` | Bambu Lab A1 |
| `A1M` | Bambu Lab A1 Mini |
| `P1P` | Bambu Lab P1P |
| `P1S` | Bambu Lab P1S |
| `X1` | Bambu Lab X1 (base) |
| `X1C` | Bambu Lab X1 Carbon |
| `X1E` | Bambu Lab X1E |
| `X1-ALL` | All X1 variants |
| `P2S` | Bambu Lab P2S |
| `H2C` | Bambu Lab H2C |
| `H2D` | Bambu Lab H2D |
| `H2S` | Bambu Lab H2S |

---

## Requirements

**Bash script**
- Linux, macOS, or Windows with WSL2 or Git Bash
- Bash 4.0 or newer

**PowerShell script**
- Windows, macOS, or Linux
- PowerShell 5.1 or newer (PowerShell 7+ recommended)
- On first run you may need to allow local scripts:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

---

## Usage

### Bash

```bash
./extract.sh <PRINTER_TYPE> <OUTPUT_DIR> [SOURCE_DIR]
```

`SOURCE_DIR` is optional and defaults to the current directory.

Examples:

```bash
# Run from inside the profile pack directory
./extract.sh H2D ./h2d_profiles

# Run from anywhere with an explicit source path
./extract.sh X1C ./x1c_profiles /path/to/profile/pack
```

Make the script executable first if needed:

```bash
chmod +x extract.sh
```

---

### PowerShell

```powershell
.\extract.ps1 -PrinterType <PRINTER_TYPE> -OutputDir <OUTPUT_DIR> [-SourceDir <SOURCE_DIR>]
```

`SourceDir` is optional and defaults to the current directory.

Examples:

```powershell
# Run from inside the profile pack directory
.\extract.ps1 -PrinterType H2D -OutputDir .\h2d_profiles

# Run from anywhere with an explicit source path
.\extract.ps1 -PrinterType X1C -OutputDir .\x1c_profiles -SourceDir "C:\Users\you\Downloads\profile_pack"
```

---

## What the Scripts Do

The scripts run three passes over the profile pack:

**Pass 1** handles brands like SUNLU that use a structured directory layout
(`Brand/Material/Printer/NozzleSize/preset_filament.json`). All nozzle sizes are extracted
and the output file is named using the brand, material, printer, and nozzle size pulled
from the directory structure.

**Pass 2** handles brands like KINGROON and FusRock that ship flat JSON files with the
printer name embedded in the filename. The printer and nozzle info is parsed out of the
filename and used to build a clean output name.

**Pass 3** catches generic or base profiles that have no printer tag in the filename at
all, like `Overture PLA.json` or `Overture PLA @base.json`. These are printer-agnostic
profiles that are still useful as a starting point. They are copied with a `_generic`
suffix so you know they were not tuned for a specific machine.

Output files are named in the format:

```
Brand_Material_PrinterType_NozzleSize.json
```

For example:

```
SUNLU_PLAPlus_H2D_0.4.json
kingroon_filamenti_KINGROON_PLA_Basic_H2D_0.4.json
overture_filamenti_Overture_PLA_H2D_generic.json
```

---

## Importing into Bambu Studio or Orca Slicer

1. Run the script for your printer.
2. Open Bambu Studio or Orca Slicer.
3. Go to **Filament** settings.
4. Use the import option to load `.json` filament profiles.
5. Point it at your output folder and import the profiles you want.

---

## Notes

- Running the script a second time into the same output folder will overwrite existing
  files silently. Use a fresh output folder or clean it out between runs if needed.
- Profiles tagged `_generic` are not printer-specific. Use them as a baseline and dial
  in your own settings from there.
- The scripts do not modify the original profile pack in any way.
