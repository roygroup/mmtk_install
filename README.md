# Molecular Modelling Tool Kit (MMTK) install script
This is a self contained bash script that attempts to automate the process of installing the MMTK python package and all the required dependencies. The script *should* run on all linux and OSX systems. It is not designed to be used on Windows. Minimal error and dependency checking is provided, if any issues occur during installation users should read the FAQ and then check the logs. Following that users should ask for help from someone in the group.

To install
----------
```
./mmtk_install.sh
```

By default mmtk and its related dependencies will be installed to the local directory `$HOME/.mmtk`.
If you wish to change the installation directory you can modify the variable `INSTALL_DIRECTORY` on line 10 of the `mmtk_install.sh` script.

#### SHARCNET
Note that when installing on a compute canada cluster or SHARCNET cluster such as graham/cedar/orca you need do the installation in two steps.
You can only download the files when running on the head node. However the installation process can be ~ 1-2 hours and the actual installation part of the script **should not be** run on the head node. First you need to run the script on the head node until the downloads are finished, if the script does not automatically exit then you will need to exit the script with Ctrl+C. Next you should execute the script in an interactive session, or submit a job to the queue with sbatch/qsub.
Use the following command to request an interactive session on graham or cedar
```
salloc --time 2:0:0 --ntasks=8
```
you may need to add the `--account` parameter with the relevant user specification
```
salloc --time 2:0:0 --ntasks=8 --account=def-user
```
If you are on orca ssh into one of the dev nodes before executing the full installation
```
ssh orc-dev1
```


* nlogn
* graham
* cedar
* orca

Aliasing or modifying the PATH
------------------------------
MMTK requires a specific verison of python which is located at `INSTALL_DIRECTORY/bin`.
You may wish to create an alias for this version of python, or change your PATH.

Some examples are provided below

* **macOS + bash**
```
echo 'alias pydev=$HOME/.mmtk/bin/python' >> $HOME/.bash_profile
```
* **linux + bash**
```
echo 'alias pydev=$HOME/.mmtk/bin/python' >> $HOME/.bashrc
```
* **zsh**
```
echo 'alias pydev=$HOME/.mmtk/bin/python' >> $HOME/.zshrc
```

Obviously if you change the `INSTALL_DIRECTORY` you will need to change the aliases.
You may also use a different alias then pydev.


Changing the source files (url's)
--------------------------------------
On line 100 of `./mmtk_install.sh` there is an array `hyperlinks` of the source url's for each piece of software used in the installation of MMTK. You may modify these links if you wish to use more recent versions of the software, like a newer version of [fftw](http://www.fftw.org/). Unfortunately Python is locked to version 2.7.X and Numpy is locked to version 1.8.x due to dependencies in MMTK. You can [read more about that here](https://github.com/khinsen/MMTK). The hyperlink_names array just stores strings which are printed to the user in error messages.
The code assumes that the two arrays are the same length and are in the same order. Do not **remove** any of the url's or names, **only** replace the url's with newer versions if you have confirmed that MMTK will install successfully.

What the script does
--------------------
1. Check which OS and architechture it is running on and provides any relevant information about software that is necessary later in the install. The script will exit at this point if necessary software is not present on the local machine. This may require the user to install certain software on their own.

2. Create the following directories
    * `INSTALL_DIRECTORY`
    * `INSTALL_DIRECTORY/src`
    * `INSTALL_DIRECTORY/logs`

3. Begin downloading the necessary source files to the src directory. When re-running the script it preforms a basic check which *should* detect any source files which were previously downloaded. It will print relevant error messages.

4. After confirming that all necessary source files are present the installation will begin. If the script exits before printing the string `Everything is done and MMTK should work now!` this indicates that there was an issue with the installation. First check the log file in the current directory which is named `logfile`. This should indicate which step in the installation failed. Then you can check the relevant log file in the `./INSTALL_DIRECTORY/logs` directory to see the **exact** error message.

    Software is installed in the following order

    * **0** - Python
    * **1** - Cython
    * **2** - zlib
    * **3** - HDF5
    * **4** - netCDF (no support for fortran)
    * **5** - NumPy
    * **6** - SciPy
    * **7** - FFTW
    * **8** - MMTK
    * **9** - fortran binaries for netCDF

    You can rerun the script where you left off by providing a NUMBER argument (shown above) to the script like so: `./mmtk_install.sh 2`, where 0 starts the installation from scratch. The script will continue with the installation ASSUMING that every package before this point SUCCESSFULLY installed, **there is no error checking!**. For example: if FFTW fails to install then you can run `./mmtk_install.sh 7` which will retry the installation of FFTW, and then MMTK, **under the assumption that Python, Cython, zlib, HDF%, netCDF, NumPy, and SciPy all installed correctly**.

5. Finally the last package 9 (fortran_netCDF) is not necessary to run MMTK. Therefore the default setting is to not install it. It is necessary if you want to write fortran code that can read and write \*.nc files. To install the fortran binaries for netCDF change the variable `NETCDF_FORTRAN` on line 37 to true. If you need the fortran binaries for netCDF you *might* need to add the following line to your `.bash_profile` or `.bashrc`
```
export LD_LIBRARY_PATH=$HOME/.mmtk/lib:$LD_LIBRARY_PATH
```

