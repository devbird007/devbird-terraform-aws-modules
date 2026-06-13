data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

resource "aws_vpc" "main" {
  cidr_block                       = var.vpc_cidr_block
  instance_tenancy                 = "default"
  assign_generated_ipv6_cidr_block = true
  enable_dns_hostnames             = true

  tags = merge(
    { Name = var.vpc_name },
    var.tags
  )
}

resource "aws_subnet" "multi_tier" {
  for_each = var.subnets

  vpc_id            = aws_vpc.main.id
  availability_zone = data.aws_availability_zones.available.names[each.value.az_index]
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 4, each.value.net_num)
  ipv6_cidr_block   = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, each.value.net_num)

  assign_ipv6_address_on_creation = true
  map_public_ip_on_launch         = strcontains(each.key, "web")
  tags = merge(
    {
      Name = "${var.vpc_name}-sn-${each.key}"
      Tier = split("-", each.key)[0]
    },
    var.tags
  )
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    { Name = "${var.vpc_name}-igw" },
    var.tags
  )
}

resource "aws_route_table" "web" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.igw.id
  }

  tags = merge(
    { Name = "${var.vpc_name}-rt-web" },
    var.tags
  )
}

resource "aws_route_table_association" "rt_association" {
  for_each = {
    for k, v in var.subnets : k => v
    if strcontains(lower(k), "web")
  }

  subnet_id      = aws_subnet.multi_tier[each.key].id
  route_table_id = aws_route_table.web.id
}

## NAT Gateway Resources

resource "aws_eip" "nat" {
  depends_on = [aws_internet_gateway.igw]

  for_each = var.enable_natgw ? {
    for k, v in var.subnets : k => v
    if strcontains(k, "web")
  } : {}

  domain = "vpc"

  tags = merge(
    { Name = "${var.vpc_name}-eip-${each.key}" },
    var.tags
  )
}

resource "aws_nat_gateway" "nat" {
  for_each = var.enable_natgw ? {
    for k, v in var.subnets : k => v
    if strcontains(k, "web")
  } : {}

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.multi_tier[each.key].id

  tags = merge(
    { Name = "${var.vpc_name}-natgw-${each.key}" },
    var.tags
  )
}

resource "aws_route_table" "private_rt" {
  for_each = var.enable_natgw ? {
    for k, v in var.subnets : k => v
    if strcontains(k, "web")
  } : {}

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[each.key].id
  }

  tags = merge(
    {
      Name = "${var.vpc_name}-rt-private-${split("-", each.key)[1]}"
    },
    var.tags
  )
}

resource "aws_route_table_association" "nat_rt_association" {
  for_each = var.enable_natgw ? {
    for k, v in var.subnets : k => v
    if !strcontains(lower(k), "web")
  } : {}

  subnet_id = aws_subnet.multi_tier[each.key].id

  route_table_id = aws_route_table.private_rt["web-${split("-", each.key)[1]}"].id
}


## Extra features like SSM_endpoints & EC2_Instance_Connect_endpoints
data "aws_region" "current" {}

resource "aws_security_group" "endpoint_sg" {
  count = var.enable_ssm_endpoints || var.enable_eic_endpoint ? 1 : 0

  vpc_id      = aws_vpc.main.id
  name        = "${var.vpc_name}-endpoint-sg"
  description = "Security Group for VPC Endpoints"

  tags = merge(
    { Name = "${var.vpc_name}-endpoint-sg" },
    var.tags
  )
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssm_vpc" {
  count = var.enable_ssm_endpoints ? 1 : 0

  security_group_id = aws_security_group.endpoint_sg[0].id
  description       = "Allow SSM traffic from VPC"
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "allow_eic_vpc" {
  count = var.enable_eic_endpoint ? 1 : 0

  security_group_id = aws_security_group.endpoint_sg[0].id
  description       = "Allow SSH traffic from VPC"
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "allow_eic_outbound" {
  count = var.enable_eic_endpoint ? 1 : 0

  security_group_id = aws_security_group.endpoint_sg[0].id
  description       = "Allow EIC to SSH out to private instances"
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

## --- Systems Manager (SSM) Endpoints ---
resource "aws_vpc_endpoint" "ssm_endpoints" {
  for_each = var.enable_ssm_endpoints ? toset(["ssm", "ec2messages", "ssmmessages"]) : []

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    for k, v in aws_subnet.multi_tier : v.id
  if strcontains(k, "app")]


  security_group_ids = [aws_security_group.endpoint_sg[0].id]

  tags = merge(
    { Name = "${var.vpc_name}-${each.key}-endpoint" },
    var.tags
  )
}

## --- EC2 Instance Connect (EIC) Endpoint ---
resource "aws_ec2_instance_connect_endpoint" "eic_endpoint" {
  count = var.enable_eic_endpoint ? 1 : 0

  subnet_id = [
    for k, v in aws_subnet.multi_tier : v.id
    if strcontains(k, "app")
  ][0]

  security_group_ids = [aws_security_group.endpoint_sg[0].id]

  tags = merge(
    { Name = "${var.vpc_name}-eic-endpoint" },
    var.tags
  )
}