import boto3

ec2 = boto3.client('ec2', region_name='us-east-1')

user_option = input('''what command do you wish to run 
1: list instances 
2: stop instance(s) 
3: start instance(s) 
4: terminate instance(s)
''')

if user_option == '1':
    response = ec2.describe_instances(
        Filters=[
            {
                'Name': 'tag:Name',
                'Values': ['terraformboto3inst1']
            }
        ]
    )
    
   
    instances = [i for r in response['Reservations'] for i in r['Instances']]
    for instance in instances:
        print(f"ID: {instance['InstanceId']}")
        print(f"State: {instance['State']['Name']}")
        

elif user_option == '2':
    instance_id = input("Enter instance ID you wis to stop: ")
    ec2.stop_instances(InstanceIds=[instance_id])
    print(f"{instance_id} SUCCESSFULLY STOPPED")

elif user_option == '3':
    instance_id = input("Enter instance ID you wish to start: ")
    ec2.start_instances(InstanceIds=[instance_id])
    print(f"{instance_id} SUCCESSFULLY STARTED")

elif user_option == '4':
    instance_id = input("Enter instance ID you wish  to terminate: ")
    if input(f"Type yes to delete {instance_id}: ") == 'yes':
        ec2.terminate_instances(InstanceIds=[instance_id])
        print(f"{instance_id} TERMINATED")
