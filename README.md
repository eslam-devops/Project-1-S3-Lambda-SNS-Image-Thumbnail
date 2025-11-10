# Project 1: S3-Lambda-SNS Image Thumbnail Generator

**By: Islam Zain**

## Overview

A complete serverless image thumbnail generation pipeline using AWS services. This project demonstrates automatic image processing with event-driven architecture, including infrastructure-as-code, deployment scripts, and comprehensive documentation.

## 🎯 Key Features

✅ **Serverless Architecture** - No servers to manage
✅ **Event-Driven** - Automatic triggering on S3 image upload
✅ **Scalable** - Handles unlimited concurrent uploads
✅ **Cost-Effective** - Free Tier eligible
✅ **Secure** - IAM roles, encryption, public access blocked
✅ **Monitored** - CloudWatch logs and alarms
✅ **Production-Ready** - Best practices implemented
✅ **Infrastructure as Code** - Terraform for reproducibility
✅ **Well-Documented** - Complete guides and code comments
✅ **Error-Handled** - Comprehensive error handling and SNS notifications

## 📋 Project Structure

```
.
├── README.md                          # This file
├── ARCHITECTURE.md                    # Architecture diagrams and explanation
├── DEPLOYMENT.md                      # Deployment guide (Console, CLI, Terraform)
├── lambda/
│   ├── lambda-function.py            # Main Lambda function for image processing
│   ├── requirements.txt               # Python dependencies (Pillow, boto3)
│   └── config.py                      # Configuration constants
├── terraform/
│   ├── main.tf                        # Main Terraform configuration
│   ├── variables.tf                   # Variable definitions
│   ├── outputs.tf                     # Output values
│   ├── s3.tf                          # S3 bucket resources
│   ├── lambda.tf                      # Lambda function resources
│   ├── sns.tf                         # SNS topic resources
│   ├── iam.tf                         # IAM roles and policies
│   └── terraform.tfvars               # Variable values
├── scripts/
│   ├── deploy.sh                      # Automated deployment script
│   ├── test.sh                        # Testing script
│   └── cleanup.sh                     # Cleanup script
├── docs/
│   ├── lab-guide.md                   # Comprehensive lab guide
│   ├── quick-start.md                 # Quick reference guide
│   ├── troubleshooting.md             # Troubleshooting matrix
│   ├── cost-analysis.md               # Free Tier cost analysis
│   └── best-practices.md              # AWS best practices
├── tests/
│   ├── sample-images/                 # Sample images for testing
│   └── test-cases.md                  # Test scenarios
├── .gitignore
└── LICENSE
```

## 🏗️ Architecture

<img width="754" height="693" alt="image" src="https://github.com/user-attachments/assets/dd162c41-a584-4188-a590-da653adfa72f" />


```

<img width="754" height="693" alt="image" src="https://github.com/user-attachments/assets/3fa2c963-6dc9-48d9-938f-91acef2bfbf9" />

User Upload → S3 Source Bucket → Event Notification
                                       ↓
                              Lambda Function
                            (Image Processing)
                                       ↓
                           ┌───────────┴───────────┐
                           ↓                       ↓
                    S3 Thumbnail Bucket      SNS Topic
                                                   ↓
                                          Email Notification
```

## 🚀 Quick Start

### Prerequisites

- AWS Account
- AWS CLI configured
- Python 3.9+
- Terraform (for IaC deployment)
- Git

### Option 1: Automated Deployment (Recommended)

```bash
# Clone the repository
git clone https://github.com/eslam-devops/Project-1-S3-Lambda-SNS-Image-Thumbnail.git
cd Project-1-S3-Lambda-SNS-Image-Thumbnail

# Make deployment script executable
chmod +x scripts/deploy.sh

# Run automated deployment
./scripts/deploy.sh
```

### Option 2: Terraform Deployment

```bash
# Initialize Terraform
cd terraform
terraform init

# Review planned changes
terraform plan

# Apply configuration
terraform apply
```

### Option 3: AWS Console (Manual)

See `docs/lab-guide.md` for step-by-step instructions.

## 📦 What's Included

### Core Files

- **lambda/lambda-function.py** - Production-ready Lambda function with:
  - PIL image processing
  - Error handling and logging
  - SNS notifications (success & failure)
  - Metadata tagging
  - Support for JPG, JPEG, PNG formats

