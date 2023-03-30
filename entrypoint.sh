#!/bin/sh

pg_ctlcluster 13 main start

sudo cp /app/config/sql.conf /etc/postgresql/13/main/postgresql.conf
sudo cp /app/config/pg_hba.conf /etc/postgresql/13/main/pg_hba.conf

sudo -u postgres bash -c "psql -c \"CREATE USER dev WITH SUPERUSER password 'password';\""
pg_ctlcluster 13 main restart

# Wait until Postgres is ready
while ! pg_isready -q -h 0.0.0.0 -p 5432 -U dev
do
  echo "$(date) - Waiting for database to start"
  sleep 2
done

bin="/app/_build/prod/rel/ex_redshift_proxy/bin/ex_redshift_proxy"
exec "$bin" "start"
