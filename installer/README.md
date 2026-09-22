# BlackICE installer

Builds a single `BlackICE <version> Setup.exe` that replaces the self extracting
archive and the ten step forum post.

## Building a release

```
python installer/fetchRedists.py          # once, or when Microsoft ships updates
python installer/buildInstaller.py 15.2
```

The result lands in `installer/output/`. Nothing else is needed — no zip, no
converting it to a self extracting archive.

Or run it on a runner: the **Build installer** action
(`.github/workflows/build-installer.yml`) does the same thing from the Actions
tab and uploads the exe as the run's artifact. It takes a version and a
"bundle the runtimes" tickbox. See the [root README](../README.md).

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

The write is attempted up to three times. The failure it guards against is
transient — something holding the exe open for a moment, typically antivirus
scanning a file the installer has just written, which was seen for real during
testing. Each attempt either completes and verifies, or restores the original
before retrying, so the exe is never left half written.

### Windows crash dumps

`crashdumps.iss` replaces step 2 of [CRASH-REPORTS.md](../CRASH-REPORTS.md), which asked
the player to type a `.reg` file in Notepad, save it with the right extension and run it
as admin. Almost nobody does that, so the crashes that matter most — the ones before
BlackICE has even loaded, which leave no report of its own — went unreported.

It writes Windows Error Reporting's per-executable LocalDumps setting:

```
HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps\hoi3_tfh.exe
    DumpCount = 5
    DumpType  = 1        mini dump, ~37 MB each
```

Scoped to that one executable, so nothing else on the machine is affected, and capped at
five dumps in `%LOCALAPPDATA%\CrashDumps`.

**It must be written to the 64-bit registry view.** The installer is a 32-bit program, so
a plain `HKLM` write is redirected into `Wow6432Node` — and `LocalDumps` only exists in
the native view, so the result would be a brand new key somewhere Windows never looks: a
setting that appears present and does nothing. `WerRootKey()` returns `HKLM64` on 64-bit
Windows and `HKLM` on 32-bit, where asking for a 64-bit view is an error.

An existing configuration is never overwritten, and the uninstaller only removes the key
when it holds exactly the two values above — which is how somebody's own setup is told
apart from ours without storing a marker anywhere.

### The uninstaller's name

Inno hardcodes it as `unins000.exe` and has no directive to change it. Renaming
it afterwards would stop Setup finding the previous install's log, which is how
reinstalling merges versions, so instead it lives in `{app}\BlackICE uninstall\`
rather than loose in the game folder where it reads like it might be the game's
own. The Start menu also gets a plainly named `Uninstall BlackICE` icon, and the
apps list entry is `BlackICE <version>`.

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

### Where saves live

Not in the game folder:

```
Documents\Paradox Interactive\Hearts of Iron III\BlackICE <version>\
```

One folder per version, holding that version's saves **and its `settings.txt`**.
The `settings.txt` in the game folder is not the one the game reads.

This is why removing a version is safe, and why the installer, the uninstaller
and the forum instructions all name the path rather than just promising saves
are untouched.

### Borderless window

The component only places `dinput8.dll` and its readme. It does nothing until
the player makes two edits, so the component description and the instructions
both say so — otherwise it looks like a feature that silently fails:

1. `fullScreen=no` in the **per-version** `settings.txt` named above.
2. Run the game once to generate
   `Documents\Paradox Interactive\v2winfix.ini`, then set `borderless=1` in it.

Optionally the window can be stretched to a larger monitor with the cursor still
lining up, via a `[dsafe]` section giving the played and actual resolutions.

The build stages `borderlessWithStretching.rar`, not `borderless.rar`. Both drop
the same `dinput8.dll` so only one can be installed; the stretching build is a
superset (`borderless=1` alone behaves exactly like the plain one) and is newer.

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

DXVK and the borderless fix are asked about **separately**, and only when they
are actually present. Neither is really part of the mod — both work just as well
on plain HoI3 — so removing BlackICE is no reason to assume they are unwanted.
Their `[Files]` entries carry `uninsneveruninstall` so Inno does not delete them
with everything else, and `extras.iss` removes them only on a yes. A silent
uninstall removes them, like everything else it does without asking.

`Documents\Paradox Interactive\v2winfix.ini` is deliberately left alone: the
borderless DLL writes it, but it is shared with the other Paradox games v2winfix
supports, so deleting it could take another game's settings with it.

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
    extras.iss        DXVK and borderless: removed only if asked for
    crashdumps.iss    turning on Windows crash dumps for the game
    oldversions.iss   finding and removing older BlackICE versions
    uninstallpick.iss which versions to remove, asked on the way out
    redist.iss        runtime detection and silent install
  fetchRedists.py     downloads the Microsoft runtimes
  buildInstaller.py   stamps the version, runs ISCC
  redist/             gitignored, filled by fetchRedists.py
  staging/            gitignored, generated .mod and unpacked dxvk/borderless
  output/             gitignored, the built installer
```

`releaseCommon.py` in the repo root holds the definition of what a release is:
the folders the mod is made of, where it goes inside the game, and the two lines
that carry the version.

`BlackICE.iss` lists those folders one by one rather than walking the tree, so
`buildInstaller.py` checks the two agree before compiling (`checkIssCoverage`)
and refuses to build if they do not. Without that, adding a new top level folder
to the mod would leave it silently out of the installer — the build would
succeed and the mod would be broken with nothing pointing at why.

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
- **`/SUPPRESSMSGBOXES` does not reach a `MsgBox` called from code.** It only
  silences Inno's own prompts. A code `MsgBox` will stop a `/VERYSILENT` run
  dead and wait for a click, which is invisible in a scripted test and makes
  results depend on whatever got clicked. Guard every one with
  `UninstallSilent()` / `WizardSilent()`.
- Editing these files through a shell heredoc eats backslash escapes: `inc\b...`
  becomes a backspace byte and `gfx\a...` a bell. Use an editor, or a Python
  script reading the pattern from `argv`, for anything containing a path.
- Inno refuses to build a single file installer above ~2.1 GB. The payload is
  2.4 GB raw but around 800 MB compressed, so there is room;
  `buildInstaller.py` warns if that headroom ever drops below 150 MB, at which
  point `DiskSpanning=yes` splits it into an exe plus `.bin` files.
