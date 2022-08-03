#!/bin/sh

# NOTE:
# Make sure that the value of Name, Type, TTL are the same with your DNS Record Set

HOSTED_ZONE_ID=Z05471843RNAQFU8FZXA
RESOURCE_VALUE=schema.us-east-1.test.vignali.rocks
DNS_NAME=schema.test.vignali.rocks
# RECORD_TYPE=A
RECORD_TYPE=CNAME
TTL=300
ACTION=DELETE
# ACTION=DELETE
# ACTION=CREATE


JSON_FILE=file.json


echo "{">> $JSON_FILE
echo " \"Comment\": \"Delete single record set\",">> $JSON_FILE
echo " \"Changes\": [">> $JSON_FILE
echo "   {" >> $JSON_FILE
echo "     \"Action\": \"$ACTION\"," >> $JSON_FILE
echo "     \"ResourceRecordSet\": {"  >> $JSON_FILE
aws route53 list-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --output json --query "ResourceRecordSets[?Name == '$RESOURCE_VALUE.']" | tail -n +3 | head -n -1 >> $JSON_FILE
echo "  }"  >> $JSON_FILE
echo " ]"  >> $JSON_FILE
echo "}"  >> $JSON_FILE


# (
# cat <<EOF
# {
#     "Comment": "Delete single record set",
#     "Changes": [
#         {
#             "Action": "$ACTION",
#             "ResourceRecordSet": {
#                 "Name": "$DNS_NAME.",
#                 "Type": "$RECORD_TYPE",
#                 "TTL": $TTL,
#                 "ResourceRecords": [
#                     {
#                         "Value": "${RESOURCE_VALUE}"
#                     }
#                 ]                
#             }
#         }
#     ]
# }
# EOF
# ) > $JSON_FILE

aws route53 change-resource-record-sets --hosted-zone-id ${HOSTED_ZONE_ID} --change-batch file://$JSON_FILE

rm $JSON_FILE
# echo "Deleting record set ..."
echo
echo "Operation Completed."