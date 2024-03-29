variable "DOCKER_REGISTRY" {
  default = "ghcr.io"
}
variable "DOCKER_ORG" {
  default = "darpa-askem"
}
variable "VERSION" {
  default = "local"
}

# ----------------------------------------------------------------------------------------------------------------------

function "tag" {
  params = [image_name, prefix, suffix]
  result = [ "${DOCKER_REGISTRY}/${DOCKER_ORG}/${image_name}:${check_prefix(prefix)}${VERSION}${check_suffix(suffix)}" ]
}

function "check_prefix" {
  params = [tag]
  result = notequal("",tag) ? "${tag}-": ""
}

function "check_suffix" {
  params = [tag]
  result = notequal("",tag) ? "-${tag}": ""
}

# ----------------------------------------------------------------------------------------------------------------------

group "prod" {
  targets = ["simulation-service"]
}

group "default" {
  targets = ["simulation-service-base"]
}

# ----------------------------------------------------------------------------------------------------------------------

# Removed linux/arm64 for now to ass CI build - Dec 2022
target "_platforms" {
  platforms = ["linux/amd64"]
}

target "simulation-service-base" {
	context = "."
	tags = tag("simulation-service", "", "")
	dockerfile = "Dockerfile"
}

target "simulation-service" {
  inherits = ["_platforms", "simulation-service-base"]
}
