#!/usr/bin/env python3
"""
Reverse Proxy for ngrok Free Tier
Routes path-based requests to different backend servers
"""
from fastapi import FastAPI, Request, Response
import httpx
import uvicorn
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="SRE Agent Backend Proxy")

# Route mapping: path prefix -> backend URL
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

@app.api_route("/{prefix}/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def proxy(prefix: str, path: str, request: Request):
    """
    Proxy requests to backend servers based on path prefix
    """
    route_key = f"/{prefix}"
    base_url = ROUTES.get(route_key)
    
    if not base_url:
        logger.error(f"Unknown route prefix: {prefix}")
        return {"error": f"Unknown route: {prefix}", "available_routes": list(ROUTES.keys())}
    
    # Build target URL
    target_url = f"{base_url}/{path}"
    if request.url.query:
        target_url += f"?{request.url.query}"
    
    logger.info(f"Proxying {request.method} {request.url.path} -> {target_url}")
    
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            # Forward the request
            response = await client.request(
                method=request.method,
                url=target_url,
                headers={k: v for k, v in request.headers.items() 
                        if k.lower() not in ['host', 'content-length']},
                content=await request.body()
            )
            
            # Return the response
            return Response(
                content=response.content,
                status_code=response.status_code,
                headers=dict(response.headers)
            )
    except httpx.RequestError as e:
        logger.error(f"Error proxying request: {e}")
        return {"error": f"Backend request failed: {str(e)}"}

if __name__ == "__main__":
    logger.info("Starting reverse proxy server...")
    logger.info(f"Routes configured: {ROUTES}")
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
