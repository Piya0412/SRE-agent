#!/usr/bin/env python3
"""
Reverse proxy for routing ngrok traffic to multiple backend servers.
Routes requests based on path prefix to different backend ports.
"""
from fastapi import FastAPI, Request, Response
from fastapi.responses import JSONResponse
import httpx
import uvicorn
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="SRE Agent Proxy")

# Route mapping: prefix -> backend URL
ROUTES = {
    "/k8s": "http://127.0.0.1:8011",
    "/logs": "http://127.0.0.1:8012",
    "/metrics": "http://127.0.0.1:8013",
    "/runbooks": "http://127.0.0.1:8014",
}

@app.get("/health")
async def health():
    """Health check endpoint"""
    return {"status": "healthy", "routes": list(ROUTES.keys())}

@app.api_route("/{prefix}/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"])
async def proxy(prefix: str, path: str, request: Request):
    """
    Proxy requests to backend servers based on path prefix.
    
    Examples:
        /k8s/pods/status -> http://127.0.0.1:8011/pods/status
        /logs/search -> http://127.0.0.1:8012/search
    """
    route_key = f"/{prefix}"
    base_url = ROUTES.get(route_key)
    
    if not base_url:
        logger.error(f"Unknown route prefix: {prefix}")
        return JSONResponse(
            status_code=404,
            content={"error": f"Unknown route prefix: {prefix}", "available": list(ROUTES.keys())}
        )
    
    # Build target URL
    target_url = f"{base_url}/{path}"
    if request.url.query:
        target_url = f"{target_url}?{request.url.query}"
    
    logger.info(f"Proxying {request.method} {request.url.path} -> {target_url}")
    
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            # Forward the request
            response = await client.request(
                method=request.method,
                url=target_url,
                headers={k: v for k, v in request.headers.items() 
                        if k.lower() not in ['host', 'content-length']},
                content=await request.body(),
            )
            
            # Return the response
            return Response(
                content=response.content,
                status_code=response.status_code,
                headers=dict(response.headers),
            )
    except httpx.RequestError as e:
        logger.error(f"Error proxying request to {target_url}: {e}")
        return JSONResponse(
            status_code=502,
            content={"error": "Backend service unavailable", "details": str(e)}
        )

if __name__ == "__main__":
    print("🚀 Starting SRE Agent Reverse Proxy on port 8000")
    print("📍 Routes:")
    for prefix, backend in ROUTES.items():
        print(f"   {prefix}/* → {backend}")
    print()
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
