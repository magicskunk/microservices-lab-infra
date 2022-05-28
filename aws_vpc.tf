# VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = var.vpc_cidr

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name                                                = "${var.project_name}-vpc",
    "kubernetes.io/cluster/${var.project_name}-cluster" = "shared"
    # eks will run in provided vpc based on this tag
  }
}

# Public Subnets
resource "aws_subnet" "public_subnet" {
  # public subnet per availability zone
  count = var.availability_zones_count

  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(local.common_tags, {
    Name                                                = "${var.project_name}-public-subnet-${count.index}"
    "kubernetes.io/cluster/${var.project_name}-cluster" = "shared"
    # "shared" -> allows more than one cluster to use this subnet
    "kubernetes.io/role/elb"                            = 1 #
  })

  map_public_ip_on_launch = true
}

# Private Subnets
resource "aws_subnet" "private_subnet" {
  count = var.availability_zones_count

  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, count.index + var.availability_zones_count)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(local.common_tags, {
    Name                                                = "${var.project_name}-private-sg"
    "kubernetes.io/cluster/${var.project_name}-cluster" = "shared"
    "kubernetes.io/role/internal-elb"                   = 1
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = merge(local.common_tags, {
    "Name" = "${var.project_name}-igw"
  })

  depends_on = [aws_vpc.main_vpc]
}

# Route Table(s)
# Route the public subnet traffic through the IGW
resource "aws_route_table" "main_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-rt"
  })
}

# Route table and subnet associations
resource "aws_route_table_association" "rt_internet_access" {
  count = var.availability_zones_count

  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.main_rt.id
}

# NAT Elastic IP
resource "aws_eip" "main_eip" {
  vpc = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ngw-ip"
  })
}

# NAT Gateway
resource "aws_nat_gateway" "main_ngw" {
  allocation_id = aws_eip.main_eip.id
  subnet_id     = aws_subnet.public_subnet[0].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ngw"
  })
}

# Add route to route table
resource "aws_route" "main_route" {
  route_table_id         = aws_vpc.main_vpc.default_route_table_id
  nat_gateway_id         = aws_nat_gateway.main_ngw.id
  destination_cidr_block = "0.0.0.0/0"
}

# Security group for public subnet
resource "aws_security_group" "public_sg" {
  name   = "${var.project_name}-public-sg"
  vpc_id = aws_vpc.main_vpc.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-sg"
  })
}

# Security group traffic rules
resource "aws_security_group_rule" "sg_ingress_public_443" {
  security_group_id = aws_security_group.public_sg.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "sg_ingress_public_80" {
  security_group_id = aws_security_group.public_sg.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "sg_egress_public" {
  security_group_id = aws_security_group.public_sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Security group for data plane
resource "aws_security_group" "eks_data_plane_sg" {
  name   = "${var.project_name}-worker-sg"
  vpc_id = aws_vpc.main_vpc.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-worker-sg"
  })
}

# Security group traffic rules
resource "aws_security_group_rule" "eks_nodes_sg_rule" {
  description       = "Allow nodes to communicate with each other"
  security_group_id = aws_security_group.eks_data_plane_sg.id
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = flatten([
    # all subnets, public and private
    cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 0),
    cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 1),
    cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 2),
    cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 3)
  ])
}

resource "aws_security_group_rule" "eks_nodes_inbound" {
  description       = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  security_group_id = aws_security_group.eks_data_plane_sg.id
  type              = "ingress"
  from_port         = 1025
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = flatten([
    # private subnets
    cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 2),
    cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 3)
  ])
}

resource "aws_security_group_rule" "eks_node_outbound" {
  security_group_id = aws_security_group.eks_data_plane_sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Security group for control plane
resource "aws_security_group" "eks_control_plane_sg" {
  name   = "${var.project_name}-control-plane-sg"
  vpc_id = aws_vpc.main_vpc.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-control-plane-sg"
  })
}

# Security group traffic rules
resource "aws_security_group_rule" "eks_control_plane_inbound" {
  security_group_id = aws_security_group.eks_control_plane_sg.id
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = flatten([
    cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 0),
    cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 1),
    cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 2),
    cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 3)
  ])
}

resource "aws_security_group_rule" "eks_control_plane_outbound" {
  security_group_id = aws_security_group.eks_control_plane_sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}
