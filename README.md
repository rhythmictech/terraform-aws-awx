# terraform-aws-awx
Spin up AWX in AWS 

## About 

Terraform to spin up AWX on ECS
- https://github.com/ansible/awx
- https://aws.amazon.com/ecs/


## Getting Started
Add necessary variables. See `variables.tf` for inputs. 


## Changelog 
### 2019-07-06
Code to deploy a dummy instance is included, all that is required is a few variables. 

### 2019-07-06
Finally got it running on ECS. Able to log into web console but haven't run any test jobs. 
There is still a lot of work to be done to productionalize it but first we hope to demonstrate value of this tool.
