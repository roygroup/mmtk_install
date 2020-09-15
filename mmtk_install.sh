#!/bin/bash

# Molecular Modeling Tool Kit installer
# version 0.5.0


# # # # # # # USER FAQ # # # # # # #
# HELLO USER!
# PLEASE CHOOSE A DIRECTORY WHERE MMTK WILL BE INSTALLED
INSTALL_DIRECTORY=$HOME/.mmtk
#
# - The script first checks which OS and architechture it is running on and provides any relevant information about software that is necessary later in the install
#
# - The script will create the following directories
# ./INSTALL_DIRECTORY
#   ./INSTALL_DIRECTORY/src
#   ./INSTALL_DIRECTORY/logs
#
# - It will begin downloading the necessary source files to the src directory
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
# adding the -j option seems to sometimes cause race issues and throw the following issues
# [Makefile:652: recipe for target 'check-recursive' failed]
# rerunning the script seems to always resolve this issue
#
# #


# the four arrays are ordered respectively
declare -a hyperlink_names  # the generic names of the packages we require
declare -a hyperlinks       # hyperlinks to the SPECIFIC version of that package we wish to download
declare -a filenames        # the name of the tar downloaded from the hyperlink
declare -a foldernames      # the default names of the folders containing the un-tar'ed files


hyperlink_names=( Python Cython zlib HDF5 c_netCDF NumPy SciPy FFTW MMTK fortran_netCDF )

# note we updated the Cython package from 0.20.1 to 0.23.1 and beyond becuase it is necessary to run Dmitri/Matt's MMTK version

hyperlinks=(
                https://www.python.org/ftp/python/2.7.15/Python-2.7.15.tgz # cannot support higher than 2.7.X
                https://github.com/cython/cython/archive/0.25.2.tar.gz
                http://zlib.net/zlib-1.2.11.tar.gz
                https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.10/hdf5-1.10.2/src/hdf5-1.10.2.tar.gz
                ftp://ftp.unidata.ucar.edu/pub/netcdf/netcdf-4.6.1.tar.gz
                http://sourceforge.net/projects/numpy/files/NumPy/1.8.2/numpy-1.8.2.tar.gz # cannot support higher than 1.8.x
                https://sourcesup.renater.fr/frs/download.php/file/4570/ScientificPython-2.9.4.tar.gz
                ftp://ftp.fftw.org/pub/fftw/fftw-3.3.6-pl1.tar.gz
                https://github.com/khinsen/MMTK/archive/path_integrals.tar.gz
                ftp://ftp.unidata.ucar.edu/pub/netcdf/netcdf-fortran-4.4.4.tar.gz
            )


