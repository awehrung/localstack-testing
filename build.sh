#!/bin/bash

DIST_DIR="lambda/dist"

function create_zip_file() {
    (cd "lambda" && zip -9 -rjq "../${DIST_DIR}/$1.zip" ./"$1"/*.py)
}

## clean
rm -rf ${DIST_DIR}
mkdir -p "${DIST_DIR}"

## build
create_zip_file "authorizer"

echo "Done."
