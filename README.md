# prusaslicer-spoolman-postprocess
Windows batch post-processing for PrusaSlicer that copies the generated G-code to a local archive and updates Spoolman automatically by reading SPOOLMAN_ID and “filament used [g]” from the file. Simple, dependency-free, and LAN-friendly. Includes setup instructions, troubleshooting tips, exit codes, and MIT license. Works on Windows 10/11.No Python

понял. добавил чёткое пояснение: **SPOOLMAN_ID — это номер катушки (Spool) из Spoolman**, заранее созданной в UI. Ниже обновлённый README одним файлом (EN).

# PrusaSlicer → Spoolman Post-Processing (Windows)

A tiny **Windows batch** post-processing script for **PrusaSlicer** that:

- copies the generated G-code to a destination folder,  
- reads `SPOOLMAN_ID` from **Filament → Notes** (embedded into the G-code header as `filament_notes`),  
- reads `; filament used [g] = …`,  
- and calls **Spoolman** `PUT /api/v1/spool/{id}/use` with `use_weight`.

> Minimal, dependency-free, LAN-friendly. Works on Windows 10/11.

---

## Features

- ✳️ Keeps a clean local archive of your sliced G-codes  
- 🧵 Automatically decrements spool usage in Spoolman after slicing/upload  
- 🧪 Clear exit codes and verbose console output  
- 🔒 No personal paths or IPs hard-coded (anonymized defaults)

---

## Requirements

- Windows 10/11 (PowerShell available by default)  
- PrusaSlicer 2.6+ (earlier may also work)  
- Reachable Spoolman instance (e.g. `http://127.0.0.1:7912`)

---

## Installation

1. **Download/clone** this repo.  
2. Place the script somewhere stable, e.g.:  
   `C:\Tools\prusaslicer-spoolman\postprocess_spoolman.bat`  
3. Create a destination folder for copied G-codes, e.g.:  
   `%USERPROFILE%\Documents\Spoolman\gcodes`

---

## Configuration

Open `postprocess_spoolman.bat` and adjust the first lines:

```bat
set "DST=%USERPROFILE%\Documents\Spoolman\gcodes"
set "BASE_URL=http://127.0.0.1:7912"
````

* **DST** — where the clean copy of your G-code will be written.
* **BASE_URL** — your Spoolman base URL (HTTP is fine on a trusted LAN).

---

## PrusaSlicer Setup (Pre-Settings)

1. **Enable the post-processing script**
   Go to **Print Settings → Output options → Post-processing scripts** and add the full path, e.g.:

   ```bat
   C:\Tools\prusaslicer-spoolman\postprocess_spoolman.bat
   ```
   <img width="1160" height="660" alt="grafik" src="https://github.com/user-attachments/assets/fa959f84-7cdf-4675-a8da-e6fe8d0a29fd" />


2. **Define SPOOLMAN_ID per filament profile (required)**
   Open **Filament → Notes** of each filament profile and add a plain line:

   ```
   SPOOLMAN_ID=123
   ```
   <img width="614" height="299" alt="grafik" src="https://github.com/user-attachments/assets/c76b1f10-9df5-4dd0-951c-2d64b8fea818" />


   This is exported into the G-code header as:

   ```
   ; filament_notes = SPOOLMAN_ID=123
   ```

   Use a **different ID for each filament profile**.

3. **Where does SPOOLMAN_ID come from?**
   It is the **numeric ID of a pre-created Spool in Spoolman**:

   * Open Spoolman → **Spools**.
   * The leftmost **ID** column shows numbers (e.g., `4`).
   * You can also see it in the spool detail URL (`…/spool/4`).
   * Create the spool first if it does not exist yet.
   * Map **one filament profile ↔ one Spool ID**.

<img width="823" height="462" alt="Screenshot 2025-11-08 184138_spoolman_id" src="https://github.com/user-attachments/assets/16a70f02-2c9c-4d08-a25e-c448abea18e0" />



4. **Keep Binary G-code disabled**
   In **Printer Settings → General → Firmware**, ensure **Supports binary G-code** is **unchecked** (the script reads plain text).

   <img width="998" height="962" alt="grafik" src="https://github.com/user-attachments/assets/e906b33e-60b4-4664-8b3d-79e5f027d7c2" />


6. *(Optional)* **Verbose G-code**
   PrusaSlicer usually writes the filament summary header automatically. Enabling **Verbose G-code** under **Print Settings → Output options** keeps all helpful comments.

> Upload workflows (PrusaConnect/OctoPrint) are supported: the script uses
> `SLIC3R_PP_OUTPUT_NAME` when available so the copied file name matches the
> final uploaded name.

---

## How It Works

* PrusaSlicer calls the batch with the path to the generated G-code as `%1`.
* The script:

  1. Derives a clean output name (handles `.pp` and upload name cases).
  2. Copies the file to `DST` (creates the folder if missing).
  3. Runs a short PowerShell snippet that:

     * searches the file for `SPOOLMAN_ID\s*=\s*(\d+)` (from `filament_notes`),
     * reads `; filament used [g] = X.Y`,
     * sends `PUT {BASE_URL}/api/v1/spool/{NNN}/use` with JSON `{ "use_weight": X.Y }`.

---

## Quick Test (without PrusaSlicer)

1. Create `test.gcode` with:

   ```gcode
   ; filament_notes = SPOOLMAN_ID=4
   ; filament used [g] = 12.34
   ```
2. Run:

   ```bat
   postprocess_spoolman.bat "C:\path\to\test.gcode"
   ```
3. You should see a PUT request; Spoolman spool **4** should receive `use_weight = 12.34`.

---

## Exit Codes

* `0`   — success
* `100` — no input filepath from PrusaSlicer
* `101` — source file not found
* `102` — copy failed
* `103` — copy produced no file
* `2`   — `SPOOLMAN_ID` not found in G-code (check Filament Notes)
* `4`   — `filament used [g]` not found in G-code

---

## Troubleshooting

* **`[ERROR] SPOOLMAN_ID not found.`**
  Ensure **Filament → Notes** contains `SPOOLMAN_ID=<integer>` on a line by itself, and that the corresponding spool exists in Spoolman.
* **`[ERROR] 'filament used [g]' not found.`**
  Slice a real model (empty plates may not produce the summary). Consider enabling **Verbose G-code**.
* **Nothing copied?**
  Check that `DST` exists or can be created; the script attempts to create it.
* **Network issues**
  Verify that `{BASE_URL}` is reachable from your PC. Prefer a trusted LAN.

---

## Security & Privacy

* Uses `-ExecutionPolicy Bypass` only for the embedded PowerShell snippet.
* No personal usernames, hostnames, or IPs are hard-coded by default.
* If exposing Spoolman beyond your LAN, consider HTTPS/SSL termination.

---

## Limitations

* Windows-only (Batch + PowerShell).
* Requires `SPOOLMAN_ID` to be present in **Filament Notes**.

---

## License

MIT — see [`LICENSE`](./LICENSE).

---

## Contributing

Issues and PRs are welcome. Please keep changes minimal, dependency-free, and focused on reliability.

```
```
