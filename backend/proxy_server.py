#!/usr/bin/env python3
"""
Simple reverse proxy server for routing requests to backend APIs.
Routes based on URL path prefix to different backend ports.
"""

from fastapi import FastAPI, Request, Response
from fastapi.responses import StreamingResponse
import httpx
import uvicorn

app = FastAPI(title="SRE Agent Proxy")

# Backend service mapping
BACKEND_SERVICES = {
    "/k8s": "http://127.0.0.1:8011",
    "/logs": "http://127.0.0.1:8012",
    "/metrics": "http://127.0.0.1:8013",
    "/runbooks": "http://127.0.0.1:8014",
}

@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD"])
async def proxy(path: str, request: Request):
    """Proxy all requests to appropriate backend service."""
    
    # Determine which backend to route to
    backend_url = None
    service_prefix = None
    
    for prefix, url in BACKEND_SERVICES.items():
        if path.startswith(prefix.lstrip("/")):
            backend_url = url
            service_prefix = prefix.lstrip("/")
            break
    
    if not backend_url:
        return Response(content="Service not found", status_code=404)
    
    # Remove service prefix from path
    if service_prefix:
        remaining_path = path[len(service_prefix):]
    else:
        remaining_path = path
    
    # Build target URL
    target_url = f"{backend_url}{remaining_path}"
    
    # Get query parameters
    query_string = str(request.url.query)
    if query_string:
        target_url = f"{target_url}?{query_string}"
    
    # Forward the request
    async with httpx.AsyncClient() as client:
        # Get request body
        body = await request.body()
        
        # Forward headers (excluding host)
        headers = dict(request.headers)
        headers.pop("host", None)
        
        try:
            # Make request to backend
            response = await client.request(
                method=request.method,
                url=target_url,
                content=body,
                headers=headers,
                timeout=30.0
            )
            
            # Return response
            return Response(
                content=response.content,
                status_code=response.status_code,
                headers=dict(response.headers)
            )
        except Exception as e:
            return Response(
                content=f"Proxy error: {str(e)}",
                status_code=502
            )

@app.get("/health")
async def health():
    """Health check endpoint."""
    return {"status": "healthy", "service": "proxy"}

if __name__ == "__main__":
    print("🚀 Starting SRE Agent Proxy Server on port 8000")
    print("📊 Routing:")
    for prefix, url in BACKEND_SERVICES.items():
        print(f"   {prefix} -> {url}")
    
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
