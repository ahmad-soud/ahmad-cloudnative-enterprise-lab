from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(
    title="Ahmad Enterprise API - Phase 3 & 4 Validation",
    version="1.0.0",
    docs_url="/docs",
    redoc_url=None
)

class UserSchema(BaseModel):
    name: str
    email: str

@app.get("/")
def read_root():
    return {"status": "healthy", "message": "Welcome to Ahmad Cloud-Native Enterprise Platform Gateway!"}

@app.get("/users")
def get_all_users():
    return {
        "total_users": 2, 
        "data": [
            {"name": "Ahmad DevOps", "email": "ahmad@enterprise.com"},
            {"name": "Cloud Native User", "email": "user@cloud.com"}
        ]
    }

@app.post("/users")
def create_user(user: UserSchema):
    return {"message": f"User {user.name} queued successfully via SQS pipeline!"}