- **terraform/** - Complete IaC configuration:
  - S3 buckets with encryption and versioning
  - Lambda function with environment variables
  - SNS topic with email subscriptions
  - IAM roles with least privilege policies
  - CloudWatch alarms and monitoring

- **scripts/deploy.sh** - Automated deployment:
  - Prerequisite verification
  - Resource creation and configuration
  - Automatic testing
  - Summary output

### Documentation

- **ARCHITECTURE.md** - Detailed architecture explanation
- **docs/lab-guide.md** - 11-page comprehensive guide
- **docs/quick-start.md** - Quick reference commands
- **docs/cost-analysis.md** - Free Tier analysis
- **docs/troubleshooting.md** - Solutions for common issues

## 💻 How It Works

1. **Upload** - User uploads image to source S3 bucket
2. **Trigger** - S3 event notification triggers Lambda function
3. **Download** - Lambda retrieves original image from S3
4. **Process** - Lambda generates 200x200px thumbnail (JPEG, 80% quality)
5. **Upload** - Lambda uploads thumbnail to destination bucket
6. **Notify** - Lambda publishes message to SNS topic
7. **Email** - SNS sends email notification to subscribers

## 💰 Cost Analysis

| Scenario | S3 | Lambda | SNS | Total/Month |
|----------|----|---------|----|-------------|
| **10 images** | $0 | $0 | $0 | **$0** ✓ |
| **100 images** | $0 | $0 | $0 | **$0** ✓ |
| **1,000 images** | $0.10 | $0.30 | $0 | **~$0.40** ✓ |

**All scenarios are within AWS Free Tier limits!**

## 🔒 Security Features

- ✓ IAM roles with least privilege access
- ✓ S3 encryption at rest (AES-256)
- ✓ Public access blocked on S3 buckets
- ✓ Environment variables for sensitive data
- ✓ CloudWatch logs for audit trail
- ✓ Error handling prevents information leakage
- ✓ VPC endpoint ready (for advanced setup)

## 📊 Monitoring & Logging

- **CloudWatch Logs** - Lambda execution logs
- **CloudWatch Alarms** - SNS notification failures
- **S3 Metrics** - Bucket access patterns
- **Lambda Metrics** - Execution time, errors, throttling

## ⚠️ Important Notes

1. **Email Confirmation** - You MUST confirm SNS email subscription
2. **Bucket Names** - S3 bucket names must be globally unique
3. **Supported Formats** - JPG, JPEG, PNG only
4. **Free Tier** - Monitor usage to stay within Free Tier limits
5. **Cleanup** - Delete resources when done to avoid charges

## 📚 Learning Outcomes

After completing this project, you'll understand:

- AWS S3 event notifications and triggers
- Lambda function development and deployment
- IAM roles and least privilege access
- SNS topic management and subscriptions
- Python image processing (PIL/Pillow)
- CloudWatch logging and monitoring
- Serverless architecture patterns
- Infrastructure as Code with Terraform
- AWS Free Tier optimization

## 🔧 Troubleshooting

For common issues and solutions, see `docs/troubleshooting.md`

Quick troubleshooting:
- Lambda timeout? Increase timeout in configuration
- Bucket name conflict? Add random suffix to bucket names
- SNS not sending emails? Check subscription confirmation
- Large images failing? Increase Lambda memory allocation

## 📞 Next Steps

1. **Read** - Review architecture overview in `ARCHITECTURE.md`
2. **Deploy** - Choose deployment method and run scripts
3. **Test** - Upload test images to verify functionality
4. **Monitor** - Check CloudWatch logs and email notifications
5. **Extend** - Add features like multiple thumbnail sizes, formats, etc.

## 📜 License

MIT License - Free to use and modify

## 👨‍💻 Author

**Islam Zain**
- AWS Solutions Architecture Student
- DevOps & Cloud Engineer
- GitHub: [@eslam-devops](https://github.com/eslam-devops)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests.

## 📞 Support

For issues or questions:
1. Check `docs/troubleshooting.md`
2. Review `docs/quick-start.md`
3. Open an issue on GitHub

---

**Project Status**: ✅ Complete & Production-Ready

**Last Updated**: November 2025
