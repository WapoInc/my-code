#!/bin/bash
# Deploy an Azure App Service with a Hello World HTML page

# ─── Variables ───────────────────────────────────────────────────────────────
RG="rg-hello-world"
LOCATION="eastus"
APP_PLAN="plan-hello-world"
APP_NAME="app-hello-world-$RANDOM"   # random suffix to ensure global uniqueness
SKU="F1"                             # Free tier
RUNTIME="NODE:20-lts"

# ─── Resource Group ──────────────────────────────────────────────────────────
echo "Creating resource group: $RG"
az group create \
  --name "$RG" \
  --location "$LOCATION" \
  --output table

# ─── App Service Plan ────────────────────────────────────────────────────────
echo "Creating App Service Plan: $APP_PLAN"
az appservice plan create \
  --name "$APP_PLAN" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --sku "$SKU" \
  --is-linux \
  --output table

# ─── Web App ─────────────────────────────────────────────────────────────────
echo "Creating Web App: $APP_NAME"
az webapp create \
  --name "$APP_NAME" \
  --resource-group "$RG" \
  --plan "$APP_PLAN" \
  --runtime "$RUNTIME" \
  --output table

# ─── Hello World HTML ────────────────────────────────────────────────────────
# Write a minimal index.html and deploy it via ZIP deploy
TMPDIR_APP=$(mktemp -d)
cat > "$TMPDIR_APP/index.html" <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Hello World</title>
  <style>
    body {
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      margin: 0;
      font-family: Arial, sans-serif;
      background: #0078d4;
      color: #fff;
    }
    h1 { font-size: 4rem; }
  </style>
</head>
<body>
  <h1>Hello World!</h1>
</body>
</html>
EOF

# Node.js startup file so App Service serves the static HTML
cat > "$TMPDIR_APP/server.js" <<'EOF'
const http = require("http");
const fs   = require("fs");
const path = require("path");

const PORT = process.env.PORT || 8080;
const HTML  = fs.readFileSync(path.join(__dirname, "index.html"));

http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/html" });
  res.end(HTML);
}).listen(PORT, () => console.log(`Listening on port ${PORT}`));
EOF

cat > "$TMPDIR_APP/package.json" <<'EOF'
{
  "name": "hello-world",
  "version": "1.0.0",
  "scripts": { "start": "node server.js" },
  "engines": { "node": ">=20" }
}
EOF

# Zip and deploy
ZIP_PATH="$TMPDIR_APP/deploy.zip"
(cd "$TMPDIR_APP" && zip -r "$ZIP_PATH" index.html server.js package.json > /dev/null)

echo "Deploying Hello World app via ZIP deploy..."
az webapp deploy \
  --name "$APP_NAME" \
  --resource-group "$RG" \
  --src-path "$ZIP_PATH" \
  --type zip \
  --output table

# Cleanup temp files
rm -rf "$TMPDIR_APP"

# ─── Output ──────────────────────────────────────────────────────────────────
APP_URL=$(az webapp show \
  --name "$APP_NAME" \
  --resource-group "$RG" \
  --query "defaultHostName" \
  --output tsv)

echo ""
echo "==========================================="
echo " Deployment complete!"
echo " URL: https://$APP_URL"
echo "==========================================="
