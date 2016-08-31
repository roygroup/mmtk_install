#!/bin/bash

# Molecular Modeling Tool Kit installer
# version 0.2.8


# # # # # # # USER FAQ # # # # # # #
# HELLO USER!
# PLEASE CHOOSE A DIRECTORY WHERE MMTK WILL BE INSTALLED
INSTALL_DIRECTORY=~/.testa
#
# - The script first checks which OS and architechture it is running on and provides any relevant information about software that is necessary later in the install
#
# - The script will create the following directories
# ./INSTALL_DIRECTORY
#   ./INSTALL_DIRECTORY/downloads
#   ./INSTALL_DIRECTORY/logs
#
# - It will begin downloading the necessary source files to the downloads directory
# If you re run the script it SHOULD detect any source files it has previously downloaded. It will print relevant error messages.
# If you want to install with different version of the respective pacakges you just need to change the links in the hyperlinks array. The hyperlink_names array is just for printing purposes.
#
# - Once all the files are downloaded the script will begin installing
# If it stop before printing (Everything is done and MMTK should work now!) then there may be an issue
# Check the relevant log file in the ./INSTALL_DIRECTORY/logs directory, meaning the last package the script was trying to install
# You can rerun the script where you left off by providing a NUMBER argument to the script like so:
# ./script.sh 2
# The script will continue with the installation ASSUMING that every package before this point SUCCESSFULLY installed, there is no error checking
#
# The number starting from 0 (Python) and ending at 8 (MMTK) indicates from which package to restart the install
# ( Python Cython zlib HDF5 c_netCDF NumPy SciPy FFTW MMTK )
#
# - Finally the last package 9 (fortran_netCDF) is not necessary to run MMTK.
# Therefore the default setting is to not install it.
# It is necessary if you want to write fortran code that can read and write *.nc files
# Set this flag to true if you wish to install it.
NETCDF_FORTRAN=false
#
# # #



# # # # # # # DEVELOPMENT NOTES # # # # # # #
#
# Extra features that could be implemented:
# 1 - checks validity of source file
#   - checks if there is a file on nlogn and downloads from there
#
# 2 - handling of library linkers for all cases
#
# 3 - checks for gcc and if not present downloads and install it
#   - obviously it should check for clang on iMac's instead, possibly updating clang?
#
# 4 - checks for gfortran and if not present, or a bugged/depreciated version downloads a new one
#
#
# === Errors ===
#
# -- OSX 10.7.5 --
#   if gfortran is not installed then fftw will fail to build and give the following error
#   configure: error: cannot compile a simple Fortran program
# ----------------
#
#
# -- OSX 10.10.4 --
# If you get the following error, most likely you are not using clang to build python, you want to use the gcc found in /usr/bin/ which is the clang version
# also make sure you Xcode is up to date by running xcode-select --install
# check your $PATH you may have /usr/local/bin or some other location with non-clang gcc installed BEFORE /usr/bin/
#
# Example error output from failed python build:
# In file included from /usr/include/Availability.h:153:0,
#                  from /usr/include/stdio.h:65,
#                  from Include/Python.h:33,
#                  from Python/mactoolboxglue.c:26:
# /System/Library/Frameworks/CoreServices.framework/Frameworks/FSEvents.framework/Headers/FSEvents.h:262:38: error: expected ',' or '}' before '__attribute__'
#    kFSEventStreamCreateFlagIgnoreSelf __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_6_0) = 0x00000008,
#                                       ^
# /System/Library/Frameworks/CoreServices.framework/Frameworks/FSEvents.framework/Headers/FSEvents.h:414:38: error: expected ',' or '}' before '__attribute__'
#    kFSEventStreamEventFlagItemCreated __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_6_0) = 0x00000100,
#                                       ^
# make: *** [Python/mactoolboxglue.o] Error 1
# ----------------
#
#
#
# #



#lang specific details
export LANG=C
export LC_ALL=C
set -e

# the directories we will be installing to
DOWNLOAD_DIRECTORY="$INSTALL_DIRECTORY"/downloads
LOG_DIRECTORY="$INSTALL_DIRECTORY"/logs

# where the script is located
SCRIPT_FILE="${BASH_SOURCE[${#BASH_SOURCE[@]} - 1]}"
SCRIPT_DIR="$(dirname "${SCRIPT_FILE}")"

# the name of the log file
LOG_FILE="$SCRIPT_DIR"/logfile      # for now the current directory

