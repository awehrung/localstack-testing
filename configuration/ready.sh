#!/bin/bash

Color_On="\033[1;32m"
Color_Off="\033[0m" # Color Reset

PYTHON_RUNTIME="python3.12"
stage_name="local"
backend_url="http://hello-world:5050"
authorizer_arn="arn:aws:lambda:${DEFAULT_REGION:-eu-central-1}:000000000000:function:authorizer"

function echo_green() {
  echo -e "${Color_On} $1 ${Color_Off}"
}

function create_lambda_function_if_not_exists() {
    # 1: function name, 2: path to zip, 3: environment
    if awslocal lambda get-function --function-name="$1"; then
        echo "Lambda function $1 already exists"
    else
        awslocal lambda create-function \
            --function-name="$1" \
            --zip-file="fileb://$2" \
            --role="arn:aws:iam::000000000000:role/test-role" \
            --timeout="60" \
            --handler="$1_handler.lambda_handler" \
            --environment Variables="{$(cat $3 | xargs | sed 's/ /,/g')}" \
            --runtime="${PYTHON_RUNTIME}"
        echo "Lambda function $1 successfully created"
    fi
}

function create_api_if_not_exists() {
  # 1: api-name
  # return: api-id
  apis=$(awslocal apigatewayv2 get-apis)
  if echo "${apis}" | jq -r .Items[].Name | grep -qx "$1"; then
    # Api already exists, find and return ID
    echo "${apis}" | jq -r ".Items[] | select(.Name == \"$1\") | .ApiId"
  else
    create_api_response=$(awslocal apigatewayv2 create-api \
      --name="$1" \
      --protocol-type="HTTP" \
      --tags="_custom_id_=$1" \
      --cors-configuration="AllowCredentials=true,AllowOrigins=[$EXTRA_CORS_ALLOWED_ORIGINS],AllowMethods=*,AllowHeaders=*")
    echo "${create_api_response}" | jq -r .ApiId
  fi
}

function create_stage_if_not_exists() {
  # 1: api-name, 2: stage-name
  stages=$(awslocal apigatewayv2 get-stages --api-id="$1")
  if echo "${stages}" | jq -r .Items[].StageName | grep -qx "$2"; then
    echo "Stage already exists"
  else
    awslocal apigatewayv2 create-stage --api-id="$1" --stage-name="$2" --auto-deploy
  fi
}

function create_authorizer_if_not_exists() {
  # 1: api-id, 2: lambda-arn, 3: authorizer-name
  # return: authorizer-id
  authorizers=$(awslocal apigatewayv2 get-authorizers --api-id="$1")
  if echo "${authorizers}" | jq -r .Items[].AuthorizerUri | grep -q "$2"; then
    # Authorizer already exists, find and return ID
    echo "${authorizers}" | jq -r ".Items[] | select(.AuthorizerUri == \"$2\") | .AuthorizerId"
  else
    create_authorizer_response=$(awslocal apigatewayv2 create-authorizer \
      --api-id="$1" \
      --authorizer-type="REQUEST" \
      --authorizer-uri="arn:aws:apigateway:eu-central-1:lambda:path/2015-03-31/functions/$2/invocations" \
      --authorizer-payload-format-version="2.0" \
      --enable-simple-responses \
      --identity-source '$request.header.Authorization' \
      --name="$3")
    echo "${create_authorizer_response}" | jq -r .AuthorizerId
  fi
}

function create_mapping_for_endpoint() {
  # 1: api-id, 2: service-url, 3: method, 4: path-prefix, 5: authorizer-id
  integration_id=$(_create_http_integration_if_not_exists "$1" "$2" "$3" "$4")
  _create_endpoint_route_if_not_exists "$1" "$3 $4" "$5" "${integration_id}"
}

function _create_http_integration_if_not_exists() {
  # 1: api-id, 2: service-url, 3: method (unused?), 4: path-prefix
  # return: integration-id
  integrations=$(awslocal apigatewayv2 get-integrations --api-id="$1")
  found_matching_integrations=$(echo "${integrations}" | jq -r ".Items[] | select(.IntegrationMethod == \"$3\") | select(.IntegrationUri == \"$2$4{proxy}\") | .IntegrationId")
  if [ "${#found_matching_integrations}" -gt 0 ]; then
    # Integration already exists, find and return ID
    echo "${found_matching_integrations}"
  else
    create_integration_response=$(awslocal apigatewayv2 create-integration \
      --api-id="$1" \
      --integration-type="HTTP_PROXY" \
      --integration-method="$3" \
      --integration-uri="$2$4{proxy}" \
      --payload-format-version="1.0")
    echo "${create_integration_response}" | jq -r .IntegrationId
  fi
}

function _create_endpoint_route_if_not_exists() {
  # 1: api-id, 2: route-key-prefix, 3: authorizer-id, 4: integration-id
  # return: route-id
  routes=$(awslocal apigatewayv2 get-routes --api-id="$1")
  if echo "${routes}" | jq -r .Items[].RouteKey | grep -q "$2"; then
    # Route already exists, find and return ID
    echo "${routes}" | jq -r ".Items[] | select(.RouteKey == \"$2\") | .RouteId"
  else
    create_route_response=$(awslocal apigatewayv2 create-route \
      --api-id="$1" \
      --route-key="$2{proxy+}" \
      --authorization-type="CUSTOM" \
      --authorizer-id="$3" \
      --target="integrations/$4")
    echo "${create_route_response}" | jq -r .RouteId
  fi
}

create_lambda_function_if_not_exists authorizer /opt/code/lambda_import/authorizer.zip /opt/app/lambda/authorizer.env
echo_green "Lambda function authorizer created"

my_api_id=$(create_api_if_not_exists "myapi")
create_stage_if_not_exists "${my_api_id}" "${stage_name}"
authorizer_id=$(create_authorizer_if_not_exists "${my_api_id}" "${authorizer_arn}" "Authorizer")
create_mapping_for_endpoint "${my_api_id}" "${backend_url}" "GET" "/" "${authorizer_id}"
echo_green "API-GW configured"

echo_green "All done"
