from pydantic import BaseModel

class LogoutSchema(BaseModel):
    refresh_token: str
    
class LogoutResponse(BaseModel):
    detail: str = "Logged out successfully"