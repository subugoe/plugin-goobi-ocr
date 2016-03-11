#!/bin/bash

###############################################################################
# This script performs three main tasks:
# - it searches in several places of Goobi for information needed for OCR
# - it executes OCR using that information as input
# - it converts the OCR result to a TEI file
# 
# All steps are logged into a file. If an error occurs, an email with the 
# contents of the log file is sent to a predefined address.
###############################################################################

# This is called when there is an error
function mailAndQuit {
	email=`head -1 /opt/digiverso/goobi/scripts/ocr/mail_for_error_report.txt | cut -f 1`
	logFileToSend=$1
	echo "mailing $logFileToSend to $email"
	mail -s "Goobi: Error in OCR" $email < $logFileToSend
	exit 1
}

goobiPath="/opt/digiverso/goobi"

# e.g. .../metadata/60000/images
imagePath=$1

# e.g. .../metadata/60000/images/orig_airyon_PPN1234_tif
origPath=$2

# e.g. .../metadata/60000/images/airyon_PPN1234_tif
tifPath=$3

# e.g. Antiqua, Fraktur
textTypeInGoobi=$4

logFolder="$goobiPath/../logs/ocr"
if [ ! -d $logFolder ]; then
	mkdir $logFolder
fi
bookTitle=`echo $tifPath | grep -P -o 'images/\S+' | cut -d "/" -f 2`
# e.g. /opt/digiverso/logs/ocr/airyon_PPN1234_tif.log
logFile="$logFolder/$bookTitle.log"

echo "Logging to $logFile"
echo "Starting OCR for $imagePath" 2>&1 | tee $logFile

#------------------------------------------------------------------------------
# Find out the languages
#
# Languages in meta.xml file are normally three-letter codes: eng, ger
# OCR tool needs ISO codes: en, de
# Mappings are defined in languages.txt
#------------------------------------------------------------------------------
langsInGoobi=`grep -P -o 'DocLanguage\">\w+' $imagePath/../meta.xml | cut -d ">" -f 2`
echo "Found languages: $langsInGoobi" 2>&1 | tee -a $logFile

langsForOcr=""

for lang in $langsInGoobi; do
	nextOcrLang=`grep $lang: $goobiPath/scripts/ocr/languages.txt | cut -d ':' -f 2`
	# OCR tool expects comma-separated language codes
	langsForOcr="$langsForOcr,$nextOcrLang"
done

if [ -n "$langsForOcr" ]; then
	# Remove the leading comma
	langsForOcr=${langsForOcr:1}
else
	langsForOcr=`grep defaults: $goobiPath/scripts/ocr/languages.txt | cut -d ':' -f 2`
fi
echo "Using languages for OCR: $langsForOcr" 2>&1 | tee -a $logFile
#------------------------------------------------------------------------------

###############################################################################
# Determine the text type 
#
# 'gothic' is only set if 'Fraktur' is passed from Goobi 
# Otherwise it is always 'normal'
###############################################################################
echo "Found text type: $textTypeInGoobi" 2>&1 | tee -a $logFile

if [ "$textTypeInGoobi" = "Fraktur" ]; then
	textTypeForOcr="gothic"
else
	textTypeForOcr="normal"
fi
echo "Using text type for OCR: $textTypeForOcr" 2>&1 | tee -a $logFile
###############################################################################

#//////////////////////////////////////////////////////////////////////////////
# Determine OCR input folder
# 
# There are three cases:
# 1. Images have different color depths ('mixed'): 
#      1-bit bitonal, 8-bit gray, or 24-bit colored
# 2. All images are 24-bit colored
# 3. All images are 1-bit bitonal
# 
# Case 1: All gray, colored, and bitonal images are copied into a new folder
#         that ends in '_mixed'. After successful OCR, the folder is deleted.
# Case 2: The 'original' folder with uncompressed images is taken, because
#         the main tif folder contains manipulated ones of worse quality.
# Case 3: The main tif folder with manipulated images is taken.
#//////////////////////////////////////////////////////////////////////////////
mixedColorImages=false

