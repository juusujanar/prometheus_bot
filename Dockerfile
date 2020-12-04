FROM golang:1.15-alpine3.12 as builder
WORKDIR /src/github.com/juusujanar/prometheus_bot

RUN apk add --no-cache ca-certificates git tzdata

# Create the user and group files that will be used in the running container to
# run the process as an unprivileged user.
RUN mkdir /user && \
    echo 'nobody:x:65534:65534:nobody:/:' > /user/passwd && \
    echo 'nobody:x:65534:' > /user/group

# Set the environment variables for the go command:
ENV CGO_ENABLED=0 GOOS=linux GIN_MODE=release

COPY go.mod go.sum ./

RUN go mod download

COPY ./ ./

# Build the executable to `/app`.
RUN go build -o /app ./main.go

# Final stage: the running container.
FROM scratch AS final

# Import the user and group files from the first stage.
COPY --from=builder /user/group /user/passwd /etc/

# Import the Certificate-Authority certificates for enabling HTTPS.
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Import timezone data
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Import the compiled executable from the second stage.
COPY --from=builder /app /app

# Perform any further action as an unprivileged user.
USER 65534:65534

# Run the compiled binary.
ENTRYPOINT ["/app"]
