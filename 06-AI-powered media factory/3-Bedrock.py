import boto3, json, urllib.request

transcribe = boto3.client("transcribe")
bedrock = boto3.client("bedrock-runtime")

BAD_WORDS = ["sex", "nude", "fuck", "porn"]

def lambda_handler(event, context):
    job_name = event["job_name"]

    job = transcribe.get_transcription_job(
        TranscriptionJobName=job_name
    )

    if job["TranscriptionJob"]["TranscriptionJobStatus"] != "COMPLETED":
        raise Exception("Transcription not ready")

    transcript_uri = job["TranscriptionJob"]["Transcript"]["TranscriptFileUri"]

    with urllib.request.urlopen(transcript_uri) as r:
        transcript_json = json.loads(r.read())

    transcript_text = transcript_json["results"]["transcripts"][0]["transcript"]

    # 🔥 DECISION LOGIC
    lower_text = transcript_text.lower()
    is_unsafe = any(word in lower_text for word in BAD_WORDS)

    if is_unsafe:
        return {
            **event,
            "summary": "Blocked due to unsafe content",
            "status": "UNSAFE"
        }

    # ✅ SAFE → generate summary
    response = bedrock.invoke_model(
        modelId="amazon.titan-text-express-v1",
        body=json.dumps({
            "inputText": f"Summarize this transcript:\n{transcript_text}",
            "textGenerationConfig": {
                "maxTokenCount": 200,
                "temperature": 0.3,
                "topP": 0.9
            }
        })
    )

    result = json.loads(response["body"].read())
    summary = result["results"][0]["outputText"]

    return {
        **event,
        "summary": summary,
        "status": "SAFE"
    }
