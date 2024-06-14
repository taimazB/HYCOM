import boto3
import json
from multiprocessing import Pool
from glob import glob


if (len(glob['../.active_*']) > 0):
    exit()


# os.environ['DO_AccessKey'] # "DO00XYVEW6BHJG6H9UK2"
DO_AccessKey = "DO00XYVEW6BHJG6H9UK2"
# os.environ['DO_SecretKey'] # "dGOFLqNJ/S3Xf2/IrvNApzpmKEmhGzJ5snLVCWJ2JRU"
DO_SecretKey = "dGOFLqNJ/S3Xf2/IrvNApzpmKEmhGzJ5snLVCWJ2JRU"

session = boto3.session.Session()
client = session.client('s3',
                        # Find your endpoint in the control panel, under Settings. Prepend "https://".
                        endpoint_url='https://nyc3.digitaloceanspaces.com',
                        # config=botocore.config.Config(s3={'addressing_style': 'virtual'}), # Configures to use subdomain/virtual calling format.
                        region_name='nyc3',  # Use the region in your endpoint.
                        # Access key pair. You can create access key pairs using the control panel or API.
                        aws_access_key_id=DO_AccessKey,
                        # Secret access key defined through an environment variable.
                        aws_secret_access_key=DO_SecretKey)

data = []
toDelete = []
paginator = client.get_paginator('list_objects_v2')
models = ['HYCOM']
for model in models:
    pages = paginator.paginate(Bucket="modeltiles", Prefix=f"{
                               model}/", Delimiter="/")
    modelDateTimes = list(pages)[0]['CommonPrefixes']
    modelDateTimes = list(map(lambda x: x['Prefix'], modelDateTimes))
    modelDateTimes = list(map(lambda x: x.split("/")[1], modelDateTimes))
    toDelete.append({'model': model, 'modelDateTimes': modelDateTimes[3:]})
    modelDateTimes = modelDateTimes[:3]  # KEEP ONLY LAST 3 MODEL DATETIMES
    for modelDateTime in modelDateTimes:
        pages = paginator.paginate(Bucket="modeltiles", Prefix=f"{
                                   model}/{modelDateTime}/", Delimiter="/")
        fields = list(pages)[0]['CommonPrefixes']
        fields = list(map(lambda x: x['Prefix'], fields))
        fields = list(map(lambda x: x.split("/")[2], fields))
        if ('DONE' in fields):
            fields.remove('DONE')
            for field in fields:
                pages = paginator.paginate(Bucket="modeltiles", Prefix=f"{
                                           model}/{modelDateTime}/{field}/", Delimiter="/")
                dateTimes = list(pages)[0]['CommonPrefixes']
                dateTimes = list(map(lambda x: x['Prefix'], dateTimes))
                dateTimes = list(map(lambda x: x.split("/")[3], dateTimes))
                data.append({"model": model, "modelDateTime": modelDateTime,
                            "field": field, "dateTimes": dateTimes})

# Upload data to "avails.json"
client.put_object(Bucket='modeltiles', Key='avails.json',
                  Body=json.dumps(data), ACL='public-read')


# REMOVE OLD DIRECTORIES
def delete(obj):
    client.delete_object(Bucket="modeltiles", Key=obj['Key'])


for obj in toDelete:
    model = obj['model']
    for modelDateTime in obj['modelDateTimes']:
        pages = paginator.paginate(Bucket="modeltiles", Prefix=f"{
                                   model}/{modelDateTime}/")
        for page in pages:
            with Pool() as p:
                p.map(delete, page['Contents'])
