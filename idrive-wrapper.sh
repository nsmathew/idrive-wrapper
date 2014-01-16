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
#     COPYRIGHT: Copyright for IDrive's utility idevsutil is with IDrive, 
#		 http://evs.idrive.com/terms-of-service.htm
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

##MAIN FLOW FUNCTIONS##

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  init_script
#   DESCRIPTION:  Initialize the main variables which are not read from the 
#		  config file.
#    PARAMETERS: na
#       RETURNS: na
#-------------------------------------------------------------------------------
init_script(){
	#initial params
	TIMESTMP=$(date +"%Y%m%d-%H%M%S-%N") # generate timestamp : YYYYMMDD-hhmmss
	CONFIG=~/.config/.idrivewrc #Config file
	WORKDIR=`mktemp -d` #Temp working directory
	IDRIVEWRAPPER_VER="idrive-wrapper v1.2"
	TIMESTMP_CMD="date +%d-%m-%Y\|%T\|%Z"
	if [ ! -s "/usr/share/doc/idrive-wrapper/idrive-wrapper_manual.txt" ] ; then
		if [ ! -s "./idrive-wrapper_manual.txt" ] ; then
			HELPFILE="NA"
		else
			HELPFILE="./idrive-wrapper_manual.txt"
		fi
	else
		HELPFILE="/usr/share/doc/idrive-wrapper/idrive-wrapper_manual.txt"
	fi

	#Check for required external commands
	type more &>/dev/null
	if [ $? -eq 0 ] ; then
		C_more_AVAILABLE=1
	fi
	type getfacl &>/dev/null
	if [ $? -eq 0 ] ; then
		C_getfacl_AVAILABLE=1
	fi
	type bc &>/dev/null
	if [ $? -eq 0 ] ; then
		C_bc_AVAILABLE=1
	fi
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  process_options
#   DESCRIPTION:  Process the command line options
#    PARAMETERS:  Cmd Line Arg Count, Cmd Line Args
#       RETURNS:  na
#-------------------------------------------------------------------------------
process_options(){
	if [ $# -lt 2 ] ; then
		show_help 1
		clean_up_exit 1
	fi
	ARGS=`getopt  -o udg:l:V:p:shG:LU:D:vP:o: -- $@`
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
				shift
				shift;;
			-l)	l_FLG=1 #List file/folder
				l_ARG=$2
				shift
				shift;;
			-V)	V_FLG=1 #Version info for file/folder
				V_ARG=$2
				shift
				shift;;
			-p)	p_FLG=1 #File properties for file/folder
				p_ARG=$2
				shift
				shift;;
			-s)	s_FLG=1 #Space Usage
				shift;;
			-h)	show_help 2 #Help
				clean_up_exit 0;; #If help is a option then just display help and exit
			-G)	G_FLG=1 #Download location for files/folders,should be used only with 'g' option.
				G_ARG=$2
				shift
				shift;;
			-L)	L_FLG=1 #List IDrive Home Folder, similar to 'l' but no args
				shift;;
			-v)	show_version #Display version
				clean_up_exit 0;; # Dont do anything further
			-U)	U_FLG=1 #Upload using command line files/folders
				U_ARG=$2
				shift
				shift;;
			-D)	D_FLG=1 #Delete based on command line files/folders
				D_ARG=$2
				shift
				shift;;
			-P)	P_FLG=1 #IDrive Parent folder
				P_ARG=$2
				shift
				shift;;
			-o)	o_FLG=1 #Log file
				o_ARG=$2
				shift
				shift;;
		esac
	done
	#If a non-option argument is given then assign it as the user ID.
	if [ ! "$3" = "" ] ; then 
		USERID_CMDLINE=$3
	fi

	#If log file given then assign the same as the log file else use /dev/null as argument for tee
	if [ ${o_FLG:-0} -eq 1 ] ; then
		if [ ! -f "${o_ARG}" ] ; then
			touch "${o_ARG}" &>/dev/null
		fi
		if [ ! -w "${o_ARG}" ] ; then
			echo "ERROR:`eval ${TIMESTMP_CMD}`: Cannot write log to ${o_ARG}."
			LOG_FILE=/dev/null
		else
			LOG_FILE="${o_ARG}"
		fi
	else
		LOG_FILE=/dev/null
	fi
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  read_config
#   DESCRIPTION:  Read the config file and initialize the variables.
#		  Any overrides based on command line values are done here as well.
#    PARAMETERS:  na
#       RETURNS:  na
#-------------------------------------------------------------------------------
read_config(){
	#Config keys
	c_username="UNAME"
	c_uploadlist="UPLOAD_LIST"
	c_deletelist="DELETE_LIST"
	c_idrivehome="IDRIVE_HOME_FOLDER"
	c_aclbackup="ACL_BACKUP"
	c_logfile="LOG_FILE"
	
	#If config file doesn exist then exit
	if  [ ! -s "${CONFIG}" ]; then
		echo "ERROR:`eval ${TIMESTMP_CMD}`: Config file, ${CONFIG} does not exist. Exitingp" | tee -a "${LOG_FILE}"
		clean_up_exit 1
	fi
	
	echo "INFO:`eval ${TIMESTMP_CMD}`: Using config file '${CONFIG}'" | tee -a "${LOG_FILE}"
	#Populate the params from config file
	#USERID
	#If no user ID given in command line then read from config file
	if [ "${USERID_CMDLINE}" = "" ] ; then
		USERID=`grep "${c_username}"  "${CONFIG}" | cut -d'=' -f 2 -s`
		if [ "${USERID}" = "" ] ; then
			echo "ERROR:`eval ${TIMESTMP_CMD}`: No user in command line nor config file. Exiting Program." | tee -a "${LOG_FILE}"
			clean_up_exit 1
		fi
	else
		USERID="${USERID_CMDLINE}"
	fi
	tmp1=/dev/null
	echo "INFO:`eval ${TIMESTMP_CMD}`: User ID is '${USERID}'" | tee -a "${LOG_FILE}"
	#IDRIVEFOLDER
	#If -P option is given then use the command line parent folder else check available in the config file. 
	#If not in config file then use IDrive root
	if [ "${P_FLG:-0}" -eq 1 ] ; then
		DESTFOLDER="${P_ARG}"
	else
		DESTFOLDER=`grep "${c_idrivehome}" "${CONFIG}" | cut -d'=' -f 2 -s`
		if [  "${DESTFOLDER}" = "" ] ;  then
			DESTFOLDER="/"
		fi
	fi
	echo "INFO:`eval ${TIMESTMP_CMD}`: Parent folder in IDrive for upload is '${DESTFOLDER}'" | tee -a "${LOG_FILE}"
	#UPLOAD/DELETE FILEISTS
	FILELIST_UPLOAD=${WORKDIR}/"${USERID}"_UPLOAD
	FILELIST_DELETE=${WORKDIR}/"${USERID}"-DELETE
	PTH=""
	grep "${c_uploadlist}" "${CONFIG}" | cut -d'=' -f 2 -s  | tr ',' '\n' | while read PTH; do
		if [ "${PTH}" = "" ] ; then
			continue	
		fi
		echo "${PTH}" >> ${FILELIST_UPLOAD}
	done
	PTH=""
	grep "${c_deletelist}" "${CONFIG}" | cut -d'=' -f 2 | tr ',' '\n' | while read PTH; do
		if [ "${PTH}" = "" ] ; then
			continue	
		fi
		echo "${PTH}" >> ${FILELIST_DELETE}
	done
	#ACL BACKUP PATH
	ACL_BACKUP=`grep "${c_aclbackup}"  "${CONFIG}" | cut -d'=' -f 2 -s`
	
	echo "INFO:`eval ${TIMESTMP_CMD}`: Log file is ${LOG_FILE}" | tee -a "${LOG_FILE}" 

}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  call_commands
#   DESCRIPTION:  This function will call the required functions based on user 
#		  options from command line
#    PARAMETERS:  na
#       RETURNS:  na
#-------------------------------------------------------------------------------
call_commands(){
	if [ ${u_FLG:-0} -eq 1 ] ; then #Upload option
		upload
	fi
	if [ ${U_FLG:-0} -eq 1 ] ; then #upload using paths from command line
		upload
	fi
	if [ ${d_FLG:-0} -eq 1 ] ; then #Delete option
		delete
	fi
	if [ ${D_FLG:-0} -eq 1 ] ; then #Delete using paths from command line
		delete
	fi
	#-g can be run without -G. But -G needs -g to be specified, hence else if used.
	if [ ${g_FLG:-0} -eq 1 ] ; then #Download based on specified path, download to location depends on -G
		download
	elif [ ${G_FLG:-0} -eq 1 ] ; then #Download location, will be used only if -g is passed
		echo "ERROR:`eval ${TIMESTMP_CMD}`: No source files/folders provided with -g. Nothing will be downloaded." | tee -a "${LOG_FILE}"
	fi
	if [ ${l_FLG:-0} -eq 1 ] || [ ${L_FLG:-0} -eq 1 ] ; then #For -l, search or list based on user input, 
		list_or_search                             #for -L list the contents from the root folder in IDRIVE
	fi
	if [ ${V_FLG:-0} -eq 1 ] ; then
		versioning_details
	fi
	if [ ${p_FLG:-0} -eq 1 ] ; then
		file_properties
	fi
	if [ ${s_FLG:-0} -eq 1 ] ; then
		space_usage
	fi
}

