#!/bin/sh

[ -d /docker-entrypoint.d/stage1 ] && for file in /docker-entrypoint.d/stage1/*.sh; do
	if [ -x "$file" ]; then
		"${file}"
	elif [ -f "$file" -a -r "$file" ]; then
		. "${file}"
	fi
done

(
	exec 2>/dev/null
	cd /etc/ssh/keys
	for f in ssh_host_*_key; do
		cp "$f" ../"$f"
	done
)

# Generate new keys if they don't yet exist
ssh-keygen -A

(
	cd /etc/ssh
	for f in ssh_host_*_key; do
		[ ! -f keys/"$f" ] && mv "$f" keys/"$f" || rm "$f"
	done
)

[ -d /docker-entrypoint.d/stage2 ] && for file in /docker-entrypoint.d/stage2/*.sh; do
	if [ -x "$file" ]; then
		"${file}"
	elif [ -f "$file" -a -r "$file" ]; then
		. "${file}"
	fi
done


: ${GIT_USER:=git}
: ${DEFAULT_BRANCH:=master}

[ "${GIT_USER}" == "git" ] && deluser "${GIT_USER}"
[ "${GIT_USER}" == "git" ] || addgroup -S "${GIT_USER}"
adduser -S -D -h /var/lib/gitolite -s /bin/sh "${GIT_USER}"
passwd -u "${GIT_USER}" # Remove pass, otherwise user is locked and no auth ever works

[ -d /docker-entrypoint.d/stage3 ] && for file in /docker-entrypoint.d/stage3/*.sh; do
	if [ -x "$file" ]; then
		"${file}"
	elif [ -f "$file" -a -r "$file" ]; then
		. "${file}"
	fi
done

# Useful dirs for customization
for dir in commands hooks/repo-specific syntactic-sugar triggers VREF; do
	[ ! -d "/var/lib/gitolite/local/${dir}" ] && mkdir -p "/var/lib/gitolite/local/${dir}"
done

# Fix permissions at every startup
chown -R "${GIT_USER}:${GIT_USER}" "/var/lib/gitolite"

[ ! -f "/var/lib/gitolite/.gitconfig" ] && cat >"/var/lib/gitolite/.gitconfig" <<EOF
[init]
  defaultBranch = ${DEFAULT_BRANCH}
EOF

[ -n "$GITOLITE_RC" ] && echo "$GITOLITE_RC" > /var/lib/gitolite/.gitolite.rc

[ -d /docker-entrypoint.d/stage4 ] && for file in /docker-entrypoint.d/stage4/*.sh; do
	if [ -x "$file" ]; then
		"${file}"
	elif [ -f "$file" -a -r "$file" ]; then
		. "${file}"
	fi
done

# Setup gitolite admin
if [ ! -f "/var/lib/gitolite/.ssh/authorized_keys" ]; then
  if [ -n "$SSH_KEY" ]; then
    [ -n "$SSH_KEY_NAME" ] || SSH_KEY_NAME=admin
    echo "$SSH_KEY" > "/tmp/$SSH_KEY_NAME.pub"
    su - "${GIT_USER}" -c "gitolite setup -pk '/tmp/${SSH_KEY_NAME}.pub'"
    rm "/tmp/$SSH_KEY_NAME.pub"
  else
    echo "You need to specify SSH_KEY on first run to setup gitolite"
    echo "You can also use SSH_KEY_NAME to specify the key name (optional)"
    echo 'Example: docker run -e SSH_KEY="$(cat ~/.ssh/id_ed25519.pub)" -e SSH_KEY_NAME="$(whoami)" ghcr.io/Vaelatern/gitolite'
    exit 1
  fi
# Check setup at every startup
else
  su - "${GIT_USER}" -c "gitolite setup"
fi

# Ignore stages. This time it's just a matter of doing it.
[ -d /docker-entrypoint.d ] && for file in /docker-entrypoint.d/*.sh; do
	if [ -x "$file" ]; then
		"${file}"
	elif [ -f "$file" -a -r "$file" ]; then
		. "${file}"
	fi
done

exec "$@"
