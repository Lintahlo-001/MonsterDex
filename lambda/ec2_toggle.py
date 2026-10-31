import boto3
import json

CORS_HEADERS = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

def lambda_handler(event, context):
    if event.get('requestContext', {}).get('http', {}).get('method') == 'OPTIONS':
        return {'statusCode': 200, 'headers': CORS_HEADERS, 'body': ''}

    body = event
    if 'body' in event:
        raw = event['body']
        if isinstance(raw, str):
            try:
                body = json.loads(raw)
            except Exception:
                body = {}
        elif isinstance(raw, dict):
            body = raw

    action      = body.get('action')
    instance_id = body.get('instance_id')
    region      = body.get('region', 'eu-west-3')

    if not action or not instance_id:
        return {
            'statusCode': 400,
            'headers': CORS_HEADERS,
            'body': json.dumps({'error': 'Missing action or instance_id'})
        }

    try:
        ec2 = boto3.client('ec2', region_name=region)

        if action == 'status':
            resp  = ec2.describe_instances(InstanceIds=[instance_id])
            state = resp['Reservations'][0]['Instances'][0]['State']['Name']
            return {'statusCode': 200, 'headers': CORS_HEADERS,
                    'body': json.dumps({'state': state})}

        elif action == 'start':
            ec2.start_instances(InstanceIds=[instance_id])
            return {'statusCode': 200, 'headers': CORS_HEADERS,
                    'body': json.dumps({'result': 'starting'})}

        elif action == 'stop':
            ec2.stop_instances(InstanceIds=[instance_id])
            return {'statusCode': 200, 'headers': CORS_HEADERS,
                    'body': json.dumps({'result': 'stopping'})}

        else:
            return {'statusCode': 400, 'headers': CORS_HEADERS,
                    'body': json.dumps({'error': f'Invalid action: {action}'})}

    except Exception as e:
        return {'statusCode': 500, 'headers': CORS_HEADERS,
                'body': json.dumps({'error': str(e)})}
