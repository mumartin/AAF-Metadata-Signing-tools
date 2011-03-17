#! /bin/sh

if [ "$#" -ne "7" ]; then
    echo "Usage: sign-md.sh Federation MD-Name MD-URL unsigned-file-name signed-file-name destin-dir email"
    exit -1
fi   

LOCATION=$0
LOCATION=${LOCATION%/*}

FED=$1
MDNAME=$2
MDURL=$3
MDUNSIGNED=$4
MDSIGNED=$5
MDDESTIN=$6
MAIL=$7

# Key Store that hold the Federation Signing key. The keystore file must be located in the certs directory.
FEDERATION_KS=keystore.ks
FEDERATION_KEY_ALIAS=put-key-alias-here
FEDERATION_KS_PASSPHRASE=put-pass-phrase-here

# Set Java Home
JAVA_HOME=/usr/lib/jvm/java-1.6.0-openjdk-1.6.0.0.x86_64/jre
export JAVA_HOME

mkdir -p $LOCATION/$FED
mkdir -p $LOCATION/$FED/work
WORK=$LOCATION/$FED/work
mkdir -p $LOCATION/$FED/log
LOG=$LOCATION/$FED/log
mkdir -p $LOCATION/$FED/backup
BACKUP=$LOCATION/$FED/backup
MAILFROM=tech-watcher@aaf.edu.au
ERRMAILTO=admin@aaf.edu.au
TIMESTAMP=`date +%Y%m%d%H%M`

# Download unsigned metadata from URL

#echo "wget --no-check-certificate -o $LOG/wget_$MDNAME.log -O $WORK/$MDUNSIGNED $MDURL"
wget --no-check-certificate -o $LOG/wget_$MDNAME.log -O $WORK/$MDUNSIGNED $MDURL

ret=$?
if [ "$ret" -ne "0" ] ; then
#    echo "$FED-ERROR: Retrieving un-signed metadata $MDNAME from source $MDURL (wget: $ret)"

    SUBJECT="$FED-ERROR: Retrieving un-signed metadata $MDNAME from source $MDURL (wget: $ret)"
    EMAILMESSAGE="$LOG/wget_$MDNAME.log"

#    echo /bin/mail -s "$SUBJECT" "$MAIL" -- -f "$MAILFROM" < $EMAILMESSAGE
    /bin/mail -s "$SUBJECT" "$ERRMAILTO" -- -f "$MAILFROM" < $EMAILMESSAGE

    exit $ret
fi

# Check that we are not re-signing the same file... If they are the same we are done
# Skip this check if first time through

if [ -f $WORK/$MDUNSIGNED.prev ]
then
    diff $WORK/$MDUNSIGNED $WORK/$MDUNSIGNED.prev > $LOG/$MDUNSIGNED.diff

    ret=$?

    if [ "$ret" -eq "0" ] ; then
        exit 0
    fi
fi

# Validate the unsigned Metadata
#

# echo "Validating..."

# echo $LOCATION/xmlsectool/xmlsectool.sh --validateSchema --xsd --httpProxy wproxy.qut.edu.au --httpProxyPort 3128 --schemaDirectory $LOCATION/schema --schemaDirectory $LOCATION/schema/xmldsig-core-schema.xsd --inFile $WORK/$MDUNSIGNED

$LOCATION/xmlsectool/xmlsectool.sh --validateSchema --xsd --schemaDirectory $LOCATION/schema --schemaDirectory $LOCATION/schema/xmldsig-core-schema.xsd --inFile $WORK/$MDUNSIGNED 2>&1 > $LOG/validate_$MDUNSIGNED.log

ret=$?
if [ "$ret" -ne "0" ] ; then
    echo "$FED-ERROR: Validation of Metadata $MDNAME failed ($ret)"

        SUBJECT="$FED-ERROR: Validation of Metadata $MDNAME failed ($ret)"
        EMAILMESSAGE="$LOG/validate_$MDUNSIGNED.log"

        /bin/mail -s "$SUBJECT" "$ERRMAILTO" -- -f "$MAILFROM" < $EMAILMESSAGE

    exit $ret
fi

# Sign the unsigned Metadata
#

#echo "Signing..."

#echo $LOCATION/xmlsectool/xmlsectool.sh --sign --inFile $WORK/$MDUNSIGNED --outFile $WORK/$MDSIGNED --keystore $LOCATION/certs/$FEDERATION_KS --key $FEDERATION_KEY_ALIAS --keyPassword $FEDERATION_KS_PASSPHRASE

$LOCATION/xmlsectool/xmlsectool.sh --sign --inFile $WORK/$MDUNSIGNED --outFile $WORK/$MDSIGNED --keystore $LOCATION/certs/$FEDERATION_KS --key $FEDERATION_KEY_ALIAS --keyPassword $FEDERATION_KS_PASSPHRASE 2>&1 > $LOG/sign_$MDUNSIGNED.log

ret=$?
if [ "$ret" -ne "0" ] ; then
#    echo "$FED-ERROR: Signing the Metadata $MDNAME failed ($ret)"

        SUBJECT="$FED-ERROR: Signing the Metadata $MDNAME failed ($ret)"
        EMAILMESSAGE=$LOG/sign_$MDUNSIGNED.log

        /bin/mail -s "$SUBJECT" "$ERRMAILTO" -- -f "$MAILFROM" < $EMAILMESSAGE

    exit $ret
fi

# Deploy newly signed Metadata
#

#echo "Deploying..."

cp $WORK/$MDSIGNED $MDDESTIN/$MDSIGNED.new

mv $MDDESTIN/$MDSIGNED.new $MDDESTIN/$MDSIGNED

# See if the Metadata has changed, if so Make a backup of previous version and email differences 
#

if [ -f $WORK/$MDUNSIGNED.prev ]; then
    diff -uI "validUntil" $WORK/$MDUNSIGNED.prev $WORK/$MDUNSIGNED > $LOG/$MDUNSIGNED.diff

    ret=$?

    if [ "$ret" -eq "1" ] ; then
	mv $WORK/$MDUNSIGNED.prev $BACKUP/$MDUNSIGNED.$TIMESTAMP
	cp $LOG/$MDUNSIGNED.diff $BACKUP/$MDUNSIGNED.diff.$TIMESTAMP

	if [ -f $WORK/$MDSIGNED.prev ]; then
	    cp $WORK/$MDSIGNED.prev $BACKUP/$MDSIGNED.$TIMESTAMP
	fi

	SUBJECT="$FED-Metadata: Updated."
	EMAILMESSAGE=$LOG/$MDUNSIGNED.diff

	/bin/mail -s "$SUBJECT" "$MAIL" -- -f "$MAILFROM" < $EMAILMESSAGE
    fi
fi

mv $WORK/$MDUNSIGNED $WORK/$MDUNSIGNED.prev
mv $WORK/$MDSIGNED $WORK/$MDSIGNED.prev
