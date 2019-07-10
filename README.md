# terraform-aws-awx
Spin up AWX in AWS 

## About 

Terraform to spin up AWX on ECS
- https://github.com/ansible/awx
- https://aws.amazon.com/ecs/


## Getting Started
Add necessary variables. See `variables.tf` for inputs. 

```
tf plan -out /tmp/tf.plan
tf apply /tmp/tf.plan
```

### Prerequisites 
- VPC
- Public and Private Subnets 
- DNS name in Route53
- SSL Certificate for DNS name in Certificate Manager

Add these values into a `.tfvars` file, like below;

```
# Required
alb_ssl_certificate_arn = "arn:aws:acm:region:accountid:certificate/hash"
route53_zone_name       = "tower.google.com."
vpc_id                  = "vpc-c0ffeffe"
cidr_block              = "1.234.678.0/20"

database_subnets = [
  "subnet-123abc",
  "subnet-123abc",
  "subnet-123abc"
]
public_subnets = [
  "subnet-123abc",
  "subnet-123abc",
  "subnet-123abc"
]
private_subnets = [
  "subnet-123abc",
  "subnet-123abc",
  "subnet-123abc"
]

# Optional
cluster_name       = "ayy-doubleyou-ex"
ecs_instance_type  = "t3.large"
db_password        = "password-up"
aws_secret_klay    = "myawxsecret"
awx_admin_password = "myawxadminpassword

tags = {
  whodunnit = "me"
}
```


## Changelog 

### SSL and Move things into their own files 

### 2019-07-06
Code to deploy a dummy instance is included, all that is required is a few variables. 

### 2019-07-06
Finally got it running on ECS. Able to log into web console but haven't run any test jobs. 
There is still a lot of work to be done to productionalize it but first we hope to demonstrate value of this tool.
