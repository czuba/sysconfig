#!/bin/bash

# setup_Ubuntu1604_pldaps.sh
# configure an Ubuntu 16.04 LTS desktop for PLDAPS usage
#
# Based on mashup/extensions of:
#       https://gist.github.com/ankurk91/0bb73c8ccf79b504c6c1
#       and
#       https://github.com/paraschas/ubuntu-setup


# verify that the computer is running a Debian derivative
if ! command -v dpkg &> /dev/null; then
    echo "this script is meant to be run on an Ubuntu system"
    exit 1
fi

cd $HOME

# global variables
SCRIPT_USER=$USER
TOOLROOT="/home/$SCRIPT_USER/MLtoolbox"
echo "you are logged in as user $SCRIPT_USER"
echo "matlab toolboxes will be installed in $TOOLROOT"

if [ "$SCRIPT_USER" == "root" ]; then
    echo ""
    echo "This script should not be run as root ('sudo-ed')"
    echo "Please run directly as the principal user[name] of this machine"
    exit 1
fi


yes_no_question() {
    while true; do
        read -e -p "$1 (y/n): " YES_NO_ANSWER
        case $YES_NO_ANSWER in
            [y]* )
                break
                ;;
            [n]* )
                break
                ;;
            * )
                echo "please enter \"y\" for yes or \"n\" for no"
                ;;
        esac
    done

    if [ "$YES_NO_ANSWER" == "y" ]; then
        return 1
    else
        return 0
    fi
}


# append the suffix ".backup" and the datetime to a directory or file name
backup_datetime() {
    TARGET="$1"
    DATE_TIME=$(date +%Y-%m-%d_%H:%M:%S)
    if [ -d "$TARGET" ] || [ -f "$TARGET" ]; then
        if [ ! -L "$TARGET" ]; then
            mv -i -v "$TARGET" "$TARGET"\.backup\."$DATE_TIME"
        fi
    fi
}


# run all apt updates?
yes_no_question "Do you want to update and upgrade the system?"
if [ $? -eq 1 ]; then
    sudo apt update && sudo apt -y upgrade && sudo apt dist-upgrade
fi


remove_packages() {
    # Remove offending package (per IT desk)
    sudo apt purge -y avahi-daemon
}


install_standard_packages() {
    # Basic packages
    sudo apt install -y git meld ubuntu-restricted-extras vlc gimp dconf-tools compizconfig-settings-manager unity-tweak-tool gparted exfat-utils exfat-fuse libjogl2-java freeglut3 libusb-1.0
    
    # ...possibly sketchy wildcards here to deal with esoteric versioned package names
    sudo apt install -y libdc1394* libraw1394*

    # Google Chrome browser
    install_google_chrome

    # Make Ubuntu ux less user-hostile
    sudo apt install -y gnome-sushi
    gsettings set com.canonical.Unity always-show-menus true
    gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view'
    gsettings set org.gnome.nautilus.list-view default-zoom-level 'smaller'
    gsettings set org.gnome.nautilus.list-view use-tree-view true
    gsettings set org.gnome.nautilus.desktop home-icon-visible true
    gsettings set org.gnome.nautilus.desktop volumes-visible true


    # Colorize git diff output      # https://github.com/so-fancy/diff-so-fancy
    wget -O $HOME/.local/share/applications/gitdiffcolors "https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy"
    git config --global core.pager "gitdiffcolors | less --tabs=4 -RFX"
    # additional git color configs
    git config --global color.ui true
    git config --global color.diff-highlight.oldNormal    "red bold"
    git config --global color.diff-highlight.oldHighlight "red bold 52"
    git config --global color.diff-highlight.newNormal    "green bold"
    git config --global color.diff-highlight.newHighlight "green bold 22"
    git config --global color.diff.meta       "yellow"
    git config --global color.diff.frag       "magenta bold"
    git config --global color.diff.commit     "yellow bold"
    git config --global color.diff.old        "red bold"
    git config --global color.diff.new        "green bold"
    git config --global color.diff.whitespace "red reverse"
}


install_google_chrome() {
    wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
    sudo sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list'
    sudo apt update
    sudo apt install -y google-chrome-stable
}


# run basic machine setup?
yes_no_question "Do you want to setup a selection of packages?"
if [ $? -eq 1 ]; then
    remove_packages

    install_standard_packages
fi


