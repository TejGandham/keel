FROM elixir:1.19-slim

RUN apt-get update && \
    apt-get install -y git inotify-tools curl && \
    rm -rf /var/lib/apt/lists/* && \
    git config --global --add safe.directory '*' && \
    git config --global credential.helper store

# Install GitHub CLI for git credential authentication
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix archive.install hex phx_new --force

WORKDIR /app

EXPOSE 4000

CMD ["mix", "phx.server"]
