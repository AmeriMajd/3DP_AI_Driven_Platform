from pydantic import BaseModel

class RefreshTokenSchema(BaseModel) :
  refresh_token: str
  
class RefreshTokenResponse(BaseModel):
  access_token: str
  token_type: str = "bearer"
