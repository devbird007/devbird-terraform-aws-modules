variable "description" {
  type = string
}

variable "vpc_cidr_block" {
  description = "IPv4 CIDR block range for the VPC"
  type        = string
  default     = "10.16.0.0/16"
}

variable "subnets" {
  description = "A map defining the subnet structure (AZ index and network number)"
  type = map(object({
    az_index = number
    net_num  = number
  }))
  default = {
    "reserved-A" = { az_index = 0, net_num = 0 }
    "db-A"       = { az_index = 0, net_num = 1 }
    "app-A"      = { az_index = 0, net_num = 2 }
    "web-A"      = { az_index = 0, net_num = 3 }

    "reserved-B" = { az_index = 1, net_num = 4 }
    "db-B"       = { az_index = 1, net_num = 5 }
    "app-B"      = { az_index = 1, net_num = 6 }
    "web-B"      = { az_index = 1, net_num = 7 }

    "reserved-C" = { az_index = 2, net_num = 8 }
    "db-C"       = { az_index = 2, net_num = 9 }
    "app-C"      = { az_index = 2, net_num = 10 }
    "web-C"      = { az_index = 2, net_num = 11 }
  }
}

variable "vpc_name" {
  description = "The name of the VPC"
  type        = string
}

variable "tags" {
  description = "A map of standard tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_natgw" {
  description = "Set to true to provision NAT Gateways in the web subnets"
  type        = bool
  default     = false
}

variable "enable_ssm_endpoints" {
  description = "Set to true to provision secure VPC Endpoints for Systems Manager"
  type        = bool
  default     = false
}

variable "enable_eic_endpoint" {
  description = "Set to true to provision an EC2 Instance Connect Endpoint"
  type        = bool
  default     = false
}