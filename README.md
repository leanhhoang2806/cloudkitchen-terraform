# How to run terraform
1. `$ terraform init`
2. before execution, check if the script is correct ` $ terraform plan`
3. supply credentials using `$ aws configure`
4. Execute the plan ` $ terraform apply ` (for the first run)
5. For future run `$terraform apply -refresh-only`

6. Only manage resources that does not including IAM with Terraform
7. For resources provided by terraform for each managed resources, look into the file `terraform.tfstate` it will give a list of variable to use
8. Always run `terraform plan` before `terraform apply`
9. Interconnected resources let's say of a user for S3 is manage by 2 user group, make sure to ignore_changes on both groups otherwise it will 
10. to remove a single resources => `terraform destroy -target=aws_ecs_task_definition.popo24_task_definition`
11. Control everything through terraform, do it manually will create confusion