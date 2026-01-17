
import base64
import json
import gzip
import re
import boto3
import os
import uuid
from datetime import datetime

s3 = boto3.client("s3")

PII_PATTERNS = {
    "EMAIL": r"[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+",
    "PHONE": r"\+?\d{1,4}?[-.\s]?\(?\d{1,3}?\)?[-.\s]?\d{1,4}",
    "CREDIT_CARD": r"\b(?:\d[ -]*?){13,16}\b"
}

def scrub(msg):
    for k, p in PII_PATTERNS.items():
        msg = re.sub(p, f"[{k}_REDACTED]", msg)
    return msg

def lambda_handler(event, context):
    if "awslogs" not in event:
        return {"status": "ignored"}

    payload = gzip.decompress(base64.b64decode(event["awslogs"]["data"]))
    data = json.loads(payload)

    cleaned = [scrub(e["message"]) for e in data.get("logEvents", [])]

    key = f"scrubbed/{datetime.utcnow().strftime('%Y/%m/%d/%H')}/{uuid.uuid4()}.log"

    s3.put_object(
        Bucket=os.environ["CLEAN_LOG_BUCKET"],
        Key=key,
        Body="\n".join(cleaned)
    )

    return {"status": "success"}
