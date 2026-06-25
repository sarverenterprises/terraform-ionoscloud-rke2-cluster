variable "cluster_name" {
  description = "Cluster name prefix for all networking resources."
  type        = string
}

variable "location" {
  description = "IONOS Cloud Virtual Data Center location."
  type        = string
}

variable "network_cidr" {
  description = "Deprecated compatibility input. IONOS assigns the LAN CIDR; cluster_subnet_cidr controls static node addressing."
  type        = string
}

variable "cluster_subnet_cidr" {
  description = "CIDR used for static private node addressing on the IONOS private LAN."
  type        = string
}

variable "enable_firewall" {
  description = "Enable IONOS public NIC firewall rules on cluster nodes."
  type        = bool
  default     = true
}

variable "trusted_ssh_cidrs" {
  description = "Compatibility input forwarded from root. IONOS public NIC firewall source_ip supports only individual IPv4 addresses or /32 host routes."
  type        = list(string)
  default     = []
}

variable "kube_api_allowed_cidrs" {
  description = "Compatibility input forwarded from root. IONOS public NIC firewall source_ip supports only individual IPv4 addresses or /32 host routes."
  type        = list(string)
  default     = []
}

variable "tailscale_wireguard_allowed_cidrs" {
  description = "Compatibility input forwarded from root. IONOS public NIC firewall source_ip supports only individual IPv4 addresses or /32 host routes."
  type        = list(string)
  default     = []
}

variable "lb_private_ip" {
  description = "Deprecated: provider load balancers are not provisioned."
  type        = string
  default     = null
}

variable "nodeport_allowed_cidrs" {
  description = "Compatibility input forwarded from root. IONOS public NIC firewall source_ip supports only individual IPv4 addresses or /32 host routes."
  type        = list(string)
  default     = []
}

variable "existing_network_id" {
  description = "Deprecated compatibility input. Use existing_private_lan_id instead."
  type        = string
  default     = null
}

variable "existing_datacenter_id" {
  description = "ID of an existing IONOS Virtual Data Center. When null, this module creates one."
  type        = string
  default     = null
}

variable "existing_public_lan_id" {
  description = "ID of an existing public IONOS LAN in the selected datacenter. When null, this module creates one."
  type        = string
  default     = null
}

variable "existing_private_lan_id" {
  description = "ID of an existing private IONOS LAN in the selected datacenter. When null, this module creates one."
  type        = string
  default     = null
}
