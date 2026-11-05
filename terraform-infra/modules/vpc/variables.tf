variable "vpc_cidr" { type = string }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_app_subnet_cidrs" { type = list(string) }
variable "isolated_data_subnet_cidrs" { type = list(string) }
variable "availability_zones" { type = list(string) }


