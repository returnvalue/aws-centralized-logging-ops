# AWS Centralized Logging Ops Lab

This lab demonstrates a mission-critical observability pattern for the **AWS SysOps Administrator Associate**: building an automated pipeline for centralized log aggregation and archival.

## Architecture Overview

The system implements a real-time log delivery pipeline:

1.  **Ingestion:** A CloudWatch Log Group (`/aws/sysops-lab/centralized-logs`) serves as the entry point for all log data.
2.  **Streaming:** A Log Subscription Filter captures all log events and forwards them to a Kinesis Data Firehose delivery stream.
3.  **Delivery:** Kinesis Data Firehose buffers the incoming log data and delivers it to a persistent S3 bucket.
4.  **Persistence:** An S3 bucket (`centralized-log-archive-bucket`) provides long-term, durable storage for all centralized logs.

## Key Components

-   **CloudWatch Log Group:** Primary collection point for log events.
-   **Kinesis Data Firehose:** Managed delivery stream configured with S3 as the destination.
-   **IAM Roles & Policies:**
    -   `cw-to-firehose-role`: Allows CloudWatch to push data to Firehose.
    -   `firehose-role`: Allows Firehose to write objects to the S3 archive bucket.
-   **Subscription Filter:** The logic that connects the Log Group to the Firehose stream.

## Prerequisites

-   [Terraform](https://www.terraform.io/downloads.html)
-   [LocalStack](https://localstack.cloud/)
-   [AWS CLI / awslocal](https://github.com/localstack/awscli-local)

## Deployment

1.  **Initialize and Apply:**
    ```bash
    terraform init
    terraform apply -auto-approve
    ```

## Verification & Testing

To test the end-to-end logging pipeline:

1.  **Put a Log Event into CloudWatch:**
    ```bash
    awslocal logs put-log-events \
      --log-group-name /aws/sysops-lab/centralized-logs \
      --log-stream-name test-stream \
      --log-events timestamp=$(date +%s000),message="Test log message for centralization"
    ```

2.  **Wait for Firehose Delivery:**
    Firehose buffers data (default 300 seconds or 5MB). In LocalStack, you can check the S3 bucket after a short delay:
    ```bash
    awslocal s3 ls s3://centralized-log-archive-bucket --recursive
    ```

3.  **Confirm Log Data in S3:**
    Download and inspect a log file from the archival bucket to verify the content.

## Cleanup

To tear down the infrastructure:
```bash
terraform destroy -auto-approve
```
