variable "key_pair_name" {
  description = "Existing EC2 Key Pair name"
  type        = string
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "dbadmin123"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

# HRM on EKS settings (keep inputs minimal; set once via terraform.tfvars)
variable "hrm_image" {
  description = "Container image for HRM (ECR URI with tag)"
  type        = string
}

variable "hrm_namespace" {
  description = "Kubernetes namespace for HRM"
  type        = string
  default     = "hrm-test"
}

variable "okta_domain" {
  description = "Okta domain (e.g., https://dev-123456.okta.com)"
  type        = string
}

variable "okta_api_token" {
  description = "Okta API token"
  type        = string
  sensitive   = true
}

variable "hrm_secret_key" {
  description = "Flask secret key"
  type        = string
  sensitive   = true
}

variable "hrm_db_host" {
  description = "Database host for HRM application"
  type        = string
}

variable "hrm_db_port" {
  description = "Database port for HRM application"
  type        = string
  default     = "3306"
}

variable "hrm_db_name" {
  description = "Database name for HRM application"
  type        = string
}

variable "hrm_db_user" {
  description = "Database user for HRM application"
  type        = string
}

variable "hrm_db_password" {
  description = "Database password for HRM application"
  type        = string
  sensitive   = true
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster created by eksctl"
  type        = string
}