# make sure the log file actually exists, and then redirect all stdout and stderr to the log file
touch "$LOG_FILE"
exec > >(tee "$LOG_FILE") 2>&1

# error codes 
E_WRONGKERNEL=83    # wrong kernel
E_WRONGARCH=84      # wrong architecture
E_WRONGARS=85       # Arguments wrong error
E_XCD=86            # Can't change directory?
E_NOTROOT=87        # Non-root exit error
E_DOWNLOAD=88       # Failed to download necessary files
tar_error_string="Failed to untar: %s\nIs this hyperlink broken: %s\nIt is required that you can download all packages before the installer can run.\n"

# keep all download options contained
function download() {
    # -s Silent or quiet mode. Don't show progress meter or error messages. Makes Curl mute.
    #    It will still output the data you ask for, potentially even to the terminal/stdout unless you redirect it.
    # -S When used with -s it makes curl show an error message if it fails.
    # -L Handles redirection, makes curl redo the request on the new location
    # -O Write output to a local file named like the remote file we get.
    curl -O -L -s -S "${1}"
}

# let the user know if we failed to get to the correct directory, wrap cd in an "error checking function"
function change_dir()   {
    cd ${1} || {
        printf "Cannot change to directory: %s\n" "${1}"
        exit ${E_XCD};
    }
}

# Flags
INSTALL_PIP_FLAG=false

# check what OS we are running
# get the kernel Name
printf "\n     ===============  machine info  ===============     \n"
Kernel=$(uname -s)
case "$Kernel" in
    Linux)
        Kernel="linux"
        INSTALL_PIP_FLAG=true
        ;;
    Darwin)
        MAC_VERSION=$(sw_vers -productVersion)
        Kernel="OSX $MAC_VERSION"
        export GCC=/usr/bin/clang

        case "$MAC_VERSION" in
            10.11*) # (OS X 10.10) and later (works well with El Capitan, OS X 10.11)
                GFORTAN_LINK=http://coudert.name/software/gfortran-5.2-Yosemite.dmg         ;; #/gfortran-5.2-Yosemite.dmg
            10.10*) # (OS X 10.10)
                GFORTAN_LINK=http://coudert.name/software/gfortran-4.9.2-Yosemite.dmg       ;; #/gfortran-4.9.2-Yosemite.dmg
            10.9*)
                GFORTAN_LINK=http://coudert.name/software/gfortran-4.9.0-Mavericks.dmg      ;; #/gfortran-4.8.2-Mavericks.dmg
            10.8*)
                GFORTAN_LINK=http://coudert.name/software/gfortran-4.8.2-MountainLion.dmg   ;;
            10.7*)
                GFORTAN_LINK=http://coudert.name/software/gfortran-4.8.2-Lion.dmg           ;;
            *)
                printf "You need to find a source for gfortran to install on you iMac\n"
                exit 0
                ;;
        esac

        # make sure xcode is installed and up to date
        echo "Is xcode installed and up to date?"
        select yn in "Yes" "No"; do
            case $yn in
                Yes ) break;;
                No ) echo "Please install/update xcode before running the script again"; exit 0;;
            esac
        done

        # make sure you have openssl installed for pip
        if [[ $MAC_VERSION == 10.1* ]]; then
            which -s brew
            if [[ $? != 0 ]] ; then # then brew doesn't exist
                # let the user install homebrew
                echo "You are running OSX and you don't have brew"
                echo "This means that you will not have pip because openssl is not supported in 10.10+"
                echo "If you want pip please exit and install brew"
                echo "Are you sure you wish to proceed?"
                select yn in "Yes" "No"; do
                    case $yn in
                        Yes ) break;;
                        No ) exit;;
                    esac
                done
            else
                # brew does exist!
                brew ls --versions openssl
                if [[ $? != 0 ]] ; then # but no openssl
                    echo "Apparently you don't have openssl installed through brew"
                    echo "Can I install openssl using brew?"
                    select yn in "Yes" "No"; do
                        case $yn in
                            Yes ) brew install openssl; brew link --force openssl; break;;
                            No ) exit;;
                        esac
                    done
                else
                    # openssl installed! joy!
                    echo "Good you have openssl installed through brew, pip will be installed successfully"
                    INSTALL_PIP_FLAG=true
                fi
            fi
        else
            # if you have an ealier version of OSX (before 10.10) then openssl should be native
            # and you won't need another version, from brew for example
            INSTALL_PIP_FLAG=true
        fi
        # lazy way to force the installer to use clang instead of an independent version of gcc installed in /usr/local/bin
        export PATH="/usr/bin:$PATH"
        ;;
    FreeBSD)
        INSTALL_PIP_FLAG=true
        Kernel="freebsd"
        ;;
    # default case
    * )
        printf "Your Operating System %s -> IS NOT SUPPORTED\n" "${Kernel}"
        exit ${E_WRONGKERNEL}
        ;;
