import json
import boto3
import os
from PIL import Image
from io import BytesIO
import logging

s3_client = boto3.client('s3')
sns_client = boto3.client('sns')
logger = logging.getLogger()
logger.setLevel(logging.INFO)

THUMBNAIL_BUCKET = os.environ.get('THUMBNAIL_BUCKET')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')
THUMBNAIL_SIZE = (200, 200)

def lambda_handler(event, context):
    try:
        for record in event['Records']:
            bucket = record['s3']['bucket']['name']
            key = record['s3']['object']['key']
            logger.info(f"Processing image: {key} from bucket: {bucket}")
            
            response = s3_client.get_object(Bucket=bucket, Key=key)
            image_data = response['Body'].read()
            
            image = Image.open(BytesIO(image_data))
            image.thumbnail(THUMBNAIL_SIZE, Image.Resampling.LANCZOS)
            
            thumbnail_buffer = BytesIO()
            image.save(thumbnail_buffer, format='JPEG', quality=80)
            thumbnail_buffer.seek(0)
            
            thumbnail_key = f"thumbnails/{os.path.splitext(key)[0]}_thumb.jpg"
            
            s3_client.put_object(
                Bucket=THUMBNAIL_BUCKET,
                Key=thumbnail_key,
                Body=thumbnail_buffer.getvalue(),
                ContentType='image/jpeg'
            )
            
            message = f"Image Processing Complete!\nOriginal Image: {key}\nOriginal Bucket: {bucket}\nThumbnail Created: {thumbnail_key}\nThumbnail Bucket: {THUMBNAIL_BUCKET}"
            
            sns_client.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject='Image Thumbnail Generated Successfully',
                Message=message
            )
            
            logger.info(f"Thumbnail created: {thumbnail_key}")
        
        return {'statusCode': 200, 'body': json.dumps('Thumbnails generated successfully!')}
    except Exception as e:
        logger.error(f"Error processing image: {str(e)}")
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject='Image Processing Error',
            Message=f'Error: {str(e)}'
        )
        return {'statusCode': 500, 'body': json.dumps(f'Error: {str(e)}')}
