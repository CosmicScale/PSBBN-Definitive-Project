# The Linux side of tests/e2e-docker.sh. linux/amd64 because the project's
# Linux helpers (scripts/helper/*.elf) are x86-64 binaries; on Apple silicon
# Docker runs them translated. Loop devices, device-mapper and ext2 are the
# Docker VM's Linux kernel, so the container runs privileged.
FROM --platform=linux/amd64 debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        busybox-static dmsetup e2fsprogs gcc libc6-dev python3 \
    && rm -rf /var/lib/apt/lists/*
COPY linux-check.sh /usr/local/bin/linux-check.sh
ENTRYPOINT ["/usr/local/bin/linux-check.sh"]
