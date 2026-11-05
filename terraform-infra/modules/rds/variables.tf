variable "vpc_id" { type = string }
variable "isolated_data_subnet_ids" { type = list(string) }
variable "kms_key_arn" { type = string }
variable "ecs_task_sg_id" { type = string }
