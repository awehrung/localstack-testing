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

Should do the same but somehow returns HTTP-status 401.
