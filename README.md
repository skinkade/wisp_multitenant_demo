# Gleam + Wisp + Lustre Multi-tenant Application Demo

```shell
# Database
docker-compose up -d
echo 'DATABASE_URL="postgres://postgres:postgres@127.0.0.1:5432/wisp_multitenant_demo?sslmode=disable"' > .env
dbmate migrate

# CSS
npm i
npx tailwindcss -i ./priv/tailwind.css -o ./priv/static/css/main.css

# Gleam application
gleam run
```