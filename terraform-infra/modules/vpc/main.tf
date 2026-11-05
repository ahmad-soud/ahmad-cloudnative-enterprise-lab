# --- 1. Main Virtual Private Cloud (VPC) ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "Enterprise-VPC" }
}

# --- 2. Internet Gateway for Public Subnet Access ---
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "Enterprise-IGW" }
}

# --- 3. Public Subnets ---
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "Public-Subnet-${var.availability_zones[count.index]}" }
}

# --- 4. Private Application Subnets ---
resource "aws_subnet" "private_app" {
  count             = length(var.private_app_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  tags              = { Name = "Private-App-Subnet-${var.availability_zones[count.index]}" }
}

# --- 5. Isolated Data Subnets (Database Tier) ---
resource "aws_subnet" "isolated_data" {
  count             = length(var.isolated_data_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.isolated_data_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  tags              = { Name = "Isolated-Data-Subnet-${var.availability_zones[count.index]}" }
}

# --- 6. Elastic IPs for NAT Gateways ---
resource "aws_eip" "nat" {
  count      = 2
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
  tags       = { Name = "NAT-EIP-${count.index}" }
}

# --- 7. NAT Gateways for Private Subnet Outbound Traffic ---
resource "aws_nat_gateway" "nat" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = { Name = "NAT-Gateway-${var.availability_zones[count.index]}" }
}

# --- 8. Public Route Table ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "Public-RouteTable" }
}

# --- 9. Private Route Tables ---
resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }
  tags = { Name = "Private-RouteTable-${var.availability_zones[count.index]}" }
}

# --- 10. Route Table Associations ---
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_app" {
  count          = 2
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# --- 11. VPC Gateway Endpoint for Amazon S3 ---
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.eu-central-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat([aws_route_table.public.id], aws_route_table.private[*].id)
  tags              = { Name = "S3-VPC-Endpoint" }
}

output "vpc_id" { value = aws_vpc.main.id }
output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "List of public subnet IDs for the Application Load Balancer"
}
output "private_app_subnet_ids" { value = aws_subnet.private_app[*].id }
output "isolated_data_subnet_ids" { value = aws_subnet.isolated_data[*].id }
