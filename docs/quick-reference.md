# Project 1: Quick Reference Guide
## S3 → Lambda → SNS Thumbnail Generation Pipeline
### By: Islam Zain

---

## 🎯 PROJECT OVERVIEW

| Aspect | Details |
|--------|---------|
| **Objective** | Automatically generate image thumbnails when images are uploaded to S3 |
| **Architecture** | Serverless (S3 → Lambda → S3 + SNS) |
| **Cost** | Free Tier eligible (~$0-2/month for light usage) |
| **Estimated Setup Time** | 30-45 minutes |
| **Skill Level** | Intermediate |

---

## 📋 PRE-DEPLOYMENT CHECKLIST

- [ ] AWS Account created and verified
- [ ] AWS CLI installed and configured
- [ ] Python 3.9+ installed locally
- [ ] Email address ready for SNS subscription
- [ ] Unique bucket names noted (must be globally unique)
- [ ] Terraform installed (optional but recommended)
- [ ] Git or file storage for code backup

---

## ⚡ QUICK START (MANUAL SETUP - 10 STEPS)

### Step 1: Create Source S3 Bucket
```bash
aws s3 mb s3://project1-images-source-$(aws sts get-caller-identity --query Account --output text) --region us-east-1
```

### Step 2: Create Destination S3 Bucket
```bash
aws s3 mb s3://project1-thumbnails-dest-$(aws sts get-caller-identity --query Account --output text) --region us-east-1
```

### Step 3: Create SNS Topic
```bash
TOPIC_ARN=$(aws sns create-topic --name project1-image-processing --region us-east-1 --query 'TopicArn' --output text)
echo $TOPIC_ARN
```

### Step 4: Subscribe Email to SNS
```bash
aws sns subscribe --topic-arn $TOPIC_ARN --protocol email --notification-endpoint your-email@example.com
# Check email and confirm subscription!
```

### Step 5: Create IAM Role for Lambda
```bash
aws iam create-role \
  --role-name project1-lambda-s3-sns-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {"Service": "lambda.amazonaws.com"},
        "Action": "sts:AssumeRole"
      }
    ]
  }'
```

### Step 6: Attach Basic Execution Policy
```bash
aws iam attach-role-policy \
  --role-name project1-lambda-s3-sns-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

### Step 7: Create Custom S3+SNS Policy
```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)

aws iam put-role-policy \
  --role-name project1-lambda-s3-sns-role \
  --policy-name project1-lambda-inline-policy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": ["s3:GetObject"],
        "Resource": "arn:aws:s3:::project1-images-source-'$ACCOUNT_ID'/*"
      },
      {
        "Effect": "Allow",
        "Action": ["s3:PutObject"],
        "Resource": "arn:aws:s3:::project1-thumbnails-dest-'$ACCOUNT_ID'/*"
      },
      {
        "Effect": "Allow",
        "Action": ["sns:Publish"],
        "Resource": "'$TOPIC_ARN'"
      }
    ]
  }'
```

### Step 8: Package Lambda Function
```bash
# Create deployment directory
mkdir project1-lambda
cd project1-lambda

# Copy lambda function code
cp ../lambda-function.py index.py

# Create requirements.txt
echo "Pillow==10.0.0" > requirements.txt

# Install dependencies (with Pillow)
pip install -r requirements.txt -t .

# Create zip deployment package
zip -r ../lambda_function.zip . -x "*.git*"

cd ..
```

### Step 9: Create Lambda Function
```bash
ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/project1-lambda-s3-sns-role"

aws lambda create-function \
  --function-name project1-thumbnail-generator \
  --runtime python3.11 \
  --role $ROLE_ARN \
  --handler index.lambda_handler \
  --zip-file fileb://lambda_function.zip \
  --timeout 30 \
  --memory-size 512 \
  --environment Variables="{THUMBNAIL_BUCKET=project1-thumbnails-dest-$ACCOUNT_ID,SNS_TOPIC_ARN=$TOPIC_ARN}" \
  --region $REGION
```

### Step 10: Configure S3 Trigger
```bash
LAMBDA_ARN="arn:aws:lambda:$REGION:$ACCOUNT_ID:function:project1-thumbnail-generator"