if [ -d ${tifPath%tif}grau ]; then
	grayPath=${tifPath%tif}grau
	mixedColorImages=true
fi
if [ -d ${tifPath%tif}col ]; then
	colorPath=${tifPath%tif}col
	mixedColorImages=true
fi

if [ "$mixedColorImages" = true ]; then
	rm -rf ${tifPath}_mixed
	mkdir ${tifPath}_mixed
	cp $tifPath/* ${tifPath}_mixed
fi
if [ "$grayPath" != "" ]; then
	cp $grayPath/* ${tifPath}_mixed
fi
if [ "$colorPath" != "" ]; then
	cp $colorPath/* ${tifPath}_mixed
fi

colorDepth=`tiffinfo $origPath/00000001.tif 2> /dev/null | grep -P -o 'Bits/Sample: \S+' | cut -d ' ' -f 2`
colorKind=`tiffinfo $origPath/00000001.tif 2> /dev/null | grep -P -o 'Photometric Interpretation: \S+' | cut -d ' ' -f3`

echo found depth:  $colorDepth

inputPathForOcr=$tifPath

if [ "$mixedColorImages" = true ]; then
	echo "Found mixed colored images" 2>&1 | tee -a $logFile
	inputPathForOcr=${tifPath}_mixed
elif [ "$colorKind" = "RGB" ]; then
	echo "Found colored images only" 2>&1 | tee -a $logFile
	inputPathForOcr=$origPath
elif [ "$colorDepth" = "1" ]; then
	echo "Found bitonal images only" 2>&1 | tee -a $logFile
	inputPathForOcr=$tifPath
else
	echo "ERROR: Could not determine color depth! Exiting." 2>&1 | tee -a $logFile
	mailAndQuit $logFile
fi

echo "Using folder for OCR: $inputPathForOcr" 2>&1 | tee -a $logFile
#//////////////////////////////////////////////////////////////////////////////

###############################################################################
# Run OCR
###############################################################################
ocrUser=`head -1 $goobiPath/scripts/ocr/credentials.txt | cut -f 1`
ocrPassword=`head -2 $goobiPath/scripts/ocr/credentials.txt | tail -1 | cut -f 1`

java -jar $goobiPath/scripts/ocr/ocr.jar -engine abbyy-multiuser -indir $inputPathForOcr -outdir $imagePath -texttype normal -langs $langsForOcr -outformats xml -props books.split=true,user=$ocrUser,password=$ocrPassword 2>&1 | tee -a $logFile

if [ "$mixedColorImages" = true ]; then
	echo "Deleting temp folder ${tifPath}_mixed" 2>&1 | tee -a $logFile
	rm -r ${tifPath}_mixed
fi

ocrResult="$inputPathForOcr.xml"
###############################################################################

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Convert Abbyy XML to TEI
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
teiOutput="$tifPath.tei.xml"

java -jar $goobiPath/scripts/ocr/converter.jar -infile $ocrResult -informat abbyyxml -outfile $teiOutput -outformat xsltoutput -outoptions xslt=$goobiPath/scripts/ocr/converter_toSubTei.xsl 2>&1 | tee -a $logFile

if [ ! -f $teiOutput ]; then
	echo "ERROR: No TEI output was produced!" 2>&1 | tee -a $logFile
	mailAndQuit $logFile
fi

rm $ocrResult
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#------------------------------------------------------------------------------
# Check for errors
#------------------------------------------------------------------------------
ERROR=`grep "ERROR" $logFile`
Exception=`grep "Exception" $logFile`
Illegal=`grep "Illegal" $logFile`

if [ "$ERROR" -o "$Exception" -o "$Illegal" ]; then
	mailAndQuit $logFile
fi
#------------------------------------------------------------------------------


