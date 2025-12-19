#!/bin/bash

# ==============================================================================
# Ray Converter Lambda - API Testing Guide
# ==============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           🧪 API Testing Guide - cURL & Postman                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# ==============================================================================
# LOCAL TESTING (SAM Local Server)
# ==============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "LOCAL TESTING (SAM Local Server on port 3000)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

LOCAL_URL="http://localhost:3000/ray"

echo "📍 Endpoint: $LOCAL_URL"
echo ""
echo "1️⃣  BASIC REQUEST (X, Y, Z coordinates):"
echo ""
echo "curl -X POST $LOCAL_URL \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"ray\": {\"x\": 10, \"y\": 20, \"z\": 30}}'"
echo ""

echo "2️⃣  REQUEST WITH LABELS:"
echo ""
echo "curl -X POST $LOCAL_URL \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"ray\": {\"x\": 5, \"y\": 15, \"label\": \"test-ray\"}}'"
echo ""

echo "3️⃣  EMPTY RAY DATA:"
echo ""
echo "curl -X POST $LOCAL_URL \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"ray\": {}}'"
echo ""

echo "4️⃣  COMPLEX DATA:"
echo ""
echo "curl -X POST $LOCAL_URL \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"ray\": {\"coordinates\": [1, 2, 3], \"intensity\": 100, \"wavelength\": 532}}'"
echo ""

# ==============================================================================
# AWS CLOUD TESTING
# ==============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "AWS CLOUD TESTING (After deployment)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

AWS_URL="https://<YOUR-API-ID>.execute-api.us-east-1.amazonaws.com/dev/ray"

echo "📍 Endpoint: $AWS_URL"
echo ""
echo "Replace <YOUR-API-ID> with your actual API Gateway ID"
echo ""
echo "curl -X POST $AWS_URL \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"ray\": {\"x\": 10, \"y\": 20, \"z\": 30}}'"
echo ""

# ==============================================================================
# POSTMAN COLLECTION (JSON Format)
# ==============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "POSTMAN SETUP INSTRUCTIONS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Open Postman"
echo "2. Create NEW REQUEST"
echo "3. Set Method: POST"
echo "4. Set URL: http://localhost:3000/ray"
echo "5. Go to HEADERS tab"
echo "6. Add: Content-Type: application/json"
echo "7. Go to BODY tab"
echo "8. Select 'raw' format"
echo "9. Select 'JSON' from dropdown"
echo "10. Copy and paste one of the JSON examples below"
echo "11. Click SEND"
echo ""

# ==============================================================================
# JSON EXAMPLES FOR POSTMAN BODY
# ==============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "JSON EXAMPLES FOR POSTMAN BODY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📋 Example 1: Simple Coordinates"
echo "────────────────────────────────────────"
cat << 'JSON1'
{
  "ray": {
    "x": 10,
    "y": 20,
    "z": 30
  }
}
JSON1
echo ""

echo "📋 Example 2: With Label"
echo "────────────────────────────────────────"
cat << 'JSON2'
{
  "ray": {
    "x": 5,
    "y": 15,
    "z": 25,
    "label": "test-ray-001"
  }
}
JSON2
echo ""

echo "📋 Example 3: Complex Structure"
echo "────────────────────────────────────────"
cat << 'JSON3'
{
  "ray": {
    "coordinates": [1, 2, 3],
    "intensity": 100,
    "wavelength": 532,
    "polarization": "vertical",
    "source": "laser"
  }
}
JSON3
echo ""

echo "📋 Example 4: Array Data"
echo "────────────────────────────────────────"
cat << 'JSON4'
{
  "ray": {
    "points": [
      {"x": 0, "y": 0, "z": 0},
      {"x": 1, "y": 1, "z": 1},
      {"x": 2, "y": 2, "z": 2}
    ],
    "path": "linear"
  }
}
JSON4
echo ""

# ==============================================================================
# EXPECTED RESPONSES
# ==============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "EXPECTED RESPONSES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "✅ SUCCESS Response (Status: 200)"
echo "────────────────────────────────────────"
cat << 'RESPONSE1'
{
  "statusCode": 200,
  "body": {
    "standard": {
      "x": 10,
      "y": 20,
      "z": 30
    },
    "timestamp": "test-request-id-123"
  }
}
RESPONSE1
echo ""

echo "⚠️  ERROR Response (Status: 500)"
echo "────────────────────────────────────────"
cat << 'RESPONSE2'
{
  "statusCode": 500,
  "body": {
    "error": "Invalid request format"
  }
}
RESPONSE2
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║            Ready to test! Use any command above               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
