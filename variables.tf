variable "project" {
    default = "roboshop"
}

variable "Environment" {
    default = "dev"
}

variable "component" {
    type = string
    
}

variable "Zone_id" {
    default = "Z02160638EY77GSSE3BP"
}

variable "domain_name" {
    default = "dpavan.online"
}



variable "health_check_path" {
        default = "/health"
}

variable "port_number" {
        default = 8080
}

variable "rule_priority" {
    type = number
}