# Use this file with `-f docker-bake.hcl`

# Set VERSION
variable "VERSION" {
    default = "latest"
}

group "default" {
    targets = ["code-server"]
}

target "code-server" {
    dockerfile = "./Dockerfile"
    tags = [
        "docker.io/kingsonho/code-server:1.0.0",
        notequal("latest",VERSION) ? "docker.io/kingsonho/code-server:${VERSION}" : "",
    ]
    platforms = ["linux/amd64", "linux/arm64"]
}