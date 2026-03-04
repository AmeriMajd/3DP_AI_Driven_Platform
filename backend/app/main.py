from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.database import engine, Base

# ── Import ALL models before create_all ───────────────────────────────────────
import app.models.user
import app.models.invitation
import app.models.refresh_token
import app.models.password_reset_token

# ── Import routers ─────────────────────────────────────────────────────────────
from app.routers import auth, admin, invitations
from app.routers import refresh    
from app.routers import password_reset  
                # NEW

# ── Create all tables ──────────────────────────────────────────────────────────
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="3DP Intelligence Platform",
    version="1.0.0",
    description="AI-Driven Additive Manufacturing Platform API"
)

# ── CORS ───────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ────────────────────────────────────────────────────────────────────
app.include_router(auth.router)
app.include_router(refresh.router)                 # NEW
app.include_router(admin.router)
app.include_router(invitations.router)
app.include_router(password_reset.router)  



@app.get("/", tags=["Health"])
def root():
    return {"message": "3DP API is running"}

@app.get("/health", tags=["Health"])
def health():
    return {"status": "ok"}

# DELETE before merging to main
@app.get("/dev/token", tags=["Dev"])
def get_dev_token():
    import uuid
    from app.core.security import create_access_token
    fake_id = str(uuid.uuid4())
    token = create_access_token({"sub": fake_id, "role": "admin"})
    return {"token": token, "usage": f"Bearer {token}"}