# Add permission for S3 to invoke Lambda
aws lambda add-permission \
  --function-name project1-thumbnail-generator \
  --statement-id AllowS3Invoke \
  --action lambda:InvokeFunction \
  --principal s3.amazonaws.com \
  --source-arn arn:aws:s3:::project1-images-source-$ACCOUNT_ID \
  --region $REGION

# Create S3 bucket notification configuration
aws s3api put-bucket-notification-configuration \
  --bucket project1-images-source-$ACCOUNT_ID \
  --notification-configuration '{
    "LambdaFunctionConfigurations": [
      {
        "LambdaFunctionArn": "'$LAMBDA_ARN'",
        "Events": ["s3:ObjectCreated:*"],
        "Filter": {
          "Key": {
            "FilterRules": [
              {
                "Name": "suffix",
                "Value": ".jpg"
              },
              {
                "Name": "suffix",
                "Value": ".png"
              }
            ]
          }
        }
      }
    ]
  }' \
  --region $REGION
```

---

## 🚀 ALTERNATIVE: TERRAFORM SETUP (5 MINUTES)

```bash
# 1. Create terraform working directory
mkdir terraform-project1
cd terraform-project1

# 2. Copy terraform files
cp ../terraform-config.tf .
cp ../lambda-function.py index.py

# 3. Create variables.tfvars
cat > terraform.tfvars <<EOF
aws_region    = "us-east-1"
project_name  = "project1"
sns_email     = "your-email@example.com"
EOF

# 4. Package Lambda code
pip install -r requirements.txt -t .
zip -r lambda_function.zip . -x "*.git*" "*.tf"

# 5. Initialize Terraform
terraform init

# 6. Plan deployment
terraform plan

# 7. Apply configuration
terraform apply
```

---

## 🧪 TESTING THE PIPELINE

### Test 1: Upload Image via AWS Console
1. Go to S3 → project1-images-source
2. Click "Upload"
3. Select a JPEG or PNG image
4. Wait 30 seconds
5. Check project1-thumbnails-dest → Should see thumbnail
6. Check email → Should have SNS notification

### Test 2: Upload via AWS CLI
```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3 cp ./test-image.jpg s3://project1-images-source-$ACCOUNT_ID/
```

### Test 3: Check CloudWatch Logs
```bash
aws logs tail /aws/lambda/project1-thumbnail-generator --follow
```

### Test 4: Verify Thumbnail Quality
```bash
aws s3 cp s3://project1-thumbnails-dest-$ACCOUNT_ID/test-image_thumb.jpg ./
identify test-image_thumb.jpg  # Shows image info
```

---

## 📊 FREE TIER LIMITS & MONITORING

| Service | Monthly Free | Your Usage | Status |
|---------|-------------|-----------|--------|
| S3 Storage | 5 GB | ✓ OK | Within limit |
| S3 Requests | 20,000 | ✓ OK | ~200 (10 images) |
| Lambda | 1M requests | ✓ OK | ~10 (10 images) |
| SNS Emails | 1,000 | ✓ OK | ~10 |

**Monitoring:**
```bash
# Check Lambda metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=project1-thumbnail-generator \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Average
```

---

## 🛠️ TROUBLESHOOTING

| Problem | Solution |
|---------|----------|
| **Lambda timeout (>3s)** | Increase timeout to 30s in Lambda settings |
| **"AccessDenied" error** | Verify IAM role has S3 and SNS permissions |
| **Pillow import error** | Ensure lambda_function.zip includes PIL dependencies |
| **No email received** | Confirm SNS subscription in email inbox |
| **Thumbnail not created** | Check file format (.jpg, .png), check CloudWatch logs |
| **"Bucket does not exist"** | Verify bucket names match in Lambda env variables |

**Debug Commands:**
```bash
# View Lambda logs
aws logs tail /aws/lambda/project1-thumbnail-generator --follow

# Test Lambda directly
aws lambda invoke \
  --function-name project1-thumbnail-generator \
  --payload file://test-event.json \
  response.json
