#!/bin/bash
# Project 1: Automated Deployment Script
# File: deploy.sh
# By: Islam Zain
# Description: Complete automated deployment of S3 → Lambda → SNS pipeline

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project configuration
PROJECT_NAME="project1"
REGION="${AWS_REGION:-us-east-1}"
THUMBNAIL_BUCKET="${PROJECT_NAME}-thumbnails"
IMAGE_BUCKET="${PROJECT_NAME}-images"
LAMBDA_FUNCTION="${PROJECT_NAME}-thumbnail-generator"
SNS_TOPIC="${PROJECT_NAME}-image-processing"
LAMBDA_ROLE="${PROJECT_NAME}-lambda-s3-sns-role"

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}Error: Unable to get AWS Account ID. Check AWS credentials.${NC}"
    exit 1
fi

# Add account ID to bucket names for global uniqueness
SOURCE_BUCKET="${IMAGE_BUCKET}-source-${ACCOUNT_ID}"
DEST_BUCKET="${THUMBNAIL_BUCKET}-dest-${ACCOUNT_ID}"

# Functions
print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
}

print_step() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Verification functions
verify_prerequisites() {
    print_header "Verifying Prerequisites"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI not found. Please install it."
        exit 1
    fi
    print_step "AWS CLI found: $(aws --version)"
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 not found. Please install it."
        exit 1
    fi
    print_step "Python 3 found: $(python3 --version)"
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Run 'aws configure'"
        exit 1
    fi
    print_step "AWS credentials verified for Account: $ACCOUNT_ID"
    
    # Check zip command
    if ! command -v zip &> /dev/null; then
        print_error "zip command not found. Please install it."
        exit 1
    fi
    print_step "zip command found"
}

# S3 Bucket Creation
create_s3_buckets() {
    print_header "Creating S3 Buckets"
    
    # Check if source bucket exists
    if aws s3 ls "s3://${SOURCE_BUCKET}" 2>&1 | grep -q 'NoSuchBucket'; then
        print_warning "Source bucket does not exist. Creating..."
        aws s3 mb "s3://${SOURCE_BUCKET}" --region "$REGION"
        print_step "Source bucket created: $SOURCE_BUCKET"
    else
        print_warning "Source bucket already exists: $SOURCE_BUCKET"
    fi
    
    # Check if destination bucket exists
    if aws s3 ls "s3://${DEST_BUCKET}" 2>&1 | grep -q 'NoSuchBucket'; then
        print_warning "Destination bucket does not exist. Creating..."
        aws s3 mb "s3://${DEST_BUCKET}" --region "$REGION"
        print_step "Destination bucket created: $DEST_BUCKET"
    else
        print_warning "Destination bucket already exists: $DEST_BUCKET"
    fi
    
    # Block public access
    aws s3api put-public-access-block \
        --bucket "$SOURCE_BUCKET" \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
        2>/dev/null || true
    
    aws s3api put-public-access-block \
        --bucket "$DEST_BUCKET" \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
        2>/dev/null || true
    
    print_step "Public access blocked on both buckets"
    
    # Enable versioning
    aws s3api put-bucket-versioning --bucket "$SOURCE_BUCKET" --versioning-configuration Status=Enabled 2>/dev/null || true
    aws s3api put-bucket-versioning --bucket "$DEST_BUCKET" --versioning-configuration Status=Enabled 2>/dev/null || true
    
    print_step "Versioning enabled on both buckets"
    
    # Enable encryption
    aws s3api put-bucket-encryption --bucket "$SOURCE_BUCKET" \
        --server-side-encryption-configuration '{
            "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
        }' 2>/dev/null || true
    
    aws s3api put-bucket-encryption --bucket "$DEST_BUCKET" \
        --server-side-encryption-configuration '{
            "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
        }' 2>/dev/null || true
    
    print_step "Encryption enabled on both buckets"
}

# SNS Topic Creation
create_sns_topic() {
    print_header "Creating SNS Topic"
    
    TOPIC_ARN=$(aws sns create-topic \
        --name "$SNS_TOPIC" \
        --region "$REGION" \
        --query 'TopicArn' \
        --output text)
    
    print_step "SNS topic created: $TOPIC_ARN"
    
    # Ask for email
    read -p "Enter email address for notifications: " EMAIL
    
    if [ -z "$EMAIL" ]; then
        print_error "Email not provided. Skipping subscription."
    else
        # Subscribe email to topic
        SUBSCRIPTION_ARN=$(aws sns subscribe \
            --topic-arn "$TOPIC_ARN" \
            --protocol email \
            --notification-endpoint "$EMAIL" \
            --region "$REGION" \
            --query 'SubscriptionArn' \
            --output text)
        
        print_step "Email subscribed to topic: $EMAIL"
        print_warning "Please check your email and confirm the subscription!"
    fi
}