remove_bloat_packages() {
    # List of apps to remove
    declare -a APPS=(
    "xul-ext-ubufox*"
    "thunderbird*"
    "libreoffice-*"
    "mythes-en-us"
    "deja-dup*"
    "transmission-gtk"
    "totem"
    "example-content"
    "gnome-calendar"
    "gnome-sudoku"
    "gnome-mahjongg"
    "aisleriot"
    "gnome-mines"
    )

    ## Loop through the above array
    for i in "${APPS[@]}"
    do
    echo -e "\e[96m    X--> Uninstalling: $i  \e[39m"
    sudo apt purge -y $i
    done

    # Clean up
    sudo apt -y autoremove
    sudo apt -y clean

    # Remove amazon app from dash, we can't remove the package
    sudo rm -rf /usr/share/applications/ubuntu-amazon-default.desktop
    sudo rm -rf /usr/share/applications/ubuntu-software.desktop
    
    # Reveal all system startup apps (recommend disable Backup Monitor & Desktop Sharing if unused)
    sudo sed -i 's/NoDisplay=true/NoDisplay=false/g' /etc/xdg/autostart/*.desktop

	# Disable cups print service
	sudo systemctl disable cupsd.service
	sudo systemctl disable cups-browsed.service
	
	# "evolution-data-server" is bloaty, but cannot remove w/o breaking basic gnome functions
	# Prevent evolution bloat from running by renaming dirs
	sudo mv /usr/lib/evolution-data-server /usr/lib/evolution-data-server-disabled
	sudo mv /usr/lib/evolution /usr/lib/evolution-disabled

}


# Remove bloatware?
yes_no_question "Do you want to remove bloatware (incl. firefox et al.)?"
if [ $? -eq 1 ]; then
remove_bloat_packages
fi


# configuration
################################################################################
    # Add repositories for Psychtoolbox-3 installation (via NeuroDebian)
    #   - copy-pasta from 'all software' repository for Ubuntu 16.04
    #   - for different OS options see: http://neuro.debian.net/install_pkg.html?p=matlab-psychtoolbox-3-nonfree
    wget -O- http://neuro.debian.net/lists/xenial.us-nh.full | sudo tee /etc/apt/sources.list.d/neurodebian.sources.list
    sudo apt-key adv --recv-keys --keyserver hkp://pool.sks-keyservers.net:80 0xA5D32F012649A5A9
    sudo apt update

    # Install psychtoolbox
    sudo apt install -y matlab-psychtoolbox-3-nonfree

    # Add directories for Matlab toolboxes
    mkdir -v -m 775 "$TOOLROOT"
    ln -vs $TOOLROOT $HOME/Desktop
    # chown -v "$SCRIPT_USER":"$SCRIPT_USER" "$TOOLROOT"

    # symlink default PTB install location to ~/MLtoolbox
    ln -vs /usr/share/psychtoolbox-3 $TOOLROOT/Psychtoolbox # def PTB location hardcoded by neurodebian
    sudo chmod -R 777 $TOOLROOT/Psychtoolbox

    # git additional toolboxes
    cd $TOOLROOT

    # ------ Public repositories ------
	# PLDAPS
	git clone -b glDraw https://github.com/HukLab/PLDAPS.git

	# Eyelink toolbox libraries (ver. 1.11; Spring 2018)
	wget -O - "http://download.sr-support.com/software/dists/SRResearch/SRResearch_key" | sudo apt-key add -
	sudo add-apt-repository "deb http://download.sr-support.com/software SRResearch main"
	sudo apt update
	sudo apt install -y eyelink-display-software


# Create PLDAPS data directories?
create_data_directory() {
    sudo mkdir -v /Data
    sudo chown -v $SCRIPT_USER:$SCRIPT_USER /Data
    sudo mkdir -v /Data/TEMP
    sudo chown -v $SCRIPT_USER:$SCRIPT_USER /Data/TEMP
}

yes_no_question "Do you want to create the /Data directory for PLDAPS?"
if [ $? -eq 1 ]; then
    create_data_directory
fi

################################################################################

echo ""
echo "system customization complete"

printf "

::: Next Steps :::

1)
Install Matlab in default location: /usr/local/MATLAB/R20##x

2)
Patch persistent Matlab issues on Linux:
2.1)
Install matlab-support package
- Terminal:
    apt search matlab-support
- *** As of 2018-03, matlab-support package incompatible with Ubuntu 16.04 & Matlab 2018a(+).
    - Resulted in startup errors about gcc version something something;
    had to manually undo lib edits it applied.
2.2)
As of Spring 2018, must patch broken Matlab/jogl errors (2016b, 2017b, 2018a, et al.)
...luckily, I wrote a script for that too:
    ubuntuFixJogl_ML2018a.sh

3)
Setup Matlab & Psychtoolbox
3.1)
Open matlab & run:  ~/MLtoolbox/Psychtoolbox/PsychLinuxConfiguration.m
3.2)
Setup xorg config(s) for your experimental rig with:
    Psychtoolbox/PsychHardware/XOrgConfCreator.m
    Psychtoolbox/PsychHardware/XOrgConfSelector.m

4)
Configure Eyelink network connection
    - Note: this prob won't stick across reboots, but should get you started
- Connect with ethernet cable
- Terminal:
    ip link
    - Will list info/state of ethernet ports, use trial & error to determine
    which one corresponds to the eyelink
    - Needed identifier should be something like 'enp3s0'
- Terminal:
    sudo ip link set enp3s0 up
    sudo ip addr add 100.1.1.2/24 dev enp3s0
    - (...obviously, if your enxXXX is different, use that)
- Terminal:
    ping 100.1.1.2
    - This should start listing successful pings to the eyelink connection,
    ctrl-c to stop it. Find someone to hi-five. You're done.

5)
...surely there's more...

---------------
TBC 2018-03-27
---------------

"



