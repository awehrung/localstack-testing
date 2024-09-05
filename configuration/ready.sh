#!/bin/bash

set -e

Color_On="\033[1;32m"
Color_Off="\033[0m" # Color Reset

PYTHON_RUNTIME="python3.12"
STAGE_NAME="local"
BACKEND_URL="http://hello-world:5050"
API_NAME="myapi"
AUTHORIZER_NAME="authorizer"

function echo_green() {
  echo -e "${Color_On} $1 ${Color_Off}"
}

# create lambda
awslocal lambda create-function \
    --function-name="${AUTHORIZER_NAME}" \
    --zip-file="fileb:///opt/code/lambda_import/${AUTHORIZER_NAME}.zip" \
    --role="arn:aws:iam::000000000000:role/test-role" \
    --timeout="60" \
    --handler="${AUTHORIZER_NAME}_handler.lambda_handler" \
    --environment Variables="{$(cat /opt/app/lambda/authorizer.env | xargs | sed 's/ /,/g')}" \
    --runtime="${PYTHON_RUNTIME}"
echo_green "Lambda function authorizer created"

# create api
create_api_response=$(awslocal apigatewayv2 create-api \
  --name="${API_NAME}" \
  --protocol-type="HTTP" \
  --tags="_custom_id_=${API_NAME}" \
  --cors-configuration="AllowCredentials=true,AllowOrigins=[http://my-frontend.com],AllowMethods=*,AllowHeaders=*")
my_api_id=$(echo "${create_api_response}" | jq -r .ApiId)
echo_green "API created"

# create stage
awslocal apigatewayv2 create-stage --api-id="${my_api_id}" --stage-name="${STAGE_NAME}" --auto-deploy
echo_green "Stage created"

# create authorizer
create_authorizer_response=$(awslocal apigatewayv2 create-authorizer \
  --api-id="${my_api_id}" \
  --authorizer-type="REQUEST" \
  --authorizer-uri="arn:aws:apigateway:eu-central-1:lambda:path/2015-03-31/functions/arn:aws:lambda:eu-central-1:000000000000:function:${AUTHORIZER_NAME}/invocations" \
  --authorizer-payload-format-version="2.0" \
  --enable-simple-responses \
  --identity-source '$request.header.Authorization' \
  --name="Authorizer")
authorizer_id=$(echo "${create_authorizer_response}" | jq -r .AuthorizerId)
echo_green "Authorizer created"

# create integration
create_integration_response=$(awslocal apigatewayv2 create-integration \
  --api-id="${my_api_id}" \
  --integration-type="HTTP_PROXY" \
  --integration-method="GET" \
  --integration-uri="${BACKEND_URL}/{proxy}" \
  --payload-format-version="1.0")
integration_id=$(echo "${create_integration_response}" | jq -r .IntegrationId)
echo_green "Integration created"

# create private route
create_private_route_response=$(awslocal apigatewayv2 create-route \
  --api-id="${my_api_id}" \
  --route-key="GET /authyes/{proxy+}" \
  --authorization-type="CUSTOM" \
  --authorizer-id="${authorizer_id}" \
  --target="integrations/${integration_id}")
route_id=$(echo "${create_private_route_response}" | jq -r .RouteId)
echo_green "Private route created"

# create public route
create_public_route_response=$(awslocal apigatewayv2 create-route \
  --api-id="${my_api_id}" \
  --route-key="GET /authno/{proxy+}" \
  --authorization-type="NONE" \
  --target="integrations/${integration_id}")
route_id=$(echo "${create_public_route_response}" | jq -r .RouteId)
echo_green "Public route created"

echo_green "All done"
