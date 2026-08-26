## Introduction
This module provisions the following:

### 1. Core Networking (VPC & Routing)
A VPC with a broad `10.16.0.0/16` CIDR block by default. It also auto-requests an Amazon-provided IPv6 block.

An Internet Gateway (IGW) attached to the VPC to allow public traffic in and out.

A Route Table (`RouteTableWeb`) configured with two default routes pointing directly to the IGW:  
- IPv4 destination: `0.0.0.0/0`
- IPv6 destination: `::/0`

### 2. The 12-Subnet Architecture
12 subnets in 4 distinct-tiers across 3 availability zones: A, B and C are created by default.  
- Web Tier (3 Subnets): Associated with the public `RouteTableWeb`. They automatically assign public IPv4 addresses on launch
- App Tier (3 Subnets): Private subnets with no attached route table
- DB Tier (3 Subnets): Isolated private database subnets
- Reserved Tier (3 Subnets): Placed at the very front of the IP spacing for future use.

#Note: The subnets can be varied by modifying the variable `subnet_newbits`

## Inputs
