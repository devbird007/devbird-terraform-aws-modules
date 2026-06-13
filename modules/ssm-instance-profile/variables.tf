variable "vpc_name" {
  description = "The name of the VPC"
  type        = string
}

variable "tags" {
  description = "A map of standard tags to apply to all resources"
  type        = map(string)
  default     = {}
}