arraylength=${#hyperlinks[@]} # the number of packages to download

# if we don't need to install fortran for netCDF then change arraylength
if [[ $NETCDF_FORTRAN = false ]]; then
    let "arraylength -= 1"
fi


# list of sharcnet / computecanada clusters
cluster_hostnames=(
                    "orc-login" # orca
                    "gra-login"
                    'cedar[0-9]'
                   )

#---------------------------------------------------------------------------------------------------------
#------------------------------------------- PREAMBLE ABOVE  ---------------------------------------------
#---------------------------------------------------------------------------------------------------------

#lang specific details
export LANG=C
export LC_ALL=C
set -e  # immediately stop the script if a simple command fails

# error codes
E_WRONGKERNEL=83    # wrong kernel
E_WRONGARCH=84      # wrong architecture
E_WRONGARS=85       # Arguments wrong error
E_XCD=86            # Can't change directory?
E_NOTROOT=87        # Non-root exit error
E_DOWNLOAD=88       # Failed to download necessary files
tar_error_string="Failed to untar: %s\nIs this hyperlink broken: %s\nIt is required that you can download all packages before the installer can run.\n"

#HTTP status codes
HTTP_NOT_FOUND=404
HTTP_OK=200

#FTP status codes
FTP_NOT_FOUND=550
FTP_OK=350


# keep all download options contained
function download() {
    # -s Silent or quiet mode. Don't show progress meter or error messages. Makes Curl mute.
    #    It will still output the data you ask for, potentially even to the terminal/stdout unless you redirect it.
    # -S When used with -s it makes curl show an error message if it fails.
    # -L Handles redirection, makes curl redo the request on the new location
    # -O Write output to a local file named like the remote file we get.
    # -I curl returns the servers HTTP headers, not the page data
    #
    # first we check the header to make sure the link is valid,
    RESPONSE_CODE=$(curl -s -o /dev/null -IL -w "%{http_code}" "${1}")

    if [[ RESPONSE_CODE -eq HTTP_OK ]] || [[ RESPONSE_CODE -eq FTP_OK ]]; then
        # the link is valid and we proceed with the download
        curl -s -SOL "${1}"
    elif [[ RESPONSE_CODE -eq HTTP_NOT_FOUND ]] || [[ RESPONSE_CODE -eq FTP_NOT_FOUND ]]; then
        # the link is invalid and we notify the user
        printf "Header code was invalid, please manually check the following hyperlink.\n%s\nIt is possible that the version number is out of date.\n" "${1}"
        exit ${E_DOWNLOAD}
    else
        # undefined result, notify user
        printf "Header code was ambigious, please check the validity of this url: \n%s\n" "${1}"
    fi
}


# let the user know if we failed to get to the correct directory, wrap cd in an "error checking function"
function change_dir()   {
    cd ${1} || {
        printf "Cannot change to directory: %s\n" "${1}"
        exit ${E_XCD};
    }
}


function check_if_sharcnet_or_compute_canada() {
    # check if you are running on computecanada or sharcnet cluster
    # if so we need to print out a message to the user
    hostname=$(hostname)
    for str in ${cluster_hostnames[@]}; do
        if [[ ${hostname} =~ ${str} ]]; then
            echo "It appears that you are running the install script on a login node of a SHARCNET or compute canada cluster.
    Please note that to install on these clusters is a two step process.
    First you need to run the script on the head node until the downloads are finished, then exit the script with Ctrl+D.
    Next you should execute the script in an interactive session, or as a job with sbatch.
    Do you understand?"
            DOWNLOAD_ONLY=true
            select yn in "Yes" "No"; do
                case $yn in
                    Yes ) break;;
                    No ) echo "Please contact someone in the group"; exit 0;;
                esac
            done
        fi
    done
}


function check_architecture()   {
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
}


function check_operating_system()   {
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
                10.13*)
                    GFORTAN_LINK=http://coudert.name/software/gfortran-6.3-Sierra.dmg           ;;
                10.12*)
                    GFORTAN_LINK=http://coudert.name/software/gfortran-6.3-Sierra.dmg           ;;
                10.11*)
                    GFORTAN_LINK=http://coudert.name/software/gfortran-6.1-ElCapitan.dmg        ;;
                10.10*) # (OS X 10.10)
                    GFORTAN_LINK=http://coudert.name/software/gfortran-5.2-Yosemite.dmg         ;;
                10.9*)
                    GFORTAN_LINK=http://coudert.name/software/gfortran-4.9.0-Mavericks.dmg      ;;
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
            set +e
            if [[ $MAC_VERSION == 1[0-9].1* ]]; then
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
            set -e
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
}


function check_gfortran()   {
    if [[ "$(command -v gfortran)" ]]; then
        printf "\nIt seems that you have gfortran, however, if the installer fails while trying to install FFTW it is most likely a gfortran issue\n\n"
        HAS_GFORTRAN=true
    else
        printf "\nYou do not have gfortran! You will not be able to compile FFTW.\n"
        printf "Please download and install gfortran from this link:\n%s\nNote that this requires administrative privilages!\n" "$GFORTAN_LINK"
        printf "If you have already installed an older version of gfortran please remove it with the following command:\n%s\n" \
        "sudo rm -r /usr/local/gfortran /usr/local/bin/gfortran"
        HAS_GFORTRAN=false
    fi
}


