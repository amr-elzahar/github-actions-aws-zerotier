variable "aws_access_key" {
  type        = string
  description = "AWS Access Key ID"
}
variable "aws_secret_access_key" {
  type        = string
  description = "AWS Secret Acces Key"
}
variable "zt_network_id" {
  type        = string
  description = "ZeroTier Network ID"
}
variable "zt_network_cidr" {
  type        = string
  description = "ZeroTier Network CIDR Block"
}