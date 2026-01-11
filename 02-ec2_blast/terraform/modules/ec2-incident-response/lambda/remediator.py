import boto3

ec2 = boto3.client("ec2")
iam = boto3.client("iam")

QUARANTINE_SG_ID = "sg-0890bfcdab0f1353a"   # Replace with your quarantine security group ID
DENY_POLICY_NAME = "DenyAll-IncidentResponse"

def lambda_handler(event, context):
    detail = event["detail"]
    instance_id = detail["resource"]["instanceDetails"]["instanceId"]
    finding_type = detail["type"]

    print(f"CRITICAL finding {finding_type} on {instance_id}")

    # 1. Snapshot volumes
    reservations = ec2.describe_instances(InstanceIds=[instance_id])["Reservations"]
    for inst in reservations[0]["Instances"]:
        for bd in inst.get("BlockDeviceMappings", []):
            if "Ebs" in bd:
                ec2.create_snapshot(
                    VolumeId=bd["Ebs"]["VolumeId"],
                    Description=f"Forensic-{instance_id}"
                )

        # 2. Quarantine instance
        ec2.modify_instance_attribute(
            InstanceId=instance_id,
            Groups=[QUARANTINE_SG_ID]
        )

        # 3. Disable IAM role (if attached)
        if "IamInstanceProfile" in inst:
            profile_arn = inst["IamInstanceProfile"]["Arn"]
            profile_name = profile_arn.split("/")[-1]

            profile = iam.get_instance_profile(
                InstanceProfileName=profile_name
            )

            role_name = profile["InstanceProfile"]["Roles"][0]["RoleName"]

            iam.put_role_policy(
                RoleName=role_name,
                PolicyName=DENY_POLICY_NAME,
                PolicyDocument='{"Version":"2012-10-17","Statement":[{"Effect":"Deny","Action":"*","Resource":"*"}]}'
            )

    return {"status": "isolated", "instance": instance_id}