cat response.json

# Verify S3 trigger
aws s3api get-bucket-notification-configuration \
  --bucket project1-images-source-$ACCOUNT_ID

# Check IAM permissions
aws iam get-role-policy \
  --role-name project1-lambda-s3-sns-role \
  --policy-name project1-lambda-inline-policy
```

---

## 📈 COST ESTIMATION

| Operation | Free Tier | Beyond | Notes |
|-----------|-----------|--------|-------|
| 10 images/month | $0 | $0 | Well within limits |
| 100 images/month | $0 | $0.10 | Lambda + S3 |
| 1000 images/month | $0.50 | $1.00 | Mostly Lambda |

**Cost Optimization:**
- Keep images < 5MB
- Use 200x200 thumbnail size
- Clean up old images monthly
- Use S3 lifecycle policies

---

## 🔐 SECURITY BEST PRACTICES

✓ **DO:**
- Use IAM roles with least privilege
- Enable S3 versioning
- Enable S3 encryption
- Monitor CloudWatch logs
- Use SNS for error alerts

✗ **DON'T:**
- Hardcode credentials
- Use wildcard (*) in IAM policies
- Make S3 buckets public
- Ignore CloudWatch alarms
- Upload sensitive images without encryption

---

## 📝 USEFUL COMMANDS

```bash
# Get all project resources
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Source Bucket: project1-images-source-$ACCOUNT_ID"
echo "Dest Bucket: project1-thumbnails-dest-$ACCOUNT_ID"
aws lambda get-function --function-name project1-thumbnail-generator
aws sns list-topics | grep project1
aws iam get-role --role-name project1-lambda-s3-sns-role

# Clean up all resources (caution!)
# aws s3 rm s3://project1-images-source-$ACCOUNT_ID --recursive
# aws s3 rb s3://project1-images-source-$ACCOUNT_ID
# aws s3 rm s3://project1-thumbnails-dest-$ACCOUNT_ID --recursive
# aws s3 rb s3://project1-thumbnails-dest-$ACCOUNT_ID
# aws lambda delete-function --function-name project1-thumbnail-generator
# aws sns delete-topic --topic-arn $TOPIC_ARN
# aws iam delete-role-policy --role-name project1-lambda-s3-sns-role --policy-name project1-lambda-inline-policy
# aws iam delete-role --role-name project1-lambda-s3-sns-role
```

---

## 📚 LEARNING RESOURCES

1. **AWS Documentation:**
   - Lambda with S3: https://docs.aws.amazon.com/lambda/latest/dg/services-s3.html
   - S3 Event Notifications: https://docs.aws.amazon.com/AmazonS3/latest/userguide/EventNotifications.html

2. **Python Libraries:**
   - Pillow (PIL): Image processing
   - boto3: AWS SDK

3. **Architecture Patterns:**
   - Fan-out messaging
   - Event-driven architecture
   - Serverless image processing

---

## 🎓 WHAT YOU'VE LEARNED

After completing this project, you understand:
- ✓ S3 event notifications and triggers
- ✓ Lambda function deployment and environment variables
- ✓ IAM roles and least privilege access
- ✓ SNS topic subscriptions and notifications
- ✓ Image processing with Python (PIL/Pillow)
- ✓ CloudWatch logging and monitoring
- ✓ Serverless architecture patterns
- ✓ AWS CLI scripting and automation
- ✓ Terraform infrastructure as code

---

## 🚀 NEXT STEPS

1. **Extend to multiple thumbnail sizes** (small, medium, large)
2. **Add image format conversion** (to WebP for compression)
3. **Implement DynamoDB logging** to track all processed images
4. **Add CloudFront distribution** for serving thumbnails globally
5. **Create Lambda@Edge** for on-the-fly image resizing
6. **Set up automated testing** with test images
7. **Implement advanced monitoring** with CloudWatch dashboards
8. **Add image metadata extraction** (EXIF data)
9. **Create REST API** with API Gateway
10. **Deploy multi-region** for disaster recovery

---

**Project 1 Complete! 🎉**
*Created by: Islam Zain*
*Date: 2025*