# terraform-aws-awx
Spin up AWX in AWS Fargate

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

## ALB of certificate used to secure traffic to ALB
alb_ssl_certificate_arn = "arn:aws:acm:region:accountid:certificate/hash"

## DNS name to assign ALB handling traffic
route53_zone_name       = "tower.google.com."

## VPC in which to spin all this up
vpc_id                  = "vpc-c0ffeffe"

## CIDR Block of VPC
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
aws_secret_klay    = "myawxsecret"
awx_admin_password = "myawxadminpassword

tags = {
  whodunnit = "me"
}
```

This configuration (ignoring fake names) will produce an AWX instance at https://tower.google.com 

## Variables
Definitive answers in [variables.tf](variables.tf)

## Outputs 
Definitive answers in [outputs.tf](outputs.tf)
