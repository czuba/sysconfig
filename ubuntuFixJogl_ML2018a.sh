#!/bin/bash

# ubuntuFixJogl_ML2018a.sh
# For Ubuntu 16.04 LTS
# Fix jogl install & matlab links
#
# Script based on proposed solution from Andreas Widmann
# for issue reported in:
# https://groups.yahoo.com/neo/groups/PSYCHTOOLBOX/conversations/topics/22674
#
# 2018-02-09 TBCzuba 	wrote it.
# 2018-03-28 TBC	updated libjogl2-java repo, incl. backups before edits,
#			stripped out superf. PTB-3 install snippets

# verify that the computer is running a Debian derivative
if ! command -v dpkg &> /dev/null; then
    echo "this script is meant to be run on an Ubuntu system"
    exit 1
fi

cd $HOME

# global variables
MATLABROOT="/usr/local/MATLAB/R2018a";    # e.g. "/usr/local/MATLAB/R2017b"

echo "You are logged in as user:  $USER"
echo "Matlab installation path:  $MATLABROOT"
echo ""

% Make sure matlabroot dir exists
if [ ! -d "$MATLABROOT" ]; then
    printf "
    ###################
    #
    # Manually edit the \$MATLABROOT path variable in this script
    # for each Matlab installation.
    #
    # To determine appropriate path, fire up Matlab, then enter
    #       matlabroot
    # in the command window.
    #
    #  ...aborting
    ###################

"
    exit 1
fi


# Fix jogl errors in Matlab (as of Apr, 2018)
###################
# (1)
# XENIAL-PROPOSED repository no longer needed (updates accepted into xenial-updates as of Mar. 2018)
THISPKG='libjogl2-java'
if [ $(dpkg-query -W -f='${Status}' $THISPKG 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
	echo "# $THISPKG fix already installed."
else
	echo -e "# Attempting to install $THISPKG package"
	sudo apt update -y
	sudo apt install -y $THISPKG
fi


###################
# (2)
echo "# Applying edits to <matlab>/toolbox/local files..."
# Change the classpath.txt and librarypath.txt files in $MATLABROOT/toolbox/local.
#
cd $MATLABROOT/toolbox/local
# In classpath.txt, replace the following two lines (~line 450):
# $matlabroot/java/jarext/gluegen-rt.jar
# $matlabroot/java/jarext/jogl-all.jar
# with:
# /usr/share/java/jogl2.jar
# /usr/share/java/gluegen2-rt.jar
#
sudo cp -v --backup=numbered classpath.txt classpath.txt.bak
sudo chmod 777 classpath.txt

RE='\$matlabroot\/java\/jarext\/gluegen-rt\.jar';
SUBST='\/usr\/share\/java\/gluegen2-rt\.jar';
sudo sed -i -e 's/'"$RE"'/'"$SUBST"'/1' 'classpath.txt';

RE='\$matlabroot\/java\/jarext\/jogl-all.jar';
SUBST='\/usr\/share\/java\/jogl2\.jar';
sudo sed -i -e 's/'"$RE"'/'"$SUBST"'/1' 'classpath.txt';

# In librarypath.txt add at the end of the file (incl. a newline):
# /usr/lib/jni
#
if [ ! -f ./librarypath.txt.bak ]; then
	sudo cp -v --backup=numbered librarypath.txt librarypath.txt.bak
	sudo chmod 777 librarypath.txt
	echo "/usr/lib/jni" >> librarypath.txt
else
	echo "# Matlab librarypath.txt already appears modified (.bak exists)"
fi


###################
# (3)
# To be sure that the MATLAB included libraries do not interfere,
# rename the following libraries in matlabroot/bin/glnxa64:
# libjogl_desktop.so
# libgluegen-rt.so
# libnativewindow_awt.so
# libnativewindow_X11.so
#
# Then, in matlabroot/toolbox/local/classpath rename:
# 3p_jogl.jcp
# to be shure it is not added back to classpath in case it is regenerated.
#
cd $MATLABROOT/bin/glnxa64
if [ ! -f ./libjogl_desktop.so.bak ]; then
	sudo mv -v ./libjogl_desktop.so ./libjogl_desktop.so.bak
	sudo mv -v ./libgluegen-rt.so ./libgluegen-rt.so.bak
	sudo mv -v ./libnativewindow_awt.so ./libnativewindow_awt.so.bak
	sudo mv -v ./libnativewindow_x11.so ./libnativewindow_x11.so.bak

	cd $MATLABROOT/toolbox/local/classpath
	sudo mv -v ./3p_jogl.jcp ./3p_jogl.jcp.bak
else
	echo "# Matlab builtin libs [seemingly] already disabled (.bak exists)"
fi


###################
# (4) Done.

printf "
###################
#   Matlab jogl error fix complete
###################

"

