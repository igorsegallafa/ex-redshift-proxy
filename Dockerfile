FROM elixir:1.13.4-otp-25-slim

WORKDIR /app/

EXPOSE 5439

# Install Postgres
RUN apt-get update
RUN apt-get install -y postgresql postgresql-contrib systemd
RUN apt-get install sudo

# Install Hex and Rebar
RUN mix do local.hex --force, local.rebar --force

ENV MIX_ENV=prod

# Dependencies
COPY mix.exs ./
COPY config config
RUN mix deps.get --only $MIX_ENV
RUN mix deps.compile

# Build Project
COPY lib lib
COPY rel rel
RUN mix compile
RUN mix release

COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
