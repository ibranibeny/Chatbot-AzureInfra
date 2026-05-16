import logging

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from app.rag.chain import rag_chain
from app.rag.ingest import ingest_documents, list_indexed_documents
from app.models.schemas import ChatRequest, ChatResponse, UploadResponse, DocumentInfo

logging.basicConfig(level=logging.INFO)

app = FastAPI(title="RAG Chatbot API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

MAX_FILE_SIZE = 50 * 1024 * 1024  # 50 MB


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    result = await rag_chain(request.message, request.session_id)
    return ChatResponse(
        answer=result["answer"],
        sources=result.get("sources", []),
    )


@app.post("/upload", response_model=UploadResponse)
async def upload_document(file: UploadFile = File(...)):
    if not file.filename or not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Only PDF files are supported")

    contents = await file.read()
    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="File too large (max 50 MB)")

    try:
        result = ingest_documents(contents, file.filename)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    return UploadResponse(**result)


@app.get("/documents", response_model=list[DocumentInfo])
async def get_documents():
    docs = list_indexed_documents()
    return [DocumentInfo(**d) for d in docs]
