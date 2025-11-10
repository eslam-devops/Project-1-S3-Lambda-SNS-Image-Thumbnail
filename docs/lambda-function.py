# Lambda Function Code for Image Thumbnail Generation
# File: index.py (or lambda_function.py)
# By: Islam Zain - Project 1

import json
import boto3
import os
from PIL import Image
from io import BytesIO
import logging
from datetime import datetime

# Initialize AWS clients
s3_client = boto3.client('s3')
sns_client = boto3.client('sns')

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
THUMBNAIL_BUCKET = os.environ.get('THUMBNAIL_BUCKET')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')
THUMBNAIL_SIZE = (200, 200)
THUMBNAIL_QUALITY = 80

def lambda_handler(event, context):
    """
    Main Lambda handler function
    Triggered by S3 ObjectCreated events
    Generates thumbnails and sends SNS notifications
    
    Args:
        event: S3 event from Lambda trigger
        context: Lambda context object
    
    Returns:
        dict: Lambda response with status code and body
    """
    
    try:
        logger.info(f"Lambda function triggered at {datetime.now()}")
        logger.info(f"Event: {json.dumps(event)}")
        
        # Process all records from the S3 event
        for record in event.get('Records', []):
            try:
                # Extract S3 bucket and object information
                bucket_name = record['s3']['bucket']['name']
                object_key = record['s3']['object']['key']
                
                logger.info(f"Processing image: s3://{bucket_name}/{object_key}")
                
                # Download the original image from S3
                response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
                image_data = response['Body'].read()
                
                logger.info(f"Downloaded image size: {len(image_data)} bytes")
                
                # Open image using PIL
                image = Image.open(BytesIO(image_data))
                
                # Log original image details
                logger.info(f"Original image format: {image.format}, Size: {image.size}")
                
                # Convert RGBA to RGB if necessary (for JPEG compatibility)
                if image.mode in ('RGBA', 'LA', 'P'):
                    # Create white background
                    background = Image.new('RGB', image.size, (255, 255, 255))
                    if image.mode == 'P':
                        image = image.convert('RGBA')
                    background.paste(image, mask=image.split()[-1] if image.mode == 'RGBA' else None)
                    image = background
                
                # Generate thumbnail with fixed size
                image.thumbnail(THUMBNAIL_SIZE, Image.Resampling.LANCZOS)
                
                logger.info(f"Thumbnail generated: {image.size}")
                
                # Save thumbnail to BytesIO buffer
                thumbnail_buffer = BytesIO()
                image.save(thumbnail_buffer, format='JPEG', quality=THUMBNAIL_QUALITY, optimize=True)
                thumbnail_buffer.seek(0)
                
                # Generate thumbnail file name
                # Extract original filename without extension
                filename_without_ext = os.path.splitext(object_key)[0]
                thumbnail_key = f"thumbnails/{os.path.basename(filename_without_ext)}_thumb.jpg"
                
                logger.info(f"Uploading thumbnail to: s3://{THUMBNAIL_BUCKET}/{thumbnail_key}")
                
                # Upload thumbnail to destination bucket
                s3_client.put_object(
                    Bucket=THUMBNAIL_BUCKET,
                    Key=thumbnail_key,
                    Body=thumbnail_buffer.getvalue(),
                    ContentType='image/jpeg',
                    Metadata={
                        'original-image': object_key,
                        'source-bucket': bucket_name,
                        'generated-by': 'Lambda-ThumbnailGenerator',
                        'generation-time': datetime.now().isoformat()
                    }
                )
                
                logger.info(f"Thumbnail uploaded successfully: {len(thumbnail_buffer.getvalue())} bytes")
                
                # Prepare success notification message
                success_message = f"""
╔════════════════════════════════════════════════════════╗
║     IMAGE PROCESSING COMPLETED SUCCESSFULLY            ║
╚════════════════════════════════════════════════════════╝

📸 ORIGINAL IMAGE DETAILS:
   • File Name: {object_key}
   • Source Bucket: {bucket_name}
   • File Size: {len(image_data)} bytes
   • Format: {image.format}

🖼️  THUMBNAIL GENERATED:
   • Thumbnail Name: {thumbnail_key}
   • Destination Bucket: {THUMBNAIL_BUCKET}
   • Thumbnail Size: {thumbnail_size_text(thumbnail_buffer)}
   • Dimensions: {THUMBNAIL_SIZE[0]}x{THUMBNAIL_SIZE[1]} pixels
   • Quality: {THUMBNAIL_QUALITY}%

⏰ PROCESSING TIME: 
   • Timestamp: {datetime.now().isoformat()}
   • Status: SUCCESS ✓

───────────────────────────────────────────────────────────
Generated by: Project 1 Lambda Thumbnail Generator
                """
                
                # Send success notification via SNS
                sns_client.publish(
                    TopicArn=SNS_TOPIC_ARN,
                    Subject=f'✓ Thumbnail Generated: {os.path.basename(object_key)}',
                    Message=success_message
                )
                
                logger.info("Success notification sent via SNS")
                
            except Exception as record_error:
                logger.error(f"Error processing record: {str(record_error)}")
                
                # Send error notification
                error_message = f"""
╔════════════════════════════════════════════════════════╗
║        IMAGE PROCESSING ERROR OCCURRED                 ║
╚════════════════════════════════════════════════════════╝

❌ ERROR DETAILS:
   • Error Type: {type(record_error).__name__}
   • Error Message: {str(record_error)}
   • Timestamp: {datetime.now().isoformat()}

📍 CONTEXT:
   • Bucket: {record.get('s3', {}).get('bucket', {}).get('name', 'Unknown')}
   • Object Key: {record.get('s3', {}).get('object', {}).get('key', 'Unknown')}

🔧 TROUBLESHOOTING:
   1. Check that the file is a valid image (JPG, PNG)
   2. Verify the file size is less than 100MB
   3. Ensure Lambda has permissions to read from source and write to destination bucket
   4. Check CloudWatch logs for detailed error trace

───────────────────────────────────────────────────────────
Generated by: Project 1 Lambda Thumbnail Generator
                """
                
                sns_client.publish(
                    TopicArn=SNS_TOPIC_ARN,
                    Subject=f'❌ Error Processing Image: {record.get("s3", {}).get("object", {}).get("key", "Unknown")}',
                    Message=error_message
                )
                
                # Continue processing other records
                continue
        
        # Success response
        response = {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Thumbnail generation completed successfully',
                'records_processed': len(event.get('Records', [])),
                'timestamp': datetime.now().isoformat()
            })
        }
        
        logger.info(f"Lambda execution completed successfully")
        return response
        
    except Exception as main_error:
        logger.error(f"Critical error in Lambda handler: {str(main_error)}")
        
        # Send critical error notification
        critical_message = f"""
╔════════════════════════════════════════════════════════╗
║        CRITICAL LAMBDA EXECUTION ERROR                 ║
╚════════════════════════════════════════════════════════╝

🚨 CRITICAL ERROR:
   • Error: {str(main_error)}
   • Type: {type(main_error).__name__}
   • Timestamp: {datetime.now().isoformat()}

⚙️  ENVIRONMENT:
   • Thumbnail Bucket: {THUMBNAIL_BUCKET}
   • SNS Topic ARN: {SNS_TOPIC_ARN}
   • Thumbnail Size: {THUMBNAIL_SIZE}

📋 ACTION REQUIRED:
   Review CloudWatch logs immediately for detailed stack trace
   and contact the development team if needed.

───────────────────────────────────────────────────────────
Generated by: Project 1 Lambda Thumbnail Generator
        """
        
        try:
            sns_client.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject='🚨 CRITICAL: Lambda Function Error',
                Message=critical_message
            )
        except Exception as sns_error:
            logger.error(f"Failed to send error notification: {str(sns_error)}")
        
        # Error response
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Lambda execution failed',
                'message': str(main_error),
                'timestamp': datetime.now().isoformat()
            })
        }


def thumbnail_size_text(buffer):
    """Helper function to format buffer size in readable format"""
    size_bytes = buffer.getbuffer().nbytes
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.2f} KB"
    else:
        return f"{size_bytes / (1024 * 1024):.2f} MB"
