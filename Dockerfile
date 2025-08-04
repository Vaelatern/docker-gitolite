FROM docker.io/alpine:3.22

# Install OpenSSH server and Gitolite
RUN set -x \
 && apk add --no-cache gitolite openssh

COPY sshd_config.d/*.conf /etc/ssh/sshd_config.d/

# Volume used to store SSH host keys, generated on first run
VOLUME /etc/ssh/keys

# Volume used to store all Gitolite data (keys, config and repositories), initialized on first run
VOLUME /var/lib/gitolite

# Entrypoint responsible for SSH host keys generation, and Gitolite data initialization
COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]

# Expose port 22 to access SSH
EXPOSE 22

# Default command is to run the SSH server
CMD ["/usr/sbin/sshd", "-D"]
