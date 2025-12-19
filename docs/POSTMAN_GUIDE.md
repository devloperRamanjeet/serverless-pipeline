````markdown
# 📮 POSTMAN LOCAL API TESTING GUIDE

## Prerequisites

1. **Start SAM Local Server** (in one terminal):
```bash
cd /Users/ramanjeet/devlopment/serverless-AiMl
sam local start-api --port 3000
```

2. **Server Running At:**
```
http://localhost:3000
```

---

## Step-by-Step Postman Setup

### Step 1: Open Postman
- Launch Postman (download from https://www.postman.com/downloads/)

### Step 2: Create New Request
```
Click: + (New Tab)  OR  File → New → Request
```

### Step 3: Set Request Method & URL
```
Method:  POST
URL:     http://localhost:3000/ray
```

### Step 4: Add Headers
```
Go to HEADERS tab
Click "Add" button

Header Name:  Content-Type
Header Value: application/json
```

### Step 5: Add Request Body
```
Go to BODY tab
Select: raw (radio button)
Select: JSON (from dropdown on right)
Paste your JSON data (see examples below)
```

### Step 6: Send Request
```
Click the SEND button (blue button on right)
```

---

## JSON Examples for BODY

### Example 1: Basic Coordinates
```json
{
  "ray": {
    "x": 10,
    "y": 20,
    "z": 30
  }
}
```

**Expected Response:**
```json
{
  "statusCode": 200,
  "body": "{\"standard\": {\"x\": 10, \"y\": 20, \"z\": 30}, \"timestamp\": \"aws-request-id\"}"
}
```

---

### Example 2: With Label
```json
{
  "ray": {
    "x": 5,
    "y": 15,
    "z": 25,
    "label": "test-ray-001"
  }
}
```

---

### Example 3: Complex Structure
```json
{
  "ray": {
    "coordinates": [1, 2, 3],
    "intensity": 100,
    "wavelength": 532,
    "polarization": "vertical",
    "source": "laser"
  }
}
```

---

### Example 4: Array of Points
```json
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
```

---

### Example 5: Empty Ray
```json
{
  "ray": {}
}
```

**Expected Response:**
```json
{
  "statusCode": 200,
  "body": "{\"standard\": {}, \"timestamp\": \"aws-request-id\"}"
}
```

---

### Example 6: Nested Complex Data
```json
{
  "ray": {
    "metadata": {
      "timestamp": "2025-12-19T12:00:00Z",
      "source": "sensor-1",
      "quality": 0.95
    },
    "data": {
      "intensity": 150,
      "frequency": 532,
      "phase": 45.5
    },
    "calibration": {
      "offset": [0.1, 0.2, 0.3],
      "scale": 1.0
    }
  }
}
```

---

## Testing Workflow

### Test 1: Verify Server is Running
1. Send Example 1 (Basic Coordinates)
2. Should get Status **200 OK**
3. Response body should contain your data

### Test 2: Test Error Handling
1. Send Example 5 (Empty Ray)
2. Should still get Status **200 OK**
3. Response should have empty `standard` object

### Test 3: Test Complex Data
1. Send Example 3 or 6
2. Should get Status **200 OK**
3. All your data should be in `standard` field

---

## Expected Response Format

All successful responses follow this format:

```json
{
  "statusCode": 200,
  "body": {
    "standard": {
      // Your ray data echoed back
    },
    "timestamp": "aws-request-id-123"
  }
}
```

---

## Troubleshooting

### ❌ "Connection Refused" Error
```
Issue: Server not running
Solution: Start SAM server in another terminal
         sam local start-api --port 3000
```

### ❌ "400 Bad Request"
```
Issue: JSON syntax error
Solution: Check JSON is valid (use JSON validator)
         Verify headers include: Content-Type: application/json
```

### ❌ "405 Method Not Allowed"
```
Issue: Using wrong HTTP method
Solution: Make sure method is set to POST (not GET, PUT, etc)
```

### ❌ "Cannot GET /ray"
```
Issue: Using GET instead of POST
Solution: Change method from GET to POST
```

---

## Quick Copy-Paste Template

Use this template in Postman BODY for quick testing:

```json
{
  "ray": {
    "x": 10,
    "y": 20,
    "z": 30
  }
}
```

Just change the values and send!

---

## Alternative: Using cURL Command

If you prefer command line, use this template:

```bash
curl -X POST http://localhost:3000/ray \
  -H "Content-Type: application/json" \
  -d '{"ray": {"x": 10, "y": 20, "z": 30}}'
```

---

## Save as Postman Collection

To save these requests for future use:

1. **Create Collection:**
   - File → New → Collection
   - Name: "Ray Converter API"

2. **Add Requests to Collection:**
   - Create each request above
   - Add to the collection

3. **Export Collection:**
   - Right-click collection → Export
   - Save as JSON file
   - Share with team

---

## API Documentation

| Property | Type | Description |
|----------|------|-------------|
| `ray` | object | Main data container |
| `ray.x` | number | X coordinate |
| `ray.y` | number | Y coordinate |
| `ray.z` | number | Z coordinate |
| `ray.label` | string | Optional label |

---

## Performance Testing

Test with larger payloads:

```json
{
  "ray": {
    "data_points": 1000,
    "arrays": [[1, 2, 3], [4, 5, 6], [7, 8, 9]],
    "nested": {
      "level1": {
        "level2": {
          "level3": {
            "value": "deep data"
          }
        }
      }
    }
  }
}
```

---

## Next Steps

✅ Test locally with Postman/cURL  
✅ Run unit tests: `pytest functions/ray_converter/tests/ -v`  
✅ Deploy to AWS: `cd infra && terraform apply`  
✅ Test on AWS with Postman (change URL to API Gateway endpoint)

````