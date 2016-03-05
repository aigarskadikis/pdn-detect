#!/bin/sh

#this code is tested un fresh 2015-02-09-raspbian-jessie-lite Raspberry Pi image
#by default this script should be located in two subdirecotries under the home

#sudo apt-get update -y && sudo apt-get upgrade -y
#sudo apt-get install git -y
#mkdir -p /home/pi/detect && cd /home/pi/detect
#git clone https://github.com/catonrug/pdn-detect.git && cd pdn-detect && chmod +x check.sh && ./check.sh

#check if script is located in /home direcotry
pwd | grep "^/home/" > /dev/null
if [ $? -ne 0 ]; then
  echo script must be located in /home direcotry
  return
fi

#it is highly recommended to place this directory in another directory
deep=$(pwd | sed "s/\//\n/g" | grep -v "^$" | wc -l)
if [ $deep -lt 4 ]; then
  echo please place this script in deeper directory
  return
fi

#set application name based on directory name
#this will be used for future temp directory, database name, google upload config, archiving
appname=$(pwd | sed "s/^.*\///g")

#set temp directory in variable based on application name
tmp=$(echo ../tmp/$appname)

#create temp directory
if [ ! -d "$tmp" ]; then
  mkdir -p "$tmp"
fi

#check if database directory has prepared 
if [ ! -d "../db" ]; then
  mkdir -p "../db"
fi

#set database variable
db=$(echo ../db/$appname.db)

#if database file do not exist then create one
if [ ! -f "$db" ]; then
  touch "$db"
fi

#check if google drive config directory has been made
#if the config file exists then use it to upload file in google drive
#if no config file is in the directory there no upload will happen
if [ ! -d "../gd" ]; then
  mkdir -p "../gd"
fi

#name of applicaition
name=$(echo "paint.net")

#where the latest installer are located
download=$(echo "http://www.dotpdn.com/downloads/pdn.html")

#launch some test download
wget -S --spider -o $tmp/output.log $download

#check if the whole page is even working
grep -A99 "^Resolving" $tmp/output.log | grep "HTTP.*200 OK"
if [ $? -eq 0 ]; then
echo

#get the zip file installer direct link
url=$(wget -qO- "$download" | sed "s/\d034/\n/g" | grep zip | head -1 | sed "s/\.*//" | sed "s/^/http:\/\/www.dotpdn.com/")
echo "$url" | grep "paint\.net.*install\.zip"
if [ $? -eq 0 ]; then
echo

#get filename and compare to the database
filename=$(echo $url | sed "s/^.*\///g")
grep "$filename" $db
if [ $? -ne 0 ]; then
echo

echo new version detected!
echo

echo Downloading $filename
wget $url -O $tmp/$filename -q
echo

echo creating md5 checksum of file..
md5=$(md5sum $tmp/$filename | sed "s/\s.*//g")
echo

echo creating sha1 checksum of file..
sha1=$(sha1sum $tmp/$filename | sed "s/\s.*//g")
echo

#lets put all signs about this file into the database
echo "$filename">> $db
echo "$md5">> $db
echo "$sha1">> $db
echo >> $db

echo searching exact version number and compare to version pattern
version=$(echo "$filename" | sed "s/paint.net.\|.install.zip//g")
echo "$version" | grep "^[0-9]\+[\., ]\+[0-9]\+[\., ]\+[0-9]\+"
if [ $? -eq 0 ]; then
echo

#if google drive config exists then upload and delete file:
if [ -f "../gd/$appname.cfg" ]
then
echo Uploading $filename to Google Drive..
echo Make sure you have created \"$appname\" direcotry inside it!
../uploader.py "../gd/$appname.cfg" "$tmp/$filename"
echo
fi

#lets send emails to all people in "posting" file
emails=$(cat ../posting | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name $version" "$url 
$md5
$sha1"
} done
echo

else
#version do not match version pattern
echo version do not match version pattern
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "Version do not match version pattern: 
$download "
} done
fi

else
#if file already in database
echo file already in database						
fi

else
#can not find exe installers name
echo can not find exe installers name
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "can not find exe installers name: 
$download "
} done
echo 
echo
fi

else
#if http statis code is not 200 ok
echo Did not receive good http status code
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "the following link do not retrieve good http status code: 
$download "
} done
echo 
echo
fi

#clean and remove whole temp direcotry
rm $tmp -rf > /dev/null
