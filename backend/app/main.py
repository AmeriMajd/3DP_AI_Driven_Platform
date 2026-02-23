from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def root():
    return {"message": "3DP API Running"}