# IAM Role Creation
create_iam_role() {
    print_header "Creating IAM Role"
    
    # Create role
    aws iam create-role \
        --role-name "$LAMBDA_ROLE" \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": {"Service": "lambda.amazonaws.com"},
                "Action": "sts:AssumeRole"
            }]
        }' 2>/dev/null || print_warning "Role already exists"
    
    print_step "IAM role created/verified: $LAMBDA_ROLE"
    
    # Attach basic execution policy
    aws iam attach-role-policy \
        --role-name "$LAMBDA_ROLE" \
        --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true
    
    print_step "CloudWatch Logs policy attached"
    
    # Create and attach custom policy
    POLICY_DOCUMENT=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::${SOURCE_BUCKET}/*"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject"],
      "Resource": "arn:aws:s3:::${DEST_BUCKET}/*"
    },
    {
      "Effect": "Allow",
      "Action": ["sns:Publish"],
      "Resource": "${TOPIC_ARN}"
    }
  ]
}
EOF
)
    
    aws iam put-role-policy \
        --role-name "$LAMBDA_ROLE" \
        --policy-name "${PROJECT_NAME}-inline-policy" \
        --policy-document "$POLICY_DOCUMENT"
    
    print_step "Custom S3 and SNS policy attached"
    
    # Get role ARN
    ROLE_ARN=$(aws iam get-role --role-name "$LAMBDA_ROLE" --query 'Role.Arn' --output text)
    echo "$ROLE_ARN"
}

# Lambda Function Packaging
package_lambda() {
    print_header "Packaging Lambda Function"
    
    # Create build directory
    BUILD_DIR="lambda_build"
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
        print_step "Cleaned existing build directory"
    fi
    
    mkdir -p "$BUILD_DIR"
    print_step "Created build directory"
    
    # Copy Lambda function
    if [ ! -f "lambda-function.py" ]; then
        print_error "lambda-function.py not found in current directory"
        exit 1
    fi
    
    cp lambda-function.py "$BUILD_DIR/index.py"
    print_step "Copied Lambda function code"
    
    # Install dependencies
    pip install -q Pillow boto3 -t "$BUILD_DIR/" 2>/dev/null
    print_step "Installed Python dependencies"
    
    # Create zip file
    cd "$BUILD_DIR"
    zip -r -q ../lambda_function.zip . -x "*.git*"
    cd ..
    
    print_step "Created deployment package: lambda_function.zip"
    
    # Show file size
    SIZE=$(du -h lambda_function.zip | cut -f1)
    print_step "Package size: $SIZE"
}

# Lambda Function Creation
create_lambda_function() {
    print_header "Creating Lambda Function"
    
    if [ ! -f "lambda_function.zip" ]; then
        print_error "lambda_function.zip not found. Run package_lambda first."
        exit 1
    fi
    
    # Sleep to ensure role is created
    sleep 5
    
    # Create function
    LAMBDA_ARN=$(aws lambda create-function \
        --function-name "$LAMBDA_FUNCTION" \
        --runtime python3.11 \
        --role "$ROLE_ARN" \
        --handler index.lambda_handler \
        --zip-file fileb://lambda_function.zip \
        --timeout 30 \
        --memory-size 512 \
        --environment "Variables={THUMBNAIL_BUCKET=${DEST_BUCKET},SNS_TOPIC_ARN=${TOPIC_ARN}}" \
        --region "$REGION" \
        --query 'FunctionArn' \
        --output text 2>/dev/null) || \
    LAMBDA_ARN=$(aws lambda get-function-by-name \
        --function-name "$LAMBDA_FUNCTION" \
        --query 'Configuration.FunctionArn' \
        --output text 2>/dev/null)
    
    print_step "Lambda function created: $LAMBDA_FUNCTION"
    
    # Update function code if it already existed
    if [ $? -ne 0 ]; then
        aws lambda update-function-code \
            --function-name "$LAMBDA_FUNCTION" \
            --zip-file fileb://lambda_function.zip \
            --region "$REGION" > /dev/null 2>&1
        print_step "Updated existing Lambda function code"
    fi
}

# Configure S3 Trigger
configure_s3_trigger() {
    print_header "Configuring S3 Trigger"
    
    # Add Lambda permission for S3
    aws lambda add-permission \
        --function-name "$LAMBDA_FUNCTION" \
        --statement-id AllowS3Invoke \
        --action lambda:InvokeFunction \
        --principal s3.amazonaws.com \
        --source-arn "arn:aws:s3:::${SOURCE_BUCKET}" \
        --region "$REGION" 2>/dev/null || print_warning "Permission might already exist"
    
    print_step "S3 → Lambda permission configured"
    
    # Create S3 notification configuration
    NOTIFICATION_CONFIG=$(cat <<EOF
{
  "LambdaFunctionConfigurations": [
    {
      "LambdaFunctionArn": "${LAMBDA_ARN}",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            {"Name": "suffix", "Value": ".jpg"},
            {"Name": "suffix", "Value": ".jpeg"},
            {"Name": "suffix", "Value": ".png"}
          ]
        }
      }
    }
  ]
}
EOF
)
    
    aws s3api put-bucket-notification-configuration \
        --bucket "$SOURCE_BUCKET" \
        --notification-configuration "$NOTIFICATION_CONFIG" \
        --region "$REGION"
    
    print_step "S3 bucket notification configured for image uploads"
}

# Test Function
test_deployment() {
    print_header "Testing Deployment"
    
    # Create test event
    TEST_EVENT=$(cat <<EOF
{
  "Records": [
    {
      "s3": {
        "bucket": {"name": "${SOURCE_BUCKET}"},
        "object": {"key": "test-image.jpg"}
      }
    }
  ]
}
EOF
)
    
    echo "$TEST_EVENT" > test-event.json
    
    # Invoke function with test event
    RESULT=$(aws lambda invoke \
        --function-name "$LAMBDA_FUNCTION" \
        --payload file://test-event.json \
        --region "$REGION" \
        /tmp/lambda-response.json 2>&1)
    
    print_step "Test invocation completed"
    
    # Show response
    if [ -f /tmp/lambda-response.json ]; then
        echo "Response:"
        cat /tmp/lambda-response.json | python3 -m json.tool 2>/dev/null || cat /tmp/lambda-response.json
    fi
}

# Display Summary
display_summary() {
    print_header "Deployment Summary"
    
    echo -e "${BLUE}Project Configuration:${NC}"
    echo "  Project Name: $PROJECT_NAME"
    echo "  AWS Region: $REGION"
    echo "  AWS Account ID: $ACCOUNT_ID"
    
    echo -e "\n${BLUE}S3 Buckets:${NC}"
    echo "  Source: $SOURCE_BUCKET"
    echo "  Destination: $DEST_BUCKET"
    
    echo -e "\n${BLUE}Lambda Function:${NC}"
    echo "  Name: $LAMBDA_FUNCTION"
    echo "  ARN: $LAMBDA_ARN"
    echo "  Runtime: Python 3.11"
    echo "  Memory: 512 MB"
    echo "  Timeout: 30 seconds"
    
    echo -e "\n${BLUE}SNS Topic:${NC}"
    echo "  Name: $SNS_TOPIC"
    echo "  ARN: $TOPIC_ARN"
    
    echo -e "\n${BLUE}IAM Role:${NC}"
    echo "  Name: $LAMBDA_ROLE"
    echo "  ARN: $ROLE_ARN"
    
    echo -e "\n${GREEN}✓ Deployment completed successfully!${NC}"
    
    echo -e "\n${YELLOW}Next Steps:${NC}"
    echo "  1. Confirm SNS email subscription"
    echo "  2. Upload an image to: s3://${SOURCE_BUCKET}/"
    echo "  3. Check S3 destination bucket for thumbnail: s3://${DEST_BUCKET}/"
    echo "  4. Check email for SNS notification"
    echo "  5. View logs: aws logs tail /aws/lambda/${LAMBDA_FUNCTION} --follow"
    
    echo -e "\n${YELLOW}Cleanup (when done):${NC}"
    echo "  aws s3 rm s3://${SOURCE_BUCKET} --recursive"
    echo "  aws s3 rb s3://${SOURCE_BUCKET}"
    echo "  aws s3 rm s3://${DEST_BUCKET} --recursive"
    echo "  aws s3 rb s3://${DEST_BUCKET}"
    echo "  aws lambda delete-function --function-name ${LAMBDA_FUNCTION}"
    echo "  aws sns delete-topic --topic-arn ${TOPIC_ARN}"
    echo "  aws iam delete-role-policy --role-name ${LAMBDA_ROLE} --policy-name ${PROJECT_NAME}-inline-policy"
    echo "  aws iam delete-role --role-name ${LAMBDA_ROLE}"
}

# Main Execution
main() {
    print_header "Project 1: Automated Deployment"
    echo "S3 → Lambda → SNS Image Thumbnail Pipeline"
    echo "By: Islam Zain"
    
    verify_prerequisites
    create_s3_buckets
    create_sns_topic
    ROLE_ARN=$(create_iam_role)
    package_lambda
    create_lambda_function
    configure_s3_trigger
    
    echo ""
    print_warning "Waiting 10 seconds for Lambda to be ready..."
    sleep 10
    
    test_deployment
    display_summary
}

# Run main function
main