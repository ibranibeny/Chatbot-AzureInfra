from pydantic import BaseModel, Field


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=4096)
    session_id: str | None = None


class ChatResponse(BaseModel):
    answer: str
    sources: list[str] = []


class UploadResponse(BaseModel):
    filename: str
    pages: int
    chunks: int


class DocumentInfo(BaseModel):
    source: str
