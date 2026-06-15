#!/usr/bin/env bash
# Deploys the "temp example simple order automation" stack to AWS:
#   DynamoDB (inventory + orders), 3 Lambdas, a public no-auth HTTP API Gateway, seeded stock.
# Everything is prefixed temp-example-simple-order-automation-* and creates ONLY new resources.
# Usage: bash deploy.sh [aws_profile]   (default profile: dev)   Region: us-east-1
set -euo pipefail
PROFILE="${1:-dev}"; REGION="us-east-1"
PREFIX="temp-example-simple-order-automation"
HERE="$(cd "$(dirname "$0")" && pwd)"
export AWS_PROFILE="$PROFILE" AWS_DEFAULT_REGION="$REGION"

INV_TABLE="${PREFIX}-inventory"; ORD_TABLE="${PREFIX}-orders"; ROLE="${PREFIX}-lambda-role"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
echo ">> account=$ACCOUNT region=$REGION profile=$PROFILE"

echo ">> DynamoDB tables"
for pair in "$INV_TABLE:sku" "$ORD_TABLE:order_id"; do
  name="${pair%%:*}"; key="${pair##*:}"
  aws dynamodb describe-table --table-name "$name" >/dev/null 2>&1 || {
    aws dynamodb create-table --table-name "$name" \
      --attribute-definitions "AttributeName=$key,AttributeType=S" \
      --key-schema "AttributeName=$key,KeyType=HASH" \
      --billing-mode PAY_PER_REQUEST >/dev/null
    echo "   created $name"; }
done
aws dynamodb wait table-exists --table-name "$INV_TABLE"
aws dynamodb wait table-exists --table-name "$ORD_TABLE"

echo ">> IAM role"
if ! aws iam get-role --role-name "$ROLE" >/dev/null 2>&1; then
  aws iam create-role --role-name "$ROLE" --assume-role-policy-document \
    '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' >/dev/null
  aws iam attach-role-policy --role-name "$ROLE" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
  aws iam put-role-policy --role-name "$ROLE" --policy-name ddb --policy-document \
    "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"dynamodb:GetItem\",\"dynamodb:PutItem\",\"dynamodb:UpdateItem\"],\"Resource\":[\"arn:aws:dynamodb:$REGION:$ACCOUNT:table/$INV_TABLE\",\"arn:aws:dynamodb:$REGION:$ACCOUNT:table/$ORD_TABLE\"]}]}"
  echo "   created $ROLE (waiting 12s for IAM propagation)"; sleep 12
fi
ROLE_ARN="$(aws iam get-role --role-name "$ROLE" --query Role.Arn --output text)"

echo ">> Lambdas"
deploy_fn () {
  local fn="$PREFIX-$1" file="$2"
  ( cd "$HERE" && rm -f "/tmp/$fn.zip" && zip -qj "/tmp/$fn.zip" "$file" )
  if aws lambda get-function --function-name "$fn" >/dev/null 2>&1; then
    aws lambda update-function-code --function-name "$fn" --zip-file "fileb:///tmp/$fn.zip" >/dev/null
  else
    aws lambda create-function --function-name "$fn" --runtime nodejs20.x --role "$ROLE_ARN" \
      --handler "${file%.mjs}.handler" --zip-file "fileb:///tmp/$fn.zip" --timeout 15 \
      --environment "Variables={INVENTORY_TABLE=$INV_TABLE,ORDERS_TABLE=$ORD_TABLE}" >/dev/null
    echo "   created lambda $fn"
  fi
  aws lambda wait function-active-v2 --function-name "$fn" 2>/dev/null || aws lambda wait function-active --function-name "$fn"
}
deploy_fn inventory inventory.mjs
deploy_fn restock   restock.mjs
deploy_fn orders    orders.mjs

echo ">> HTTP API"
API_ID="$(aws apigatewayv2 get-apis --query "Items[?Name=='${PREFIX}-api'].ApiId | [0]" --output text)"
if [ -z "$API_ID" ] || [ "$API_ID" = "None" ]; then
  API_ID="$(aws apigatewayv2 create-api --name "${PREFIX}-api" --protocol-type HTTP \
    --cors-configuration 'AllowOrigins=*,AllowMethods=*,AllowHeaders=*' --query ApiId --output text)"
  echo "   created api $API_ID"
  add_route () {  # method path lambda-suffix
    local fn="$PREFIX-$3"
    local int_id="$(aws apigatewayv2 create-integration --api-id "$API_ID" --integration-type AWS_PROXY \
      --integration-uri "arn:aws:lambda:$REGION:$ACCOUNT:function:$fn" --payload-format-version 2.0 \
      --query IntegrationId --output text)"
    aws apigatewayv2 create-route --api-id "$API_ID" --route-key "$1 $2" --target "integrations/$int_id" >/dev/null
    aws lambda add-permission --function-name "$fn" \
      --statement-id "apigw-$(echo "$1$2" | tr -cd '[:alnum:]')" --action lambda:InvokeFunction \
      --principal apigateway.amazonaws.com \
      --source-arn "arn:aws:execute-api:$REGION:$ACCOUNT:$API_ID/*/*" >/dev/null 2>&1 || true
  }
  add_route GET  "/inventory/{sku}" inventory
  add_route POST "/restock"         restock
  add_route POST "/orders"          orders
  aws apigatewayv2 create-stage --api-id "$API_ID" --stage-name '$default' --auto-deploy >/dev/null
else
  echo "   api exists ($API_ID) — leaving routes as-is"
fi
API_URL="$(aws apigatewayv2 get-api --api-id "$API_ID" --query ApiEndpoint --output text)"

echo ">> Seeding inventory"
python3 - "$INV_TABLE" "$HERE/seed.json" <<'PY'
import json, subprocess, sys, os
table, seed = sys.argv[1], sys.argv[2]
env = dict(os.environ)
for it in json.load(open(seed)):
    item = {"sku": {"S": it["sku"]}, "quantity": {"N": str(it["quantity"])}}
    subprocess.run(["aws","dynamodb","put-item","--table-name",table,"--item",json.dumps(item)], check=True, env=env)
    print("   seeded", it["sku"], "=", it["quantity"])
PY

echo ""
echo "=================================================================="
echo "DONE. API base URL:"
echo "  $API_URL"
echo "Try:"
echo "  curl $API_URL/inventory/WIDGET-001"
echo "  curl -X POST $API_URL/restock -d '{\"sku\":\"GIZMO-003\",\"qty\":25}'"
echo "  curl -X POST $API_URL/orders  -d '{\"sku\":\"WIDGET-001\",\"qty\":2,\"customer\":\"acme\"}'"
echo "=================================================================="
