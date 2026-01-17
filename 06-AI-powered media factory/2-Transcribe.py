import boto3
import uuid

transcribe = boto3.client("transcribe")

def lambda_handler(event, context):
    job_name = f"job-{uuid.uuid4()}"
    media_uri = f"s3://{event['bucket']}/{event['key']}"

    transcribe.start_transcription_job(
        TranscriptionJobName=job_name,
        Media={"MediaFileUri": media_uri},
        MediaFormat="mp4",
        LanguageCode="en-US"
    )

    return {
        **event,
        "job_name": job_name
    }