##COMMAND FUNCTIONS##
#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  upload
#   DESCRIPTION:  Upload files/folders to IDrive based on config file or the
#		  the list given in command line
#    PARAMETERS:  na
#       RETURNS:  na
#-------------------------------------------------------------------------------
upload(){
	if [ ${u_FLG:-0} -eq 1 ] ; then
		if [ ! -s "${FILELIST_UPLOAD}" ] ; then
			echo "No file/folder list available. Nothing will be uploaded." | tee -a "${LOG_FILE}"
			return
		fi
		upload_file="${FILELIST_UPLOAD}"
		u_FLG=""
	elif [ ${U_FLG:-0} -eq 1 ] ; then
		upload_file=${WORKDIR}/"${USERID}"_UPLOAD_CMDLINE
		PTH=""
		echo "${U_ARG}" | tr ',' '\n' | while read PTH; do
			if [ "${PTH}" = "" ] ; then
				continue	
			fi
			echo "${PTH}" >> "${upload_file}"
		done
		U_FLG=""
	fi
	
	#Perform ACL backup if requested first and then upload
	backup_ACL "${upload_file}"

	echo "INFO:`eval ${TIMESTMP_CMD}`: File/folder list for upload is as below..." | tee -a "${LOG_FILE}"
	cat "${upload_file}"
	echo "INFO:`eval ${TIMESTMP_CMD}`: Starting backup..." | tee -a "${LOG_FILE}"
	idevsutil --xml-output --password-file="${PASSWD}" --files-from="${upload_file}" / "${USERID}"@"${SERVER}"::home/"${DESTFOLDER}" 2>&1 | tee -a "${LOG_FILE}"
	echo "INFO:`eval ${TIMESTMP_CMD}`: Upload is complete, check log for any errors." | tee -a "${LOG_FILE}"
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  delete
#   DESCRIPTION:  Delete files/folder to IDrive based on config file or the 
#		  list given in the command line
#    PARAMETERS:  na
#       RETURNS:  na
#-------------------------------------------------------------------------------
delete(){
	if [ ${d_FLG:-0} -eq 1 ] ; then
		if [ ! -s "${FILELIST_DELETE}" ] ; then
			echo "No file/folder list available. Nothing will be deleted." | tee -a "${LOG_FILE}"
			return
		fi
		delete_file="${FILELIST_DELETE}"
		d_FLG=""
	elif [ ${D_FLG:-0} -eq 1 ] ; then
		delete_file=${WORKDIR}/"${USERID}"_DELETE_CMDLINE
		PTH=""
		echo "${D_ARG}" | tr ',' '\n' | while read PTH; do
			if [ "${PTH}" = "" ] ; then
				continue	
			fi
			echo "${PTH}" >> "${delete_file}"
		done
		D_FLG=""
	fi
	echo "INFO:`eval ${TIMESTMP_CMD}`: File/folder list for deletion is as below..." | tee -a "${LOG_FILE}"
	cat "${delete_file}"
	echo "INFO:`eval ${TIMESTMP_CMD}`: Starting file deletion..." | tee -a "${LOG_FILE}"
	idevsutil --xml-output --password-file="${PASSWD}" --delete-items --files-from="${delete_file}" "${USERID}"@"${SERVER}"::home/ 2>&1 | tee -a "${LOG_FILE}"
	echo "INFO:`eval ${TIMESTMP_CMD}`: File deletion is complete, check log for any errors." | tee -a "${LOG_FILE}"
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  download
#   DESCRIPTION:  Download a file based on specified path as argument
#    PARAMETERS:  na
#       RETURNS:  na
#-------------------------------------------------------------------------------
download(){
	filelist_download="${WORKDIR}"/"${USERID}"_DOWNLOAD
	#Create a temp file with the paths provided in command line
	PTH=""
	echo "${g_ARG}" | tr ',' '\n' | while read PTH; do
		if [ "${PTH}" = "" ] ; then
			continue	
		fi
		echo "${PTH}" >> ${filelist_download}
	done
	#If -G is set then use that as download location if valid else use /tmp/idrive-downloads/
	if [ ${G_FLG} -ne 1 ] || [ ! -d "${G_ARG}" ] ; then
		mkdir -p /tmp/idrive-downloads/
		download_location="/tmp/idrive-downloads/"
		echo "INFO:`eval ${TIMESTMP_CMD}`: No valid download location specified, using ${download_location}" | tee -a "${LOG_FILE}"
	else
		download_location="${G_ARG}"
		echo "INFO:`eval ${TIMESTMP_CMD}`: Files will be downloaded to ${download_location}" | tee -a "${LOG_FILE}"
	fi
	echo "INFO:`eval ${TIMESTMP_CMD}`: Download list is..." | tee -a "${LOG_FILE}"
	cat ${filelist_download}
	echo "INFO:`eval ${TIMESTMP_CMD}`: Starting download..." | tee -a "${LOG_FILE}"
	idevsutil --xml-output --password-file="${PASSWD}" --files-from="${filelist_download}" "${USERID}"@"${SERVER}"::home/ "${download_location}" 2>&1  | tee -a "${LOG_FILE}"
	echo "INFO:`eval ${TIMESTMP_CMD}`: Download complete. Check logs for errors." | tee -a "${LOG_FILE}"
	echo "INFO:`eval ${TIMESTMP_CMD}`: If ACLs were backed up, file permissions/owner/group can be restored using the setfacl command." | tee -a "${LOG_FILE}"
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  space_usage
#   DESCRIPTION:  Gets the space usage and file count from IDrive
#    PARAMETERS:  na
#       RETURNS:  na
#-------------------------------------------------------------------------------
space_usage(){
	echo "INFO:`eval ${TIMESTMP_CMD}`: Requesting for space usage..." | tee -a "${LOG_FILE}" 
	RETVAL=$(idevsutil --xml-output --password-file="${PASSWD}" --get-quota "${USERID}"@"${SERVER}"::home/)
	echo ${RETVAL} | tee -a "${LOG_FILE}"
	echo "${RETVAL}" | grep "SUCCESS" 2>&1>/dev/null
	if [ $? -eq 1 ] ; then
		echo "ERROR:`eval ${TIMESTMP_CMD}`: Cannot retrieve space usage." | tee -a "${LOG_FILE}"
		return
	fi
	read tq uq <<< $(echo "${RETVAL}" | tr -d '\n' | awk -F'"' '/totalquota/{v1=$4}/usedquota/{v2=$6}/ERROR/{v1="ERROR"} {printf v1" "v2}') 
	if [ "${tq:-0}" = "ERROR" ] ; then
		return
	fi
	echo "INFO INTERPRETER-" | tee -a "${LOG_FILE}"
	data_size_interpreter "${tq}"
	echo "TOTAL SPACE: ${INTERPRETED_SIZE}" | tee -a "${LOG_FILE}"
	data_size_interpreter "${uq}"
	echo "USED SPACE: ${INTERPRETED_SIZE}" | tee -a "${LOG_FILE}"
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  list_or_search
#   DESCRIPTION:  Search for or list files/folders
#    PARAMETERS:  na
#       RETURNS:  na
#-------------------------------------------------------------------------------
list_or_search(){
	if [ "${l_FLG:-0}" -eq 1 ]  ; then
		searchterm="${l_ARG}"			
	elif [ "${L_FLG:-0}" -eq 1 ] ; then
		searchterm="${DESTFOLDER}"
	fi
	echo "INFO:`eval ${TIMESTMP_CMD}`: Searching or listing for - '${searchterm}'..." | tee -a "${LOG_FILE}"
	idevsutil --xml-output --password-file="${PASSWD}" --search "${USERID}"@"${SERVER}"::home/"${searchterm}" 2>&1 | tee -a "${LOG_FILE}"
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  versioning_details
#   DESCRIPTION:  Get versioning info for the provided file/folder name
#    PARAMETERS:  na
#       RETURNS:  na
#-------------------------------------------------------------------------------
versioning_details(){
	echo "INFO:`eval ${TIMESTMP_CMD}`: Getting versioning details for - '${V_ARG}'..." | tee -a "${LOG_FILE}"
	idevsutil --xml-output --password-file="${PASSWD}" --version-info "${USERID}"@"${SERVER}"::home/"${V_ARG}" 2>&1 | tee -a "${LOG_FILE}"
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  file_properties
#   DESCRIPTION:  Get the file or folder properties for path given by user
#    PARAMETERS:  na
#       RETURNS:  ba
#-------------------------------------------------------------------------------
file_properties(){
	echo "INFO:`eval ${TIMESTMP_CMD}`: Getting properties for - '${p_ARG}'..." | tee -a "${LOG_FILE}" 
	RETVAL=$(idevsutil --xml-output --password-file="${PASSWD}" --properties "${USERID}"@"${SERVER}"::home/"${p_ARG}")
	echo ${RETVAL} | tee -a "${LOG_FILE}"
	fsz=0
	read fsz <<< $(echo "${RETVAL}" | awk -F'["| ]' '/size/{v1=$3}/ERROR/{v1="ERROR"} {printf v1}')
	if [ "${fsz:-0}" = "ERROR" ] ; then
		return
	fi
	echo "INFO INTERPRETER-" | tee -a "${LOG_FILE}"
	data_size_interpreter "${fsz}"
	echo "FILE/FOLDER SIZE: ${INTERPRETED_SIZE}" | tee -a "${LOG_FILE}"
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  show_help
#   DESCRIPTION:  Show the help content onto STDOUT
#    PARAMETERS:  1-Brief help for options, 2-Detailed help
#       RETURNS:  na
#-------------------------------------------------------------------------------
show_help(){
	if [ "${HELPFILE}" = "NA" ] ; then
		echo "ERROR:`eval ${TIMESTMP_CMD}`: No help file or manual found."
		return
	fi
	if [ $1 -eq 1 ] ; then
		echo "idrive-wrapper usage as below:"
		#Extract the brief usage summary from help file
		sed -n '/Usage Summary:START/,/Usage Summary:END/p' "${HELPFILE}" | head -n -1 | tail -n +2
	elif [ $1 -eq 2 ] ; then
		if [ ${C_more_AVAILABLE} -eq 1 ] ; then
			cat "${HELPFILE}" | more
		else
			cat "${HELPFILE}"
		fi
	fi
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  show_version
#   DESCRIPTION:  Show the current program version and idensutil version
#    PARAMETERS:  na
#       RETURNS:  na
#-------------------------------------------------------------------------------
show_version(){
	echo "${IDRIVEWRAPPER_VER}"
	echo $(idevsutil --client-version | head -n 1)
}

##HELPER FUNCTIONS##
#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  get_password
#   DESCRIPTION:  Get the user password
#    PARAMETERS:  na
#       RETURNS:  na
#-------------------------------------------------------------------------------
get_password(){
	read -s -p "--Enter password for ${USERID}:" PASSWD
	echo
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  get_server
#   DESCRIPTION:  Get the IDrive server details where backup is done
#    PARAMETERS:  na
#       RETURNS:  na
#-------------------------------------------------------------------------------
get_server(){
	echo "INFO:`eval ${TIMESTMP_CMD}`: Retrieving server details..." | tee -a "${LOG_FILE}"
	RETVAL=$(idevsutil --getServerAddress "${USERID}" --password-file="${PASSWD}")
	SERVER=$(echo ${RETVAL} | awk -F'["]' '/SUCCESS/{v1=$4}/ERROR/{v1=$2} {printf v1}')
	#If return contains error then exit
	if [ "${SERVER}" = "ERROR" ]
	then
		echo "ERROR:`eval ${TIMESTMP_CMD}`: Cannot get server details, exiting." | tee -a "${LOG_FILE}"
		echo ${RETVAL} | tee -a "${LOG_FILE}"
		clean_up_exit 1
	fi
	echo "INFO:`eval ${TIMESTMP_CMD}`: Server recevied as ${SERVER}" | tee -a "${LOG_FILE}"
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  backup_ACL
#   DESCRIPTION:  Backup the ACLs for the files and folders included in this run. 
#                 Save filename with timestamp to make it unique for each run.
#    PARAMETERS:  na
#       RETURNS:  na
#-------------------------------------------------------------------------------
backup_ACL(){
	if [ "${ACL_BACKUP}" = "" ] ; then
		echo "INFO:`eval ${TIMESTMP_CMD}`: ACL Backup not requested in config file." | tee -a "${LOG_FILE}"
		return
	fi
	if [ ! -d "${ACL_BACKUP}" ] ; then
		echo "ERROR:`eval ${TIMESTMP_CMD}`: ACL Backup folder ${ACL_BACKUP} is not valid/does not exist. ACL backup will not be performed." | tee -a "${LOG_FILE}"
		return
	fi
	if [ ${C_getfacl_AVAILABLE:-0} -ne 1 ] ; then
		echo "ERROR:`eval ${TIMESTMP_CMD}`: 'getfacl' command is not available. ACL backup will not be performed" | tee -a "${LOG_FILE}"
		return
	fi
	converted_uname=`echo "${USERID}" | sed 's/[^a-zA-Z0-9]/_/g'` #Remove the spl chars and replace with '_'
	filename="${ACL_BACKUP%/}"/${converted_uname}-acls-${TIMESTMP}.txt # Adding uname to filename incase of multiple accounts
	PTH=""
	cat $1 | while read PTH; do
	
		if [ "${PTH}" = "" ] ; then
			continue	
		fi
		getfacl -R "${PTH}" >> "${filename}"
	done
	if [ $? != 0 ] ; then
		echo "ERROR:`eval ${TIMESTMP_CMD}`: ACL backup might not have completed. Please check logs and verify in backup location." | tee -a "${LOG_FILE}"
	else
		echo "INFO:`eval ${TIMESTMP_CMD}`: ACL Backup completed in ${filename}" | tee -a "${LOG_FILE}"
	fi
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  data_size_interpreter
#   DESCRIPTION:  Get a number in bytes and then based on how big is the file i
#		  return the appropriate size in B,KB,MB,GB
#    PARAMETERS:  na
#       RETURNS:  na
#-------------------------------------------------------------------------------
data_size_interpreter(){
	INTERPRETED_SIZE=""
	if [ $1 -lt 1024 ] ; then
		INTERPRETED_SIZE=$1" B"
	elif [ ${C_bc_AVAILABLE:-0} -eq 1 ] ; then
		if [ $1 -lt 1048576 ] ; then
			INTERPRETED_SIZE=`echo "scale=2;$1/1024" | bc`" KB"
		elif [ $1 -lt 1073741824 ] ; then 
			INTERPRETED_SIZE=`echo "scale=2;$1/1048576" | bc`" MB"
		else
			INTERPRETED_SIZE=`echo "scale=2;$1/1073741824" | bc`" GB"
		fi
	else		
		if [ $1 -lt 1048576 ] ; then
			INTERPRETED_SIZE=`expr $1 / 1024`" KB"
		elif [ $1 -lt 1073741824 ] ; then 
			INTERPRETED_SIZE=`expr $1 / 1048576`" MB"
		else
			INTERPRETED_SIZE=`expr $1 / 1073741824`" GB"
		fi
	fi
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  clean_up_exit
#   DESCRIPTION:  Perform any needed cleanup and exit
#    PARAMETERS:  Exit status to be returned
#       RETURNS:  Exit status to shell
#-------------------------------------------------------------------------------
clean_up_exit(){
	rm -fr ./evs_temp/ #Temp directory created by idevsutil
	rm -fr ${WORKDIR} #Temp directory created for file/folder list
	exit $1
}

##START HERE##
init_script
#Process the command line options
process_options $# $@
echo "IDrive backup wrapper script started." | tee -a "${LOG_FILE}"
#Read the config file and assign params and populate file lists
read_config
#Get the password and server
get_password
get_server
#Call function for required ops
call_commands
#Remove any temp directories/files and exit
clean_up_exit 0
##END##
