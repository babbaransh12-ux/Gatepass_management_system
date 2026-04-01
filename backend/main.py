import os
import sys
import logging
from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

# Add parent directory to sys.path for absolute imports if needed
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Load environment variables
dotenv_path = os.path.join(os.path.dirname(__file__), "..", ".env")
load_dotenv(dotenv_path)

from db import init_db
from routes.auth_routes import router as auth_router
from routes.student_routes import router as student_router
from routes.warden_routes import router as warden_router
from routes.ivr_routes import router as ivr_router
from routes.qr_routes import router as qr_router

from fastapi.exceptions import RequestValidationError, HTTPException
from starlette.exceptions import HTTPException as StarletteHTTPException

app = FastAPI(
    title="E-Gatepass API",
    description="FastAPI Backend for E-Gatepass System",
    version="2.0.0"
)

# Global Exception Handler to match Frontend expectations
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    status_code = 500
    message = str(exc)
    
    if isinstance(exc, StarletteHTTPException):
        status_code = exc.status_code
        message = exc.detail
    elif isinstance(exc, RequestValidationError):
        status_code = 422
        message = "Validation Error: " + str(exc.errors())
        
    return Response(
        content=f'{{"status": "error", "message": "{message}"}}',
        status_code=status_code,
        media_type="application/json"
    )

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Tunnel Bypass Middleware (for Ngrok/Localtunnel)
@app.middleware("http")
async def bypass_tunnel_warning(request: Request, call_next):
    response = await call_next(request)
    response.headers["Bypass-Tunnel-Reminder"] = "true"
    response.headers["ngrok-skip-browser-warning"] = "true"
    return response

# Initialize Database and Ngrok
@app.on_event("startup")
def startup_event():
    init_db()
    
    # Initialize Ngrok if enabled
    if os.environ.get("USE_NGROK", "false").lower() == "true":
        from pyngrok import ngrok, conf
        
        # Point to local ngrok.exe if it exists in the backend folder
        local_ngrok = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ngrok.exe")
        if os.path.exists(local_ngrok):
            print(f"[NGROK] Using local ngrok.exe at: {local_ngrok}")
            conf.get_default().ngrok_path = local_ngrok
        
        auth_token = os.environ.get("NGROK_AUTHTOKEN", "").strip()
        if not auth_token or auth_token == "your_authtoken_here":
            print("\n[WARNING] NGROK_AUTHTOKEN not set in .env. Please add it to automate ngrok.")
        else:
            try:
                # Check for existing tunnels to avoid duplicates during reload
                tunnels = ngrok.get_tunnels()
                if not tunnels:
                    ngrok.set_auth_token(auth_token)
                    
                    domain = os.environ.get("NGROK_DOMAIN", "").strip()
                    port = int(os.environ.get("PORT", 5000))
                    
                    print(f"\n[NGROK] Attempting to connect to port {port} with domain {domain}...")
                    if domain:
                        public_url = ngrok.connect(port, domain=domain).public_url
                    else:
                        public_url = ngrok.connect(port).public_url
                    
                    print(f"[NGROK] Tunnel established: {public_url}")
                    os.environ["BASE_URL"] = public_url
                else:
                    print(f"\n[NGROK] Tunnel already exists: {tunnels[0].public_url}")
                    os.environ["BASE_URL"] = tunnels[0].public_url
            except Exception as e:
                print(f"\n[ERROR] Failed to start ngrok: {e}")

# Include Routers
app.include_router(auth_router)
app.include_router(student_router)
app.include_router(warden_router)
app.include_router(ivr_router)
app.include_router(qr_router)

@app.get("/")
def read_root():
    return {"message": "E-Gatepass API is operational", "docs": "/docs"}

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 5000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)
