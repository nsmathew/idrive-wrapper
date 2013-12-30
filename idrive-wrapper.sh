#!/usr/bin/bash
#Utility to backup local data to IDrive's cloud backup
#Based on IDrive's command line utility, idevsutil
#Copyright for IDrive's utility idevsutil is with IDrive, http://evs.idrive.com/terms-of-service.htm
#Copyright for rest of the script Nitin Mathew, 2013

FILELIST_UPLOAD=/home/nsm09/scripts/resources/FILELIST-IDRIVE-UPLOAD
FILELIST_DELETE=/home/nsm09/scripts/resources/FILELIST-IDRIVE-DELETE
USERID=nsmathew@gmail.com
DESTFOLDER=ArchLinux

#Check if required variable are defined, exclude deletion list from check
if [ ! -f ${FILELIST_UPLOAD} ] ||  [ "${USERID}" = "" ] || [ "${DESTFOLDER}" = "" ]
then
	echo "Problem in required variables FILELIST_UPLOAD:${FILELIST_UPLOAD}, USER:${USERID}, DESTFOLDER:${DESTFOLDER}. Please correct in script and rerun."
	exit 1
fi

echo
echo "Backup into IDrive for ${USERID}." 
echo "File/Folder list for UPLOAD from ${FILELIST_UPLOAD} as below:"
cat ${FILELIST_UPLOAD}
echo "File/Folder list for DELETION from ${FILELIST_DELETE} as below:"
cat ${FILELIST_DELETE}

#Get password
read -s -p "Enter password for ${USERID}:" PWD
echo
#Get server
echo "Retrieving server details..."
RETVAL=$(idevsutil --getServerAddress ${USERID} --password-file=${PWD})
SERVER=$(echo ${RETVAL} | awk -F'[=| ]' '/SUCCESS/{v1=$5}/ERROR/{v1=$3} {printf v1}' | awk -F'"' '{printf $2}')

#If return contains error then exit
if [ ${SERVER} = "ERROR" ]
then
	echo "Error getting server details, exiting."
	echo ${RETVAL}
	exit 1
fi

#Start backup
echo "Server received as ${SERVER}"
echo "Starting backup..."
idevsutil --xml-output --password-file=${PWD} --files-from=${FILELIST_UPLOAD} / ${USERID}@${SERVER}::home/${DESTFOLDER}
echo "Backup run is complete, check log for any errors."

#Check if anything is there for deletion
if [ ! -s ${FILELIST_DELETE} ] 
then
	echo "File list for deletion is empty or not available. Nothing will be deleted"
else
	echo "Starting file deletion..."
	idevsutil --xml-output --password-file=${PWD} --delete-items --files-from=${FILELIST_DELETE} ${USERID}@${SERVER}::home/${DESTFOLDER}
	echo "File deletion is complete"
fi

#List files
echo "File Listing as below from ${DESTFOLDER}:"
idevsutil --xml-output --password-file=${PWD} --all --search ${USERID}@${SERVER}::home/${DESTFOLDER}/*

#Provide addl info
echo "Additional commands are avaialble at http://evs.idrive.com/dev-guide-parameters.htm"
echo "Exiting"