esac
printf "Operating System Kernel: %s\n" "${Kernel}"

# check the architechture
Architecture=$(uname -m)
case "$Architecture" in
    x86)
        Architecture="x86"
        ;;
    ia64)
        Architecture="ia64"
        ;;
    i?86)
        Architecture="x86"
        ;;
    amd64)
        Architecture="amd64"
        ;;
    x86_64)
        Architecture="x86_64"
        ;;
    sparc64)
        Architecture="sparc64"
        ;;
    * )
        printf "Your Architecture %s -> IS NOT SUPPORTED\n" "${Architecture}"
        exit ${E_WRONGARCH}
        ;;
esac
printf "Operating System Architecture: %s\n" "${Architecture}"


# lets check if you have gfortran
if [[ "$(command -v gfortran)" ]]; then
    printf "\nIt seems that you have gfortran, however, if the installer fails while trying to install FFTW it is most likely a gfortran issue\n\n"
    HAS_GFORTRAN=true
else
    printf "\nYou do not have gfortran! You will not be able to compile FFTW.\n"
    printf "Please download and install gfortran from this link:\n%s\nNote that this requires administrative privilages!\n" "$GFORTAN_LINK"
    HAS_GFORTRAN=false
fi

# create the directories that we will be working in
mkdir -p ${INSTALL_DIRECTORY}
mkdir -p ${DOWNLOAD_DIRECTORY}
mkdir -p ${LOG_DIRECTORY}
printf "Succesfully made directories: \n%s\n%s\n%s\n\n" "${INSTALL_DIRECTORY}" "${DOWNLOAD_DIRECTORY}" "${LOG_DIRECTORY}"

# move to the download directory to start downloading
change_dir "${DOWNLOAD_DIRECTORY}"

# the four arrays are ordered respectively
declare -a hyperlink_names  # the generic names of the packages we require
declare -a hyperlinks       # hyperlinks to the SPECIFIC version of that package we wish to download
declare -a filenames        # the name of the tar downloaded from the hyperlink
declare -a foldernames      # the default names of the folders containing the un-tar'ed files


hyperlink_names=( Python Cython zlib HDF5 c_netCDF NumPy SciPy FFTW MMTK fortran_netCDF )

# note we updated the Cython package from 0.20.1 to 0.23.1 becuase it is necessary to run Dmitri/Matt's MMTK version
hyperlinks=(
                https://www.python.org/ftp/python/2.7.11/Python-2.7.11.tgz
                https://github.com/cython/cython/archive/0.24.x.tar.gz # previous version 0.23.1
                http://zlib.net/zlib-1.2.8.tar.gz
                http://www.hdfgroup.org/ftp/HDF5/releases/hdf5-1.8.16/src/hdf5-1.8.16.tar.gz
                ftp://ftp.unidata.ucar.edu/pub/netcdf/netcdf-4.3.3.1.tar.gz
                http://sourceforge.net/projects/numpy/files/NumPy/1.8.2/numpy-1.8.2.tar.gz
                https://sourcesup.renater.fr/frs/download.php/file/4425/ScientificPython-2.9.4.tar.gz  # previous version (2.9.3)
                http://www.fftw.org/fftw-3.3.4.tar.gz
                https://bitbucket.org/khinsen/mmtk/get/path_integrals.tar.gz
                ftp://ftp.unidata.ucar.edu/pub/netcdf/netcdf-fortran-4.4.2.tar.gz
            )


