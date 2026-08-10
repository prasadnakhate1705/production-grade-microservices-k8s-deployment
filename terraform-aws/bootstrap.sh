#!/usr/bin/env bash
#
# ONE-TIME BOOTSTRAP — creates the S3 bucket that holds Terraform state.
#
# Chicken-and-egg: Terraform's backend must exist before `terraform init` can
# run, so this bucket cannot be managed by the same Terraform stack that uses
# it. Hence a plain script. Run it once, then never again.
#
# Locking needs NO DynamoDB table. The backend uses S3 native locking
# (use_lockfile = true, Terraform >= 1.11): Terraform PUTs a <key>.tflock object
# with If-None-Match, which S3 rejects atomically if the lock is already held.
# Versioning is what makes that safe, so it is enabled below and is REQUIRED.
#
# Usage:  bash terraform-aws/bootstrap.sh
# Safe to re-run — every step is idempotent.

set -euo pipefail

BUCKET="microservicesdemo-prasad-tfstate" # must match backend "s3" in providers.tf
REGION="us-east-1"

echo "── Account: $(aws sts get-caller-identity --query Account --output text)"
echo "── Bucket:  ${BUCKET} (${REGION})"

# ── 1. Create the bucket ─────────────────────────────────────────────────────
# us-east-1 is the one region that must NOT pass a LocationConstraint.
if aws s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
  echo "── Bucket already exists, skipping create."
else
  echo "── Creating bucket..."
  if [ "${REGION}" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}"
  else
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}" \
      --create-bucket-configuration "LocationConstraint=${REGION}"
  fi
fi

# ── 2. Versioning — REQUIRED ─────────────────────────────────────────────────
# Gives you a recoverable history of every state file, which is the difference
# between "restore yesterday's state" and "rebuild the cluster from scratch".
echo "── Enabling versioning..."
aws s3api put-bucket-versioning \
  --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled

# ── 3. Encryption at rest ────────────────────────────────────────────────────
# State files contain resource IDs, endpoints and occasionally secrets in plain
# text, so this is not optional in any shared account.
echo "── Enabling default encryption (AES256)..."
aws s3api put-bucket-encryption \
  --bucket "${BUCKET}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm": "AES256" },
      "BucketKeyEnabled": true
    }]
  }'

# ── 4. Block ALL public access ───────────────────────────────────────────────
echo "── Blocking public access..."
aws s3api put-public-access-block \
  --bucket "${BUCKET}" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# ── 5. Expire old state versions after 90 days ───────────────────────────────
# Versioning keeps every write forever otherwise; state files are small but this
# keeps the bucket tidy without giving up a useful recovery window.
echo "── Applying lifecycle policy (expire noncurrent versions after 90 days)..."
aws s3api put-bucket-lifecycle-configuration \
  --bucket "${BUCKET}" \
  --lifecycle-configuration '{
    "Rules": [{
      "ID": "expire-old-state-versions",
      "Status": "Enabled",
      "Filter": { "Prefix": "" },
      "NoncurrentVersionExpiration": { "NoncurrentDays": 90 },
      "AbortIncompleteMultipartUpload": { "DaysAfterInitiation": 7 }
    }]
  }'

echo
echo "── Bootstrap complete. Now run:"
echo "     cd terraform-aws && terraform init"
