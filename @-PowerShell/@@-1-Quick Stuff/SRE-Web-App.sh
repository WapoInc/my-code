#!/bin/bash
#===============================================================================
# Deploy Azure Web App - Hello World
# Deploys a simple Web App displaying "Hello World" in Helvetica 22pt
#
# Usage: ./Deploy-WebApp-HelloWorld.sh
#        ./Deploy-WebApp-HelloWorld.sh -g MyResourceGroup -n MyWebApp -l eastus
#===============================================================================

set -e

# ---------- Default Parameters ----------
RESOURCE_GROUP="rg-helloworld2"
WEBAPP_NAME="webapp-helloworld-$(date +%s | tail -c 7)"
LOCATION="southafricanorth"
SKU="F1"

# ---------- Parse Arguments ----------
while [[ $# -gt 0 ]]; do
  case $1 in
    -g|--resource-group) RESOURCE_GROUP="$2"; shift 2;;
    -n|--name)           WEBAPP_NAME="$2";    shift 2;;
    -l|--location)       LOCATION="$2";       shift 2;;
    -s|--sku)            SKU="$2";            shift 2;;
    -h|--help)
      echo "Usage: $0 [-g resource-group] [-n webapp-name] [-l location] [-s sku]"
      echo "  -g  Resource group name   (default: rg-helloworld)"
      echo "  -n  Web app name          (default: webapp-helloworld-<random>)"
      echo "  -l  Azure region          (default: southafricanorth)"
      echo "  -s  App Service Plan SKU  (default: F1)"
      exit 0;;
    *) echo "Unknown option: $1"; exit 1;;
  esac
done

APP_SERVICE_PLAN="asp-${WEBAPP_NAME}"

echo "============================================"
echo " Azure Web App Deployment - Hello World"
echo "============================================"
echo " Resource Group : $RESOURCE_GROUP"
echo " Web App Name   : $WEBAPP_NAME"
echo " Location       : $LOCATION"
echo " SKU            : $SKU"
echo " App Svc Plan   : $APP_SERVICE_PLAN"
echo "============================================"
echo ""

# ---------- Step 1: Create Resource Group ----------
echo "[1/5] Creating Resource Group: $RESOURCE_GROUP ..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output none

# ---------- Step 2: Create App Service Plan ----------
echo "[2/5] Creating App Service Plan: $APP_SERVICE_PLAN ..."
az appservice plan create \
  --name "$APP_SERVICE_PLAN" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku "$SKU" \
  --is-linux \
  --output none

# ---------- Step 3: Create Web App ----------
echo "[3/5] Creating Web App: $WEBAPP_NAME ..."
az webapp create \
  --name "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --plan "$APP_SERVICE_PLAN" \
  --runtime "NODE:22-lts" \
  --output none

# ---------- Step 4: Create Hello World HTML ----------
echo "[4/5] Preparing Hello World application ..."

TMPDIR=$(mktemp -d)

cat > "$TMPDIR/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hello World</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            background-color: #ffffff;
        }
        h1 {
            font-family: Helvetica, Arial, sans-serif;
            font-size: 22pt;
            color: #333333;
        }
    </style>
</head>
<body>
    <h1>Hello World</h1>
</body>
</html>
HTMLEOF

# Create a simple Node.js server to serve the HTML
cat > "$TMPDIR/index.js" << 'JSEOF'
const http = require("http");
const fs   = require("fs");
const path = require("path");

const html = fs.readFileSync(path.join(__dirname, "index.html"), "utf8");
const port = process.env.PORT || 8080;

http.createServer((req, res) => {
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    res.end(html);
}).listen(port, () => {
    console.log(`Server running on port ${port}`);
});
JSEOF

cat > "$TMPDIR/package.json" << 'PKGEOF'
{
  "name": "hello-world-webapp",
  "version": "1.0.0",
  "description": "Hello World - Helvetica 22pt",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  }
}
PKGEOF

# ---------- Step 5: Deploy via ZIP ----------
echo "[5/5] Deploying application to Azure ..."

ZIPFILE="$TMPDIR/app.zip"
(cd "$TMPDIR" && zip -q "$ZIPFILE" index.html index.js package.json)

az webapp deploy \
  --name "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --src-path "$ZIPFILE" \
  --type zip \
  --output none

# Cleanup temp files
rm -rf "$TMPDIR"

# ---------- Done ----------
WEBAPP_URL="https://${WEBAPP_NAME}.azurewebsites.net"

echo ""
echo "============================================"
echo " Deployment Complete!"
echo "============================================"
echo " URL: $WEBAPP_URL"
echo ""
echo " To delete all resources when done:"
echo "   az group delete --name $RESOURCE_GROUP --yes --no-wait"
echo "============================================"
