# ARCHITECTURE

## System Design

Serverless image thumbnail generation pipeline using AWS.

## Data Flow

1. Image Upload → S3 Source
2. S3 Event → Lambda
3. Process Image
4. Upload to S3 Dest
5. Notify SNS
6. Email Alert

## Components

- S3 Source/Dest Buckets
- Lambda Function (Python)
- SNS Topic
- CloudWatch Logs

## Security

- IAM Least Privilege
- Encryption at Rest
- Public Access Blocked
