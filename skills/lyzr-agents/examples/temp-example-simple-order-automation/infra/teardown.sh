#!/usr/bin/env bash
# Removes ONLY the temp-example-simple-order-automation-* resources this demo created.
# Usage: bash teardown.sh [aws_profile]   (default: dev)
set -uo pipefail
PROFILE="${1:-dev}"; REGION="us-east-1"; PREFIX="temp-example-simple-order-automation"
export AWS_PROFILE="$PROFILE" AWS_DEFAULT_REGION="$REGION"

API_ID="$(aws apigatewayv2 get-apis --query "Items[?Name=='${PREFIX}-api'].ApiId | [0]" --output text 2>/dev/null)"
[ -n "$API_ID" ] && [ "$API_ID" != "None" ] && { aws apigatewayv2 delete-api --api-id "$API_ID" && echo "deleted api $API_ID"; }

for s in inventory restock orders; do
  aws lambda delete-function --function-name "$PREFIX-$s" 2>/dev/null && echo "deleted lambda $PREFIX-$s" || true
done

ROLE="$PREFIX-lambda-role"
aws iam delete-role-policy --role-name "$ROLE" --policy-name ddb 2>/dev/null || true
aws iam detach-role-policy --role-name "$ROLE" --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true
aws iam delete-role --role-name "$ROLE" 2>/dev/null && echo "deleted role $ROLE" || true

for t in "$PREFIX-inventory" "$PREFIX-orders"; do
  aws dynamodb delete-table --table-name "$t" >/dev/null 2>&1 && echo "deleted table $t" || true
done
echo "teardown complete."
