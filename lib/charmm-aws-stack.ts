import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as s3deploy from 'aws-cdk-lib/aws-s3-deployment';
import { readFileSync } from 'fs';

export const DeployEnv = (process.env.DeployEnv ?? 'Testing');

export class CharmmAwsStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const annaduBucket = 'arn:aws:s3:::annadu';
    const charmmVpcId = 'vpc-594f1c3e';
    const charmmRoleArn = 'arn:aws:iam::830967159360:instance-profile/charmm';
    const charmmSg = 'sg-49631837';
    const charmmKeyName = 'charmm';
    let charmmAmi = 'ami-0fe472d8a85bc7b0e';  // amazon linux 2
    let charmmInstType = ec2.InstanceClass.T2;
    let charmmInstSize = ec2.InstanceSize.MICRO;
    if (DeployEnv === 'charmm1') {
      charmmAmi = 'ami-0565b5221d36a0fb7';  // cuda
      charmmInstType = ec2.InstanceClass.G4DN;
      charmmInstSize = ec2.InstanceSize.XLARGE;
    } else if (DeployEnv === 'charmm2') {
      charmmAmi = 'ami-0565b5221d36a0fb7';  // cuda
      charmmInstType = ec2.InstanceClass.G4DN;
      charmmInstSize = ec2.InstanceSize.XLARGE;
    } else if (DeployEnv === 'charmm3') {
      charmmAmi = 'ami-0565b5221d36a0fb7';  // cuda
      charmmInstType = ec2.InstanceClass.G4DN;
      charmmInstSize = ec2.InstanceSize.XLARGE4;
    } else if (DeployEnv === 'charmm4') {
      charmmAmi = 'ami-0565b5221d36a0fb7';  // cuda
      charmmInstType = ec2.InstanceClass.G4DN;
      charmmInstSize = ec2.InstanceSize.METAL;
    }
    // aws ec2 describe-images --region us-east-1 --image-ids ami-0565b5221d36a0fb7
    const charmmRootDev = '/dev/xvda';


    // copy install.sh to s3://annadu/charmm/install_scripts/
    const bucket = s3.Bucket.fromBucketArn(this, 's3bucket', annaduBucket);
    new s3deploy.BucketDeployment(this, 'DeployInstallSh', {
      sources: [s3deploy.Source.asset('./install_scripts')],
      destinationBucket: bucket,
      destinationKeyPrefix: 'charmm/install_scripts/'
    })
    new s3deploy.BucketDeployment(this, 'RunScripts', {
      sources: [s3deploy.Source.asset('./scripts')],
      destinationBucket: bucket,
      destinationKeyPrefix: 'charmm/bin/'
    })
    const userDataScript = readFileSync('./lib/user-data.sh', 'utf-8');

    // ec2 instance variables

    const defaultVpc = ec2.Vpc.fromLookup(this, 'Vpc', {
      // vpcId: charmmVpcId,
      isDefault: true,
    });

    const role = iam.Role.fromRoleArn(this, 'charmmRole', charmmRoleArn, { mutable: false });

    const sg = ec2.SecurityGroup.fromLookupById(this, 'sg', charmmSg);

    const rootVolume: ec2.BlockDevice = {
      deviceName: charmmRootDev,
      volume: ec2.BlockDeviceVolume.ebs(50),
    };

    const charmm3 = new ec2.Instance(this, 'charmm3', {
      instanceName: DeployEnv,
      vpc: defaultVpc,
      vpcSubnets: {subnetType: ec2.SubnetType.PUBLIC},
      role: role,
      securityGroup: sg,
      instanceType: ec2.InstanceType.of(charmmInstType, charmmInstSize),
      machineImage: ec2.MachineImage.genericLinux({
        'us-east-1': charmmAmi
      }),
      blockDevices: [rootVolume],
      keyName: charmmKeyName,
    });

    const eip = new ec2.CfnEIP(this, 'eip', {
      instanceId: charmm3.instanceId
    })

    charmm3.addUserData(userDataScript);
  }
}
