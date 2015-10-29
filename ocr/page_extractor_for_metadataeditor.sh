#!/bin/bash

##############################################################################
# This script extracts the text of one or several consecutive pages
# from a TEI file. The pages must be delimited by <milestone> tags.
# It is used by the Goobi Metadata Editor when you click on the OCR button.
##############################################################################

teiFile=$1
pageFrom=$2
pageFromMinusOne=$(($pageFrom-1))
pageTo=$3

if [ "$pageFrom" = "1" ]; then
	startTag="<body>"
else
	startTag="<milestone n=\"${pageFromMinusOne}\" type=\"page\"/>"
fi

endTag="<milestone n=\"${pageTo}\" type=\"page\"/>"

# read into a string, remove newlines and everything before startTag and after endTag
text=`cat $teiFile | tr -d "\n" | sed "s|.*$startTag||" | sed "s|$endTag.*||"`

# mark newlines to be after paragraphs and at linebreaks
text=`echo "$text" | sed 's_</p>_{newline}_g'`
text=`echo "$text" | sed 's_<lb/>_{newline}_g'`
# mark spaces to be after words (and punctuations)
text=`echo "$text" | sed 's_</w>_{space}_g'`
# remove all tags
text=`echo "$text" | sed 's:<[^>]*>::g'`
# remove all spaces
text=`echo "$text" | sed 's:\s*::g'`
# restore all marked spaces and newlines
text=`echo "$text" | sed 's:{space}: :g'`
text=`echo "$text" | sed 's:{newline}:\n:g'`
# remove some spaces before or after punctuation characters
text=`echo "$text" | sed 's| \.|\.|g'`
text=`echo "$text" | sed 's/ ,/,/g'`
text=`echo "$text" | sed 's/ ;/;/g'`
text=`echo "$text" | sed 's/ :/:/g'`
text=`echo "$text" | sed 's/ ’ /’/g'`
text=`echo "$text" | sed 's/( /(/g'`
text=`echo "$text" | sed 's/ )/)/g'`
text=`echo "$text" | sed 's/ !/!/g'`
text=`echo "$text" | sed 's/ ?/?/g'`

echo "$text"
