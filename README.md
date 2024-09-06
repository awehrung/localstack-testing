# Important note

The problem described appears in commit `843aa4f` but was explained and solved in https://github.com/localstack/localstack/issues/11470

# How to use

Build the lambda `dist`:

```shell
./build.sh
```

Start the containers:

```shell
docker-compose up -d
```

Check the logs and wait for all resources to be created.

Try the public route:

```shell
curl -v https://myapi.execute-api.localhost.localstack.cloud:4566/local/authno/mytest
```

Should return HTTP-status 200 and print a Hello-world message.

Try the private route:

```shell
curl -v https://myapi.execute-api.localhost.localstack.cloud:4566/local/authyes/mytest
```

~~Should do the same but somehow returns HTTP-status 401.~~

Returns 401 without calling the authorizer due to the absence of the header required by the authorizer "identity-source". This is intentional since https://github.com/localstack/localstack/issues/10636.

Try the private route with the missing header:

```shell
curl -v -H 'Authorization: whatever' https://myapi.execute-api.localhost.localstack.cloud:4566/local/authyes/mytest
```

Should return HTTP-status 200 and print a Hello-world message.
