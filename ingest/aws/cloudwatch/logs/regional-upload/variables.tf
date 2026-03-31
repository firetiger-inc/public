variable "ingester_source" {
  description = "Path to the ingester Lambda zip file"
  type        = string
}

variable "ingester_etag" {
  description = "MD5 hash of the ingester Lambda zip for change detection"
  type        = string
}

variable "filter_manager_source" {
  description = "Path to the filter manager Lambda zip file"
  type        = string
}

variable "filter_manager_etag" {
  description = "MD5 hash of the filter manager Lambda zip for change detection"
  type        = string
}
