import os
import sys
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

# Localtunnel Bypass Middleware
@app.middleware("http")
async def bypass_localtunnel(request: Request, call_next):
    response = await call_next(request)
    response.headers["Bypass-Tunnel-Reminder"] = "true"
    return response

# Initialize Database
@app.on_event("startup")
def startup_event():
    init_db()

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
