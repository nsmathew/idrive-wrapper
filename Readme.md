idrive-wrapper
=============

Description
-----------
Runs the idevsutil commands for uploading, deleting, downloading and other actions using command line options. idevsutil is an official command line utility provided by IDrive(c).

Language
--------
Shell script

Platform
--------
Linux

Installation
------------
For Arch Linux: Use the PKGBUILD from the AUR, https://aur.archlinux.org/packages/idrive-wrapper.

For other distributions: Download idrive-wrapper.sh, idrive-wrapper_manual.txt and .idrivewrc. Then download the 'idevsutil' from the IDrive site, http://evs.idrive.com/download.htm#command-line-utility and install it.

Usage
-----
Refer to the manual on detailed usage of the program. The .idrivewrc config file provided can be filled in and placed in the ~/.config folder. If the config file is not used then the required parameters have to be given via the command line options. 

The usage in brief is as below:
<pre>
idrive-wrapper [OPTIONS [ARGUMENTS]] [IDRIVE_USERID]
-u      - Upload files/folder given in config file to IDrive
-U ARG  - Upload files/folder given as ARG(csv) to IDrive
-P ARG  - Home folder in IDrive to use for uploads
-d      - Delete file/folder given in config file
-D ARG  - Delete file/folder given in ARG(csv) from IDrive
-g ARG  - Download files given as ARG(csv) to /tmp/idrive-downloads/
-G ARG  - Download files from -g option to ARG
-l ARG  - List or search for ARG in IDrive
-v ARG  - Show versioning info for ARG
-p ARG  - Show file/folder properties for ARG
-s      - Show space usage in IDrive
-o ARG  - Specify log file
-h      - Show detailed help
Config file is at ~/.config/.idrivewrc
</pre>
