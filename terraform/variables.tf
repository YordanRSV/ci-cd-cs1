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