function make_directories()   {
    mkdir -p ${INSTALL_DIRECTORY}
    mkdir -p ${DOWNLOAD_DIRECTORY}
    mkdir -p ${LOG_DIRECTORY}
    printf "Succesfully made directories: \n%s\n%s\n%s\n\n" "${INSTALL_DIRECTORY}" "${DOWNLOAD_DIRECTORY}" "${LOG_DIRECTORY}"
}


function download_source_files()   {
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
}


# for readability
function exit_on_error() {
    echo "$1" >&3;
    exit 0;
}


# see the following stackoverflow post for the choice of -j9
# https://stackoverflow.com/questions/17743547/how-to-speed-up-compilation-time-in-linux/17749621#17749621
# also note the following possible issues from
# https://www.cmcrossroads.com/article/pitfalls-and-benefits-gnu-make-parallelization

# see the following post for why the dap-remote-tests are disabled
# https://www.unidata.ucar.edu/support/help/MailArchives/netcdf/msg13343.html

# actually maybe we want to disable the DAP completely

# the specific installation options
function install_function() {
    case "$1" in
        0) # python -- should consider adding the --enable-optimizations command to speed up python?
            # only try to install pip if we have openssl
            if $INSTALL_PIP_FLAG; then echo "Pip will be installed"; PIP_OPTION=yes; else echo "No pip installed"; PIP_OPTION=no; fi
            ./configure --prefix="$INSTALL_DIRECTORY" --enable-unicode=ucs4  --with-ensurepip=${PIP_OPTION} \
                || exit_on_error "Failed to configure python or install pip, check the logs"
            make clean  # if we are re-runing the script we should start fresh
            make -j9 || exit_on_error "Failed to make python, check the logs"
            make -j9 install || exit_on_error "Failed to install python, check the logs"
            ;;

        1) # cython
            ${PYTHON} setup.py clean --all install
            ;;
        2) # zlib
            ./configure --prefix="$INSTALL_DIRECTORY" || exit_on_error "Failed to configure zlib, check the logs"
            make clean  # if we are re-runing the script we should start fresh
            make -j9 || exit_on_error "Failed to make zlib, check the logs"
            make -j9 check install || exit_on_error "Failed to install zlib, check the logs"
            ;;
        3) # HDF5 - (no -j9 for FFTW since '[Makefile:683: install-recursive] Error 1' happens frequently enough)
            ./configure --with-zlib="$INSTALL_DIRECTORY" --prefix="$INSTALL_DIRECTORY" \
                || exit_on_error "Failed to configure HDF5, check the logs"
            make clean  # if we are re-runing the script we should start fresh
            make || exit_on_error "Failed to make HDF5, check the logs"
            make check install || exit_on_error "Failed to install HDF5, check the logs"
            ;;
        4) # netCDF - (no -j9 for FFTW since '[Makefile:683: install-recursive] Error 1' happens frequently)
            CPPFLAGS=-I"$INSTALL_DIRECTORY"/include LDFLAGS=-L"$INSTALL_DIRECTORY"/lib \
                ./configure --prefix="$INSTALL_DIRECTORY" --disable-dap   \
                || exit_on_error "Failed to configure netCDF, check the logs"
            make clean  # if we are re-runing the script we should start fresh
            make check install || exit_on_error "Possibly failed to install netCDF, check the logs - might have actually succeeded"
            ;;
        5) # Numpy
            ${PYTHON} setup.py install || exit_on_error "Failed to install Numpy, check the logs"
            ;;
        6) # Scipy
            export NETCDF_PREFIX="$INSTALL_DIRECTORY"
            ${PYTHON} setup.py clean --all install || exit_on_error "Failed to install Scipy, check the logs"
            ;;
        7) # FFTW - (no -j9 for FFTW since '[Makefile:683: install-recursive] Error 1' happens frequently)
            ./configure --prefix="$INSTALL_DIRECTORY" --enable-shared  || exit_on_error "Failed to configure FFTW, check the logs"
            make clean  # if we are re-runing the script we should start fresh
            make check install || exit_on_error "Failed to install FFTW, check the logs"
            ;;
        8) # MMTK
            ${CYTHON} -I Include Src/MMTK_trajectory_action.pyx
            ${CYTHON} -I Include Src/MMTK_trajectory_generator.pyx
            export MMTK_USE_CYTHON=1
            ${PYTHON} setup.py clean --all build_ext -I"$INSTALL_DIRECTORY"/include -L"$INSTALL_DIRECTORY"/lib \
                || exit_on_error "Failed to build_ext MMTK, check the logs"
            ${PYTHON} setup.py install || exit_on_error "Failed to install MMTK, check the logs"
            ;;
        9) # this is only if you need fortran binaries for netCDF
            export LD_LIBRARY_PATH="$INSTALL_DIRECTORY"/lib:"${LD_LIBRARY_PATH}"
            CPPFLAGS=-I"$INSTALL_DIRECTORY"/include LDFLAGS=-L"$INSTALL_DIRECTORY"/lib                             \
                ./configure --prefix="$INSTALL_DIRECTORY" --disable-fortran-type-check  --disable-dap-remote-tests \
                || exit_on_error "Failed to configure fortran binaries for netCDF, check the logs"
            make clean  # if we are re-runing the script we should start fresh
            make check install  || exit_on_error "Failed to install fortran binaries for netCDF, check the logs"
            ;;
        *)
            printf "Install loop did something weird, why is the counter ${1} greater than 9?\n"
            exit 0
            ;;
    esac
}


