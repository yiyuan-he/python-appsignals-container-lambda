# [Public Documentation] Application Signals Set Up for Lambda with ECR Container Image (Python)

This guide focuses on how to properly integrate the OpenTelemetry Layer with AppSignals support into your containerized Python Lambda function.

## Why This Approach is Necessary

Lambda functions deployed as container images do not support Lambda Layers in the traditional way. When using container images, you cannot simply attach the layer as you would with other Lambda deployment methods. Instead, you must manually incorporate the layer’s contents into your container image during the build process.

This document outlines the necessary steps to download the `layer.zip` artifact and properly integrate it into your containerized Lambda function to enable AppSignals monitoring.

## Prerequisites

* AWS CLI configured with your credentials
* Docker installed
* These instructions assume you are on `x86_64` platform.

## 1. Set Up Project Structure

Create a directory for your Lambda function:

```console
mkdir python-appsignals-container-lambda && \
cd python-appsignals-container-lambda
```

## 2. Obtaining and Using the OpenTelemetry Layer with AppSignals Support

### Downloading and Integrating the Layer in Dockerfile

The most crucial step is downloading and integrating the OpenTelemetry Layer with AppSignals support directly in your Dockerfile:

```Dockerfile
# Dockerfile

FROM public.ecr.aws/lambda/python:3.13

# Copy function code
COPY app.py ${LAMBDA_TASK_ROOT}

# Install utilities
RUN dnf install -y unzip wget

# Download the OpenTelemetry Layer with AppSignals Support
RUN wget https://github.com/aws-observability/aws-otel-python-instrumentation/releases/latest/download/layer.zip -O /tmp/layer.zip

# Extract and include Lambda layer contents
RUN mkdir -p /opt && \
    unzip /tmp/layer.zip -d /opt/ && \
    chmod -R 755 /opt/ && \
    rm /tmp/layer.zip

# Set the CMD to your handler
CMD [ "app.lambda_handler" ]
```

> Note: The layer.zip file contains the OpenTelemetry instrumentation necessary for AWS AppSignals to monitor your Lambda function.

> Important: The layer extraction steps ensure that:
> 1. The layer.zip contents are properly extracted to the /opt/ directory
> 2. The otel-instrument script receives proper execution permissions
> 3. The temporary layer.zip file is removed to keep the image size smaller

## 3. Lambda Function Code

Create your Lambda function in an app.py file:

```python
import json
import boto3

def lambda_handler(event, context):
    """
    Sample Lambda function that can be used in a container image.

    Parameters:
    -----------
    event: dict
        Input event data
    context: LambdaContext
        Lambda runtime information

    Returns:
    __
    dict
        Response object
    """
    print("Received event:", json.dumps(event, indent=2))

    # Create S3 client
    s3 = boto3.client('s3')

    try:
        # List buckets
        response = s3.list_buckets()

        # Extract bucket names
        buckets = [bucket['Name'] for bucket in response['Buckets']]

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Successfully retrieved buckets',
                'buckets': buckets
            })
        }
    except Exception as e:
        print(f"Error listing buckets: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': f'Error listing buckets: {str(e)}'
            })
        }
```

## 4. Build and Deploy the Container Image

### Set up environment variables

```console
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text) 
AWS_REGION=$(aws configure get region)

# For fish shell users:
# set AWS_ACCOUNT_ID (aws sts get-caller-identity --query Account --output text) 
# set AWS_REGION (aws configure get region)
```

### Authenticate with ECR

First with public ECR (for base image):

```console
aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws
```

Then with your private ECR:

```console
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
```

### Create ECR repository (if needed)

```console
aws ecr create-repository \
    --repository-name lambda-appsignals-demo \
    --region $AWS_REGION
```

### Build, tag and push your image

```console
# Build the Docker image
docker build -t lambda-appsignals-demo .

# Tag the image
docker tag lambda-appsignals-demo:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/lambda-appsignals-demo:latest

# Push the image
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/lambda-appsignals-demo:latest
```

## 5. Create and Configure the Lambda Function

1. Go to AWS Lambda console and create a new function
2. Select **Container image** as the deployment option
3. Select your ECR image

### Critical AppSignals Configuration

The following steps are essential for the `layer.zip` integration to work:

* Add the environment variable:
    * Key: `AWS_LAMBDA_EXEC_WRAPPER`
    * Value: `/opt/otel-instrument`
    * This environment variable tells Lambda to use the `otel-instrument` wrapper script that was extracted from the `layer.zip` file to your container’s `/opt` directory.
* Attach required IAM policies:
    * **CloudWatchLambdaApplicationSignalsExecutionRolePolicy** - required for AppSignals
    * Additional policies for your function’s operations (e.g., S3 access policy for our example)

## 6. Testing and Verification

1. Test your Lambda function with a simple event
2. If the layer integration is successful, your Lambda will appear in the AppSignals service map
3. You should see traces and metrics for your Lambda function in the CloudWatch console.

## Troubleshooting Layer Integration

If AppSignals isn’t working:

1. Check the function logs for any errors related to the OpenTelemetry instrumentation
2. Verify the environment variable `AWS_LAMBDA_EXEC_WRAPPER` is set correctly
3. Ensure the layer extraction in the Dockerfile completed successfully
4. Confirm the IAM permissions are properly attached


