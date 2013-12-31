#!/usr/bin/bash - 
#===============================================================================
#
#          FILE: idrive-wrapper.sh
# 
#         USAGE: ./idrive-wrapper.sh 
# 
#   DESCRIPTION: Utility to backup local data to IDrive's cloud backup
# 
#        AUTHOR: Nitin Mathew, nitn.mathew2000@hotmail.com
#       CREATED: 30/12/2013 21:19
#     COPYRIGHT: Copyright for IDrive's utility idevsutil is with IDrive, http://evs.idrive.com/terms-of-service.htm
#		 Copyright for rest of the script Nitin Mathew, 2013
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#===============================================================================

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  read_config_init
#   DESCRIPTION:  Read the config file and initialize the variables
#    PARAMETERS:  na
#       RETURNS:  na
#-------------------------------------------------------------------------------
read_config_init(){
	#initial params
	CONFIG=~/.config/.idrivewrc
	HELPFILE=TODO
	WORKDIR=`mktemp -d`
	
	#If config file doesn exist then exit
	if  [ ! -s "${CONFIG}" ]; then
		echo "ERROR: Config file, ${CONFIG} does not exist. Exiting"
		clean_up_exit 1
	fi
	
	echo "INFO: Using config file '${CONFIG}'"
	#Populate the params from config file
	USERID=`grep 'UNAME'  "${CONFIG}" | cut -d'=' -f 2`
	echo "INFO: User ID is '${USERID}'"
	DESTFOLDER=`grep 'IDRIVE_HOME_FOLDER'  "${CONFIG}" | cut -d'=' -f 2`
	echo "INFO: Parent folder in IDrive is '${DESTFOLDER}'"
	FILELIST_UPLOAD=${WORKDIR}/${USERID}_UPLOAD
	FILELIST_DELETE=${WORKDIR}/${USERID}-DELETE
	grep 'UPLOAD_LIST' "${CONFIG}" | cut -d'=' -f 2 | tr ';' '\n' | while read PTH; do
		echo "${PTH}" >> ${FILELIST_UPLOAD}
	done
	PTH=""
	grep 'DELETE_LIST' "${CONFIG}" | cut -d'=' -f 2 | tr ';' '\n' | while read PTH; do
		echo "${PTH}" >> ${FILELIST_DELETE}
	done
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  process_options
#   DESCRIPTION:  Process the command line options
#    PARAMETERS:  na
#       RETURNS:  na
#-------------------------------------------------------------------------------
process_options(){
	echo $#
	if [ $# -lt 2 ] ; then
		show_help 1
		clean_up_exit 1
	fi
	ARGS=`getopt -q -o udg:l:v:p:shGLVP -- $@`
	if [ $? != 0 ]
	then
		show_help 1
		clean_up_exit 1
	fi
	eval set -- "${ARGS}"
	while [ $1 != -- ]
	do
		case $1 in 
			-u)	u_FLG=1 #Upload
				shift;;
			-d)	d_FLG=1 #Delete
				shift;;
			-g)	g_FLG=1 #Get/Download with file/folder
				g_ARG=$2
				shift;;
			-l)	l_FLG=1 #List file/folder
				l_ARG=$2
				shift
				shift;;
			-v)	v_FLG=1 #Version info for file/folder
				v_ARG=$2
				shift
				shift;;
			-p)	p_FLG=1 #File properties for file/folder
				p_ARG=$2
				shift
				shift;;
			-s)	s_FLG=1 #Space Usage
				shift;;
			-h)	h_FLG=1 #Help
				break;;
			-G)	G_FLG=1 #Get from parent,  similar to 'g' but no args
				break;;
			-L)	L_FLG=1 #List parent, similar to 'l' but no args
				break;;
			-P)	P_FLG=1 #Property info for parent, similar to 'p' but no args
				break;;
			*)	echo "Unrecognized option $1"
				show_help 1
				clean_up_exit 1
		esac
	done
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  call_commands
#   DESCRIPTION:  This function will call the required functions based on user options from command line
#    PARAMETERS:  na
#       RETURNS:  na
#-------------------------------------------------------------------------------
call_commands(){
	
	if [ ${h_FLG:-0} -eq 1 ] ; then
		echo "Help"
		show_help 2
		clean_up_exit 0
	fi
	if [ ${u_FLG:-0} -eq 1 ] ; then
		echo "Upload"
	fi
	if [ ${d_FLG:-0} -eq 1 ] ; then
		echo "Delete"
	fi
	if [ ${g_FLG:-0} -eq 1 ] ; then
		echo "Get with Arg"
		echo "Arg: ${g_ARG}"
	fi
	if [ ${G_FLG:-0} -eq 1 ] ; then
		echo "Get No Arg"
	fi
	if [ ${l_FLG:-0} -eq 1 ] ; then
		echo "List with Arg"
		echo "Arg: ${l_ARG}"
	fi
	if [ ${L_FLG:-0} -eq 1 ] ; then
		echo "List No Arg"
	fi
	if [ ${v_FLG:-0} -eq 1 ] ; then
		echo "Version with Arg"
		echo "Arg: ${v_ARG}"
	fi
	if [ ${p_FLG:-0} -eq 1 ] ; then
		echo "Properties with Arg"
		echo "Arg: ${p_ARG}"
	fi
	if [ ${P_FLG:-0} -eq 1 ] ; then
		echo "Properties No Arg"
	fi	
	if [ ${s_FLG:-0} -eq 1 ] ; then
		echo "Space Usage"
	fi
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  clean_up_exit
#   DESCRIPTION:  Perform any needed cleanup and exit
#    PARAMETERS:  Exit status to be returned
#       RETURNS:  Exit status to shell
#-------------------------------------------------------------------------------
clean_up_exit(){
	rm -fr ${WORKDIR}
	exit $1
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  show_help
#   DESCRIPTION:  Show the help function onto STDOUT
#    PARAMETERS:  1-Brief help for options, 2-Detailed help by reading from help file
#       RETURNS:  na
#-------------------------------------------------------------------------------
show_help(){
	
	if [ $1 -eq 1 ] ; then
		echo "idrive-wrapper usage as below:"
		#TODO Print out brief help here for options
	elif [ $1 -eq 2 ] ; then
		echo "Help 2"
		#TODO cat the help file from ${HELPFILE}
	fi
}

#Start Here
#Process the command line options
process_options $# $*

#Read the config file and assign params and populate file lists
echo "IDrive backup wrapper script started."
echo $(date +"%Y-%b-%d, %H:%M:%S")          # generate timestamp : YYYYMMDD-hhmmss
read_config_init
call_commands
clean_up_exit 0

