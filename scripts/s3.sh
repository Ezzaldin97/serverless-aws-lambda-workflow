#!/bin/bash

BUCKET_NAME="ezz-ds-ml-development"
FILE_NAME="data.json"

# check first if bucket exists before creation
if ! aws s3 ls "s3://$BUCKET_NAME" > /dev/null 2>&1; then
    echo "Bucket does not exist. Creating..."
    aws s3 mb s3://$BUCKET_NAME
fi

# fill the json file with name and age
touch data/$FILE_NAME
echo '{"name": "John Doe", "age": 30}' > data/$FILE_NAME

# upload the json file to s3
aws s3 cp data/$FILE_NAME s3://$BUCKET_NAME/$FILE_NAME

# create a directory with 4 text files in data directory
mkdir -p data/mytxt
for i in {1..4}; do
    echo "This is file $i" > data/mytxt/file$i.txt
done

aws s3 sync data/mytxt s3://$BUCKET_NAME/mytxt

# create the bucket policy
aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy file://s3_bucket_policy.json