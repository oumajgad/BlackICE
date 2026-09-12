# BlackICE installer

Builds a single `BlackICE <version> Setup.exe` that replaces the self extracting
archive and the ten step forum post.

## Building a release

```
python installer/fetchRedists.py          # once, or when Microsoft ships updates
python installer/buildInstaller.py 15.2
```

The result lands in `installer/output/`. Nothing else is needed — no converting
to SFX, no pasting `SFXArchiveText.txt` into WinRAR.

### Requirements

| Tool | Why | Where |
| --- | --- | --- |
| Inno Setup 6 | compiles the installer | `winget install JRSoftware.InnoSetup` |
| 7-Zip | unpacks `dxvk.rar` and trims the DirectX bundle | already installed |
| Python 3 | the two build scripts | already installed |

`buildInstaller.py` finds `ISCC.exe` through Inno's own registry entry, so it
works whether Inno was installed per user (winget) or into Program Files. Set
the `ISCC` environment variable to override.

### Flags

- `--no-redist` — build without bundling the Microsoft runtimes. The installer
  still detects and reports what is missing; it just cannot fix it.
- `--fast` — no compression, so a build takes ~30 s instead of a long LZMA2 run.
  For trying out wizard changes only. Such a build is ~2.5 GB, runs unelevated,
  and prints `do not publish`.

  A `--fast` build installs **per user** (HKCU) under its own `AppId` and calls
  itself `(TEST BUILD - not a release)` in the apps list, so it can never be
  mistaken for, or silently sit beside, a real all-users install. **Always
  remove a test install by running its uninstaller** — deleting the folder
  leaves a dead entry in the apps list with no way to remove it from the UI.

## What the installer does

Everything `installInstructions.txt` used to ask the player to do:

| Old step | Now |
| --- | --- |
| 4. Select the base game folder | Validated, and guessed where possible |
| 5. Extract, say yes to overwrites | Just happens |
| 6. Download Podcat's LAA exe | **Gone** — see below |
| 7. Run `zDsafe_ExePatcher.exe` | Done during install, with a backup |
| 8-10. Remove Sprites in game, restart | Done during install |
| Optional: unpack `dxvk.rar` by hand | A checkbox |
| Redistributables | Detected and installed |

### The exe patch

Applying only `PatchLargeAddressAware` from `tools/PythonExePatcher/ExePatcher.py`
to a stock `hoi3_tfh.exe` produces a file **byte-identical** to Podcat's LAA exe:

```
stock    sha256 7c99eb75824532d7e4ad80a612a7ec38bacc793a6180a5ef4d0a14f1e8eaee77
patched  sha256 0eb63e3e4a844383d379d8308fe75ed2a471d4fc0bdd9d678ce06f4dbc9d098b  <- == Podcat's exe
```

So the separate download was never necessary, and the installer does not ship
that exe. The other three patches in `ExePatcher.py` are **not** applied: BiceLib
sets those up at runtime.

Before writing anything the installer fingerprints all nine patch sites. It
patches only an exe whose sites all hold the stock bytes, reports "already done"
when they all hold the patched bytes, and refuses to touch anything else — these
are absolute offsets, and a different build would be corrupted silently. The
original is kept as `hoi3_tfh.exe.preBlackICE`.

### Which runtimes, and why

Read off the import tables and SxS manifests of the shipped binaries, not from
the usual "install everything back to 2005" advice:

| Runtime | Needed by |
| --- | --- |
| VC++ 2005 SP1 x86 | `lua51.dll`, `lua5.1.dll`, `script/lfs.dll` (`Microsoft.VC80.CRT`) |
| VC++ 2008 SP1 x86 | `PdxConnect.dll`, `script/wx.dll` (`Microsoft.VC90.CRT`) |
| VC++ 2010 SP1 x86 | `tbb.dll`, `tbbmalloc.dll`, `hoi3game.exe` (`msvcr100.dll`) |
| VC++ 2015-2022 x86 | `script/BiceLib.dll` (`vcruntime140.dll`, UCRT) |
| VC++ 2015-2022 x64 | `stats/visualizeStatisticCLI.exe` |
| DirectX 9.0c | `hoi3_tfh.exe` imports `d3dx9_42.dll` |
| .NET Framework 3.5 | `launcher.exe` is managed, CLR v2.0.50727 |

VC++ 2012 and 2013 are **not** included: nothing links against them.

`fetchRedists.py` downloads these from Microsoft into `installer/redist/`
(gitignored, ~56 MB). The DirectX end user runtime is a 95 MB bundle of which
only `DXSETUP` plus the `d3dx9_42_x86` cab is kept, about 3 MB.

.NET 3.5 is the one component that cannot be bundled — it is a Windows feature,
not a download. The installer enables it with
`DISM /Online /Enable-Feature /FeatureName:NetFx3`, which pulls from Windows
Update, and says so plainly if that fails.

### The shortcut

The shortcut launches the game directly, which skips the launcher and with it
both the "pick the mod in the launcher" step and the .NET dependency:

```
hoi3_tfh.exe  -mod=mod/BlackICE 15.2.mod        WorkingDir = the base game folder
```

