import logging
import os
import random


def lambda_handler(event, context):
    logging.info("HELLO FROM AUTHORIZER")
    return {
        "isAuthorized": True,
        "context": {
            "test-env": os.getenv("TEST_ENV", "no-value"),
            "random-header": random.randint(0, 100)
        },
    }
