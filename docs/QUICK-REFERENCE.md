docs/QUICK-REFERENCE.md# Quick Reference Guide

## AWS CLI Quick Start (10 steps)

1. Create source bucket
   ```bash
   aws s3 mb s3://project-thumbnails-source
   ```

2. Create destination bucket
   ```bash
   aws s3 mb s3://project-thumbnails-dest
   ```

3. Create SNS topic
   ```bash
   aws sns create-topic --name project-thumbnails
   ```

4. Create IAM role
   ```bash
   aws iam create-role --role-name LambdaS3SNS \
     --assume-role-policy-document file://trust-policy.json
   ```

5. Attach policies
   ```bash
   aws iam attach-role-policy --role-name LambdaS3SNS \
     --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
   ```

6. Create Lambda function
   ```bash
   aws lambda create-function --function-name ThumbnailGenerator \
     --runtime python3.9 --role arn:aws:iam::ACCOUNT:role/LambdaS3SNS \
     --handler lambda_function.lambda_handler --zip-file fileb://function.zip
   ```

7. Configure S3 trigger
   ```bash
   aws s3api put-bucket-notification-configuration ...
   ```

8. Subscribe to SNS topic
   ```bash
   aws sns subscribe --topic-arn arn:aws:sns:region:account:topic \
     --protocol email --notification-endpoint your-email@example.com
   ```

9. Test upload
   ```bash
   aws s3 cp test-image.jpg s3://project-thumbnails-source/
   ```

10. Check Lambda logs
    ```bash
    aws logs tail /aws/lambda/ThumbnailGenerator --follow
    ```

## Terraform Deployment (5 minutes)

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Testing Methods

### Method 1: AWS Console
- Go to Lambda → Upload image via S3 console

### Method 2: AWS CLI
```bash
aws s3 cp image.jpg s3://bucket-source/
```

### Method 3: Local Testing
```bash
python lambda_function.py
```

### Method 4: S3 Trigger
- Upload image to S3 source bucket
- Check S3 destination for thumbnail

## Free Tier Monitoring

- **S3**: 5GB storage
- **Lambda**: 1M requests/month
- **SNS**: 1,000 emails/month

## Useful Commands

```bash
# List buckets
aws s3 ls

# List objects in bucket
aws s3 ls s3://bucket-name/

# Get Lambda function
aws lambda get-function --function-name ThumbnailGenerator

# Get CloudWatch logs
aws logs describe-log-streams --log-group-name /aws/lambda/ThumbnailGenerator

# Invoke Lambda
aws lambda invoke --function-name ThumbnailGenerator response.json

# Delete S3 bucket
aws s3 rm s3://bucket-name --recursive
aws s3api delete-bucket --bucket bucket-name

# Delete Lambda
aws lambda delete-function --function-name ThumbnailGenerator

# Delete SNS topic
aws sns delete-topic --topic-arn arn:aws:sns:region:account:topic
```

## Troubleshooting Quick Fixes

| Problem | Solution |
|---------|----------|
| Lambda timeout | Increase timeout: `aws lambda update-function-configuration --timeout 60` |
| Bucket name exists | Add random suffix: `bucket-name-$(date +%s)` |
| SNS no email | Confirm subscription in email inbox |
| Large images fail | Increase Lambda memory: `--memory-size 1024` |
| Permissions denied | Attach S3 and SNS policies to IAM role |

## Cost Estimation

- **1,000 images/month**: ~$0.40
- **10,000 images/month**: ~$4
- **100,000 images/month**: ~$40

## Next Steps

1. Read DEPLOYMENT.md for detailed guide
2. Review ARCHITECTURE.md for system design
3. Check lambda/ folder for Python code
4. See terraform/ folder for IaC

**Remember**: Always confirm SNS subscription!