**The mod path is not quoted**, even though it contains spaces. That is the form
the game's own launcher uses — read off a running `hoi3_tfh.exe` with
`Get-CimInstance Win32_Process` — and quoting it the way a command line normally
would stops the game finding the mod. The path is relative to `tfh\`, while the
working directory is the base folder.

`Mod File/BICE.bat` shows the same unquoted shape.

### Versions

Every version shares one `AppId`, so there is a single entry in Windows'
installed apps list and installing 15.1 over 15.0 relabels it rather than adding
a second. Uninstalling removes the files from every version installed into that
folder — Inno merges the uninstall logs.

The mod folders themselves are versioned (`tfh\mod\BlackICE 15.0`), so without
help an old release would sit there costing ~2.4 GB with nothing in the UI
pointing at it. `oldversions.iss` finds them, shows what each one takes, and
offers to remove them, ticked by default. That page is skipped when there is
nothing to remove.

Removal happens **after** the new version is installed, so a failed install
never costs anyone the version they already had, and the scan excludes the
folder being installed so a reinstall cannot delete itself.

The uninstaller offers the same choice (`uninstallpick.iss`), because otherwise
there is no way to drop an old version short of reinstalling. It shows a custom
form — uninstallers have no wizard pages — from `InitializeUninstall`, which is
the last point at which the uninstall can still be called off:

- **everything ticked** → a real uninstall: Inno removes what it installed, the
  entry goes, and the offer to restore the exe and sprites follows.
- **only some ticked** → housekeeping: those folders go, `InitializeUninstall`
  returns False so Inno removes nothing else, and the entry is relabelled to the
  newest version still present so the apps list never names a version that is
  gone. The game itself is left completely alone.
- **a silent uninstall** skips the form and removes everything, as a silent run
  should.

#### What counts as a version

Only `BlackICE ` followed by a **digit**. `BlackICE 15.0` yes, `BlackICE GitHub`
no — that last one is a working copy someone develops against, and offering it
for deletion ticked by default would be a disaster. Anything else sharing the
folder, such as `HoI3PosEd release`, is likewise untouched.

Junctions and symlinks are skipped outright: deleting through one would reach
out of the game folder and take whatever it points at with it.

Saves are never touched: each version's `user_dir` is
`Documents\Paradox Interactive\Hearts of Iron III\BlackICE <version>`, outside
the game folder, so a removed version can be reinstalled and its campaigns
resumed.

`AppId` must never change once a version has shipped — it is the key Windows
finds the mod under, and a new one would orphan every existing install.

### What is reversible

The uninstaller offers to put back, and does not touch the game otherwise:

- `hoi3_tfh.exe` — from `hoi3_tfh.exe.preBlackICE`
- the sprites in `gfx\anims` — moved back out of `gfx\anims\backup`
- `lua5.1.dll` — the game ships its own and the mod replaces it, so the original
  is set aside as `lua5.1.dll.preBlackICE` before the copy

The restore runs at `usPostUninstall`, **after** Inno deletes the files it
installed. Doing it at `usUninstall` puts `lua5.1.dll` back only for Inno to
delete it a moment later.

## Layout

```
installer/
  BlackICE.iss        the wizard: pages, files, tasks, install steps
  inc/
    bytes.iss         raw byte read/write over TFileStream
    gamefolder.iss    finding and validating the base game folder
    basefiles.iss     backing up base folder files the mod replaces
    exepatch.iss      the LAA patch, with build fingerprinting
    sprites.iss       moving gfx\anims aside, as the Utility's button does
    oldversions.iss   finding and removing older BlackICE versions
    uninstallpick.iss which versions to remove, asked on the way out
    redist.iss        runtime detection and silent install
  fetchRedists.py     downloads the Microsoft runtimes
  buildInstaller.py   stamps the version, runs ISCC
  redist/             gitignored, filled by fetchRedists.py
  staging/            gitignored, generated .mod and unpacked dxvk/borderless
  output/             gitignored, the built installer
```

`releaseCommon.py` in the repo root holds the mod folder list and the version
stamping shared with `zipperRelease.py`, so the zip and the installer cannot
disagree about what ships or what version it claims to be.

## Gotchas

Things that cost time once and would again:

- **Every include must start with `[Code]`.** The files are concatenated, so
  when one starts the parser is still inside the previous one's `[Code]`
  section, and a leading `;` banner gets fed to the Pascal compiler.
- **No source line may begin with `[` or `#`.** A wrapped `Format(...)`
  argument list starting a line reads as a section header, and a wrapped
  `#13#10` reads as a preprocessor directive. Keep both on the previous line.
- **`IntToHex` does not exist** in Pascal Script, and `StrToInt` is not reliable
  for `$`-prefixed hex. `bytes.iss` does its own conversion.
- **Bytes must travel as `AnsiString`.** `String` is UTF-16 in Unicode Inno and
  would double every byte written.
- **ISCC takes one script.** Directives like `Compression` cannot be overridden
  from the command line; `--fast` switches them through a `FastBuild` define.
- Calling `ISCC.exe` from Git Bash mangles `/D...` arguments into paths. Go
  through `buildInstaller.py`, which uses `subprocess` directly.
- Editing these files through a shell heredoc eats backslash escapes: `inc\b...`
  becomes a backspace byte and `gfx\a...` a bell. Use an editor, or a Python
  script reading the pattern from `argv`, for anything containing a path.
- Inno refuses to build a single file installer above ~2.1 GB. The payload is
  2.4 GB raw but around 800 MB compressed, so there is room;
  `buildInstaller.py` warns if that headroom ever drops below 150 MB, at which
  point `DiskSpanning=yes` splits it into an exe plus `.bin` files.
