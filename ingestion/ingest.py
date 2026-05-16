"""
Document ingestion pipeline:
  1. Parse documents via Document Intelligence (disconnected container on VM)
  2. Chunk text with LangChain text splitters
  3. Embed via Azure AI Foundry (text-embedding-3-small)
  4. Store in Qdrant vector database
"""

import os
import glob
import argparse

from langchain_openai import AzureOpenAIEmbeddings
from langchain_qdrant import QdrantVectorStore
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_community.document_loaders import AzureAIDocumentIntelligenceLoader
from azure.identity import DefaultAzureCredential, get_bearer_token_provider

# --- Configuration ---
DOC_INTEL_ENDPOINT = os.getenv("DOC_INTEL_ENDPOINT", "http://localhost:5050")
QDRANT_URL = os.getenv("QDRANT_URL", "http://localhost:6333")
QDRANT_COLLECTION = os.getenv("QDRANT_COLLECTION", "documents")
AZURE_AI_ENDPOINT = os.getenv("AZURE_AI_ENDPOINT", "")
EMBEDDING_DEPLOYMENT = os.getenv("EMBEDDING_DEPLOYMENT", "text-embedding-3-small")

# --- Azure credential ---
credential = DefaultAzureCredential()
token_provider = get_bearer_token_provider(
    credential, "https://cognitiveservices.azure.com/.default"
)

# --- Embeddings ---
embeddings = AzureOpenAIEmbeddings(
    azure_deployment=EMBEDDING_DEPLOYMENT,
    azure_endpoint=AZURE_AI_ENDPOINT,
    azure_ad_token_provider=token_provider,
    api_version="2024-06-01",
)

# --- Text Splitter ---
text_splitter = RecursiveCharacterTextSplitter(
    chunk_size=1000,
    chunk_overlap=200,
    separators=["\n\n", "\n", ". ", " ", ""],
)


def ingest_file(file_path: str) -> int:
    """Ingest a single document file into Qdrant."""
    print(f">>> Processing: {file_path}")

    # 1. Parse with Document Intelligence
    loader = AzureAIDocumentIntelligenceLoader(
        url_path=None,
        file_path=file_path,
        api_endpoint=DOC_INTEL_ENDPOINT,
        api_key="not-needed",  # Disconnected container doesn't need a key
        api_model="prebuilt-layout",
    )
    documents = loader.load()

    # 2. Chunk
    chunks = text_splitter.split_documents(documents)
    for chunk in chunks:
        chunk.metadata["source"] = os.path.basename(file_path)

    print(f"    Chunks: {len(chunks)}")

    # 3. Embed + Store in Qdrant
    QdrantVectorStore.from_documents(
        documents=chunks,
        embedding=embeddings,
        url=QDRANT_URL,
        collection_name=QDRANT_COLLECTION,
    )

    print(f"    Stored in Qdrant collection: {QDRANT_COLLECTION}")
    return len(chunks)


def main():
    parser = argparse.ArgumentParser(description="Ingest documents into Qdrant")
    parser.add_argument(
        "path",
        help="File or directory path to ingest",
    )
    parser.add_argument(
        "--pattern",
        default="**/*.pdf",
        help="Glob pattern for directory ingestion (default: **/*.pdf)",
    )
    args = parser.parse_args()

    if os.path.isfile(args.path):
        files = [args.path]
    elif os.path.isdir(args.path):
        files = glob.glob(os.path.join(args.path, args.pattern), recursive=True)
    else:
        print(f"Error: {args.path} not found")
        return

    total_chunks = 0
    for f in files:
        total_chunks += ingest_file(f)

    print(f"\n>>> Ingestion complete: {len(files)} files, {total_chunks} chunks")


if __name__ == "__main__":
    main()