function install_programs()   {
    for (( i=0; i<${arraylength}; i++ )); do
        if [[ "$1" -le "$i" ]]; then
            change_dir "${foldernames[$i]}"
            printf "Attempting to build and install %s\n" "${hyperlink_names[$i]}"
            {
                install_function "$i"
            } > "$LOG_DIRECTORY/${hyperlink_names[$i]}log" 2>&1
            change_dir ..
            printf "%s successfully installed\n" "${hyperlink_names[$i]}"
        else
            printf "Assuming %s is already installed\n" "${hyperlink_names[$i]}"
        fi
    done
}

#---------------------------------------------------------------------------------------------------------
#--------------------------------------------- INSTALL MMTK  ---------------------------------------------
#---------------------------------------------------------------------------------------------------------

# Flags
INSTALL_PIP_FLAG=false # default is false - check_operating_system() will set to true if certain conditions are met
DOWNLOAD_ONLY=false # used when running on head nodes of computecanada or sharcnet

# the directories we will be installing to
DOWNLOAD_DIRECTORY="$INSTALL_DIRECTORY"/src
LOG_DIRECTORY="$INSTALL_DIRECTORY"/logs

# where the script is located
SCRIPT_FILE="${BASH_SOURCE[${#BASH_SOURCE[@]} - 1]}"
SCRIPT_DIR="$(dirname "${SCRIPT_FILE}")"

PYTHON="$INSTALL_DIRECTORY"/bin/python  # where python will be located
CYTHON="$INSTALL_DIRECTORY"/bin/cython  # where cython will be located

# the name of the log file
LOG_FILE="$SCRIPT_DIR"/logfile  # for now the current directory

# make sure the log file actually exists, and then redirect all stdout and stderr to the log file
touch "$LOG_FILE"

# see this post for explanation on how exec is working
# https://unix.stackexchange.com/questions/80988/how-to-stop-redirection-in-bash?utm_medium=organic&utm_source=google_rich_qa&utm_campaign=google_rich_qa
exec 3>&1 4>&2
# redirect all stdout and stderr to the log file
exec > >(tee "$LOG_FILE") 2>&1

# execute functions
check_architecture
check_operating_system
check_gfortran
make_directories
check_if_sharcnet_or_compute_canada

# move to the download directory to start downloading
change_dir "${DOWNLOAD_DIRECTORY}"
download_source_files

if [[ $DOWNLOAD_ONLY = true ]]; then
    printf "It appears we are on a head node, execution will stop here, you must run the script in an interactive session or submit the job to the queue using sbatch/qsub/srun.\n"
    exit
fi

# the magic
#---------------------------------------------------------------------------------------------------------
install_programs "$1"
#---------------------------------------------------------------------------------------------------------


printf "Everything is done and MMTK should work now!\n"
printf "Now Exiting the scipt\n"
exit 0
