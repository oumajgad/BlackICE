# BlackICE for Hearts of Iron III
### This is the official repo for the mod.

### How to build a test version
There is a GitHub action which builds the installer: a single
`BlackICE <version> Setup.exe`. Run it and point it at the base game folder (the
one with `hoi3_tfh.exe` in it) - there is nothing to extract and no zip inside a
zip.

Start it from the **Actions** tab, pick **Build installer**, and press **Run
workflow**. Two options:

| Option | What it does |
| --- | --- |
| **version** | Stamped into the build. Leave it as `GitHub` for a test version, or give a release number like `15.2`. |
| **bundle_runtimes** | Includes the Microsoft runtimes (C++, DirectX) so the installer can fix a machine that is missing them. Adds about 56 MB and a few minutes. Untick it for a quicker test build. |

When it finishes, download the artifact from the run's summary page. It is kept
for 30 days. The screenshots below show where to start an action and where the
download is.

Running it costs nothing: Actions minutes and artifact storage are both free for
public repositories on GitHub's standard runners.

![First](https://github.com/oumajgad/BlackICE/blob/master/DaveStuff/action1.png?raw=true "How to start an action")
![Second](https://github.com/oumajgad/BlackICE/blob/master/DaveStuff/action2.png?raw=true "Where to download the file")

The installer also patches `hoi3_tfh.exe` for 4 GB of memory, moves the unused
3D sprites aside, installs any missing runtimes and makes a shortcut - all the
steps that used to be done by hand after extracting the zip.

To build one locally instead, see [installer/README.md](installer/README.md).

### Where to get older versions?
Versions from 10.33 onwards can be downloaded from my ([@Dsafe1](https://github.com/Dsafe1)) [GoogleDrive](https://drive.google.com/drive/folders/17b5sYNkG1sfR8vqJHtatweoxQaWM4icy?usp=drive_link)
