"""
Real-time document ingestion:
  1. Parse PDF with pypdf
  2. Chunk with LangChain text splitters
  3. Embed via Azure AI Foundry (reuses chain.py embeddings)
  4. Store in Qdrant
"""

import logging
from io import BytesIO

from pypdf import PdfReader
from langchain_core.documents import Document
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_qdrant import QdrantVectorStore
from qdrant_client import QdrantClient

from app.rag.chain import embeddings, QDRANT_URL, QDRANT_COLLECTION

logger = logging.getLogger(__name__)

text_splitter = RecursiveCharacterTextSplitter(
    chunk_size=1000,
    chunk_overlap=200,
    separators=["\n\n", "\n", ". ", " ", ""],
)


def parse_pdf(file_bytes: bytes, filename: str) -> list[Document]:
    """Extract text from PDF and return LangChain Documents."""
    reader = PdfReader(BytesIO(file_bytes))
    documents = []
    for i, page in enumerate(reader.pages):
        text = page.extract_text() or ""
        if text.strip():
            documents.append(Document(
                page_content=text,
                metadata={"source": filename, "page": i + 1},
            ))
    return documents


def ingest_documents(file_bytes: bytes, filename: str) -> dict:
    """Parse, chunk, embed and store a PDF in Qdrant."""
    # 1. Parse PDF
    raw_docs = parse_pdf(file_bytes, filename)
    if not raw_docs:
        raise ValueError(f"No text could be extracted from {filename}")

    # 2. Chunk
    chunks = text_splitter.split_documents(raw_docs)
    for chunk in chunks:
        chunk.metadata["source"] = filename

    logger.info("Ingesting %s: %d pages, %d chunks", filename, len(raw_docs), len(chunks))

    # 3. Embed + Store in Qdrant
    QdrantVectorStore.from_documents(
        documents=chunks,
        embedding=embeddings,
        url=QDRANT_URL,
        collection_name=QDRANT_COLLECTION,
    )

    return {
        "filename": filename,
        "pages": len(raw_docs),
        "chunks": len(chunks),
    }


def list_indexed_documents() -> list[dict]:
    """List unique source documents in the Qdrant collection."""
    try:
        client = QdrantClient(url=QDRANT_URL)
        collections = client.get_collections().collections
        if not any(c.name == QDRANT_COLLECTION for c in collections):
            return []

        sources = set()
        offset = None
        while True:
            results, offset = client.scroll(
                collection_name=QDRANT_COLLECTION,
                limit=100,
                offset=offset,
                with_payload=True,
                with_vectors=False,
            )
            for point in results:
                src = point.payload.get("metadata", {}).get("source", "")
                if src:
                    sources.add(src)
            if offset is None:
                break

        return [{"source": s} for s in sorted(sources)]
    except Exception as e:
        logger.warning("Error listing documents: %s", e)
        return []
