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
    sudo apt install -y vlc gimp dconf-tools compizconfig-settings-manager unity-tweak-tool gparted git ubuntu-restricted-extras

    # Google Chrome browser
    install_google_chrome

    # Make Linux ux less user-hostile
    sudo apt install -y gnome-sushi classicmenu-indicator
    gsettings set com.canonical.Unity always-show-menus true

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
    "firefox*"
    "xul-ext-ubufox*"
    "thunderbird*"
    "libreoffice-*"
    "mythes-en-us"
    "deja-dup*"
    "transmission-gtk"
    "totem"
    "shotwell"
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
    # chown -v "$SCRIPT_USER":"$SCRIPT_USER" "$TOOLROOT"

    # symlink default PTB install location to ~/MLtoolbox
    ln -v -s /usr/share/psychtoolbox-3 $TOOLROOT/Psychtoolbox # def PTB location hardcoded by neurodebian
    sudo chmod -R 775 $TOOLROOT/Psychtoolbox

    # git additional toolboxes
    cd $TOOLROOT
    # ------ Public repositories ------
	# PLDAPS
	git clone https://github.com/HukLab/PLDAPS.git

    # ------ Private repositories ------
    # huklabBasics
	git clone https://github.com/HukLab/huklabBasics.git
	# visbox (TBC Toolbox [et.al.] migrated from Dropbox)
	git clone https://github.com/czuba/visbox.git
	# misc system & pref files
	git clone https://github.com/czuba/riffraff.git
	# update local matlab startup.m
    mkdir -vpm 775 $HOME/Documents/MATLAB
	ln -vbs $TOOLROOT/riffraff/startup.m $HOME/Documents/MATLAB/startup.m


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
echo "system customization successful"
