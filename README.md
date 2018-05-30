# mmtk_install
Install script for MMTK

================INSTALLATION================
For install the mmtk and the python developer packages, the only thing you have to do is:

        ./mmtk_install.sh

All the things now is installed in your home directory ~/.mmtk

=============MODIFY BASH PROFILE=============
As the mmtk uses the developer version of python, not the python installed in your server or PC.
You have to modify the SHELL profile to make an alias to indicate the version you want to use.
As we always leave the original version of python with the command "python", we chose the "pydev"
for developer version of python.

If you are using the bash SHELL, you can add alias in .bash_profile in your home directory. If you are
using other SHELL, like zsh, you can modify the specific profile like .zshrc:

        cd #change directory to your home directory
        vi .bash_profile #open the bash profile

Then you can add following lines in your .bash_profile:

        alias '"$HOME/.mmtk/bin/python" $*'
        export LD_LIBRARY_PATH=$HOME/.mmtk/lib

If you change the directory of the mmtk, please modify the above paths by your own.

Now, you can use "pydev" to run your simulation with MMTK

=====================END=======================
