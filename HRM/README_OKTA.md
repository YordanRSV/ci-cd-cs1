Okta integration (HRM)

Quick setup

1. Copy `.env.example` to `.env` and fill `OKTA_DOMAIN` and `OKTA_API_TOKEN`.

2. Run locally with docker-compose (this will use env variables from your shell or .env):

PowerShell

```powershell
# Load env vars from .env (PowerShell)
Get-Content .\.env | Foreach-Object { if ($_ -match "^([^#].+)=(.*)$") { $name=$matches[1]; $value=$matches[2]; $env:$name=$value } }

docker-compose up --build
```

3. Or run the test script locally (requires Python and dependencies installed):

```powershell
# ensure OKTA_DOMAIN and OKTA_API_TOKEN are set in environment
python test_okta.py
```

Notes

- The app expects `OKTA_DOMAIN` (e.g. `https://dev-123456.okta.com`) and `OKTA_API_TOKEN` to be set as environment variables.
- For production, store the Okta API token in a secrets store and inject it into your runtime (do not commit secrets).
- If you need to create an API token: Okta Admin Console → Security → API → Tokens → Create Token.