arraylength=${#hyperlinks[@]} # the number of packages to download

# download loop
for (( i=0; i<${arraylength}; i++ )); do

    # first store the filename and the foldername (assuming default output from tar)
    filenames[$i]=$(basename  "${hyperlinks[$i]}")
    temp="${filenames[$i]}" # couldn't get expression expansion to work without this line
    foldernames[$i]="${temp%.t*}"

    # check to see if the tar has been downloaded and the folder has been created
    if [ -e "${filenames[$i]}" ] && [ -d  "${foldernames[$i]}" ];
    then    # file and folder found so we don't need to do anything more (we hope!)
        printf "It seems that this resource %-8s has already been downloaded and un-tared\n" "(${hyperlink_names[$i]})"

    elif [ -e "${filenames[$i]}" ] && [ ! -d  "${foldernames[$i]}" ];
    then    # only the file found so we probably need to un-tar the file, maybe redownload if that doesn't work
        printf "It seems that this resource %-8s has already been downloaded but not un-tared so we are going to un-tar it\n" "(${hyperlink_names[$i]})"
        mkdir -p "${DOWNLOAD_DIRECTORY}/${foldernames[$i]}"
        tar -xzf "${filenames[$i]}" -C "${DOWNLOAD_DIRECTORY}/${foldernames[$i]}" --strip-components=1 || {
            printf "It seems we failed to un-tar %-35s so we are redownloading it\n" "(${filenames[$i]})"
            download "${hyperlinks[$i]}"
            mkdir -p "${DOWNLOAD_DIRECTORY}/${foldernames[$i]}"
            tar -xzf "${filenames[$i]}" -C "${DOWNLOAD_DIRECTORY}/${foldernames[$i]}" --strip-components=1 || {
                printf "${tar_error_string}" "${filenames[$i]}" "${hyperlinks[$i]}"; exit ${E_DOWNLOAD};
            }
        }
        printf "Un-tared  %-8s\n" "(${filenames[$i]})"
    else
            # file not found so proceed to download the file and un-tar it
        download "${hyperlinks[$i]}"
        mkdir -p "${DOWNLOAD_DIRECTORY}/${foldernames[$i]}"
        tar -xzf "${filenames[$i]}" -C "${DOWNLOAD_DIRECTORY}/${foldernames[$i]}" --strip-components=1 || {
            printf "${tar_error_string}" "${filenames[$i]}" "${hyperlinks[$i]}"; exit ${E_DOWNLOAD};
        }
        printf "Successfully downloaded and untared %-8s" "(${hyperlink_names[$i]})"
        printf "Filename   %s\nFoldername %s\n" "${filenames[$i]}" "${foldernames[$i]}"
    fi
done

printf "Finished downloading all required packages\n"

# start installing stuff
if [[ "$1" -le 0 ]]; then
    change_dir "${foldernames[0]}"
    printf "Attempting to build and install %s\n" "${hyperlink_names[0]}"
    {
    # only try to install pip if we have openssl
    if $INSTALL_PIP_FLAG; then echo "Pip will be installed"; PIP_OPTION=yes; else echo "No pip installed"; PIP_OPTION=no; fi
    ./configure --prefix="$INSTALL_DIRECTORY" --enable-unicode=ucs4  --with-ensurepip=${PIP_OPTION}
    make
    make install
    } >> "$LOG_DIRECTORY/${hyperlink_names[0]}log" 2>&1
    change_dir ..
    printf "%s successfully installed\n" "${hyperlink_names[0]}"
else
    printf "Assuming %s is already installed\n" "${hyperlink_names[0]}"
fi

if [[ "$1" -le 1 ]]; then
    change_dir "${foldernames[1]}"
    printf "Attempting to build and install %s\n" "${hyperlink_names[1]}"
    {
        "$INSTALL_DIRECTORY"/bin/python setup.py install
    } > "$LOG_DIRECTORY/${hyperlink_names[1]}log" 2>&1
    change_dir ..
    printf "%s successfully installed\n" "${hyperlink_names[1]}"
else
    printf "Assuming %s is already installed\n" "${hyperlink_names[1]}"
fi

if [[ "$1" -le 2 ]]; then
    change_dir "${foldernames[2]}"
    printf "Attempting to build and install %s\n" "${hyperlink_names[2]}"
    {
        ./configure --prefix="$INSTALL_DIRECTORY"
        make
        make check install
    } > "$LOG_DIRECTORY/${hyperlink_names[2]}log" 2>&1
    change_dir ..
    printf "%s successfully installed\n" "${hyperlink_names[2]}"
else
    printf "Assuming %s is already installed\n" "${hyperlink_names[2]}"
fi

if [[ "$1" -le 3 ]]; then
    change_dir "${foldernames[3]}"
    printf "Attempting to build and install %s\n" "${hyperlink_names[3]}"
    {
        ./configure --with-zlib="$INSTALL_DIRECTORY" --prefix="$INSTALL_DIRECTORY"
        make
        make check install
    } > "$LOG_DIRECTORY/${hyperlink_names[3]}log" 2>&1
    change_dir ..
    printf "%s successfully installed\n" "${hyperlink_names[3]}"
else
    printf "Assuming %s is already installed\n" "${hyperlink_names[3]}"
fi

if [[ "$1" -le 4 ]]; then
    change_dir "${foldernames[4]}"
    printf "Attempting to build and install %s\n" "${hyperlink_names[4]}"
    {
        CPPFLAGS=-I"$INSTALL_DIRECTORY"/include LDFLAGS=-L"$INSTALL_DIRECTORY"/lib \
            ./configure --prefix="$INSTALL_DIRECTORY"
        make check install
    } > "$LOG_DIRECTORY/${hyperlink_names[4]}log" 2>&1
    change_dir ..
    printf "%s successfully installed\n" "${hyperlink_names[4]}"
else
    printf "Assuming %s is already installed\n" "${hyperlink_names[4]}"
fi

if [[ "$1" -le 5 ]]; then
    change_dir "${foldernames[5]}"
    printf "Attempting to build and install %s\n" "${hyperlink_names[5]}"
    {
        "$INSTALL_DIRECTORY"/bin/python setup.py install
    } > "$LOG_DIRECTORY/${hyperlink_names[5]}log" 2>&1
    change_dir ..
    printf "%s successfully installed\n" "${hyperlink_names[5]}"
else
    printf "Assuming %s is already installed\n" "${hyperlink_names[5]}"
fi

if [[ "$1" -le 6 ]]; then
    change_dir "${foldernames[6]}"
    printf "Attempting to build and install %s\n" "${hyperlink_names[6]}"
    {
        export NETCDF_PREFIX="$INSTALL_DIRECTORY"
        "$INSTALL_DIRECTORY"/bin/python setup.py install
    } > "$LOG_DIRECTORY/${hyperlink_names[6]}log" 2>&1
    change_dir ..
    printf "%s successfully installed\n" "${hyperlink_names[6]}"
else
    printf "Assuming %s is already installed\n" "${hyperlink_names[6]}"
fi

if [[ "$1" -le 7 ]]; then
    change_dir "${foldernames[7]}"
    printf "Attempting to build and install %s\n" "${hyperlink_names[7]}"
    {
        ./configure --prefix="$INSTALL_DIRECTORY" --enable-shared
        make check install
    } > "$LOG_DIRECTORY/${hyperlink_names[7]}log" 2>&1
    change_dir ..
    printf "%s successfully installed\n" "${hyperlink_names[7]}"
else
    printf "Assuming %s is already installed\n" "${hyperlink_names[7]}"
fi

if [[ "$1" -le 8 ]]; then
    change_dir "${foldernames[8]}"
    printf "Attempting to build and install %s\n" "${hyperlink_names[8]}"
    {
        "$INSTALL_DIRECTORY"/bin/cython -I Include Src/MMTK_trajectory_action.pyx
        "$INSTALL_DIRECTORY"/bin/cython -I Include Src/MMTK_trajectory_generator.pyx
        export MMTK_USE_CYTHON=1
        "$INSTALL_DIRECTORY"/bin/python setup.py build_ext -I"$INSTALL_DIRECTORY"/include -L"$INSTALL_DIRECTORY"/lib
        "$INSTALL_DIRECTORY"/bin/python setup.py install
    } > "$LOG_DIRECTORY/${hyperlink_names[8]}log" 2>&1
    change_dir ..
    printf "%s successfully installed\n" "${hyperlink_names[8]}"
else
    printf "Assuming %s is already installed\n" "${hyperlink_names[8]}"
fi
printf "Everything is done and MMTK should work now!\n"



#this is only if you need fortran binaries for netCDF
if $NETCDF_FORTRAN; then
    if [[ "$1" -le 9 ]]; then
        change_dir "${foldernames[9]}"
        {
            export LD_LIBRARY_PATH="$INSTALL_DIRECTORY"/lib:"${LD_LIBRARY_PATH}"
            CPPFLAGS=-I"$INSTALL_DIRECTORY"/include LDFLAGS=-L"$INSTALL_DIRECTORY"/lib \
                ./configure  --disable-fortran-type-check --prefix="$INSTALL_DIRECTORY"
            make check
            make install
        } > "$LOG_DIRECTORY/${hyperlink_names[9]}log" 2>&1
        printf "%s successfully installed fortran version of\n" "${hyperlink_names[9]}"
            printf "%s successfully installed\n" "${hyperlink_names[9]}"
    else
        printf "Assuming %s is already installed\n" "${hyperlink_names[9]}"
    fi
    printf "Now Exiting the scipt\n"
fi

exit 0
