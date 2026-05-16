import os
import logging

from langchain_openai import ChatOpenAI, AzureOpenAIEmbeddings
from langchain_qdrant import QdrantVectorStore
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from azure.identity import DefaultAzureCredential, get_bearer_token_provider

logger = logging.getLogger(__name__)

# --- Configuration from environment ---
QDRANT_URL = os.getenv("QDRANT_URL", "http://10.0.1.4:6333")
QDRANT_COLLECTION = os.getenv("QDRANT_COLLECTION", "documents")
VLLM_BASE_URL = os.getenv("VLLM_BASE_URL", "http://10.0.2.4:8000/v1")
VLLM_MODEL = os.getenv("VLLM_MODEL", "Qwen/Qwen3.5-9B")

# Azure AI Foundry (embeddings via managed identity)
AZURE_AI_ENDPOINT = os.getenv("AZURE_AI_ENDPOINT", "")
EMBEDDING_DEPLOYMENT = os.getenv("EMBEDDING_DEPLOYMENT", "text-embedding-3-small")

# --- Azure credential (managed identity in production, CLI locally) ---
credential = DefaultAzureCredential()
token_provider = get_bearer_token_provider(
    credential, "https://cognitiveservices.azure.com/.default"
)

# --- Embeddings (Azure OpenAI via managed identity) ---
embeddings = AzureOpenAIEmbeddings(
    azure_deployment=EMBEDDING_DEPLOYMENT,
    azure_endpoint=AZURE_AI_ENDPOINT,
    azure_ad_token_provider=token_provider,
    api_version="2024-06-01",
)

# --- LLM (vLLM with OpenAI-compatible API) ---
llm = ChatOpenAI(
    base_url=VLLM_BASE_URL,
    api_key="not-needed",  # vLLM doesn't require an API key
    model=VLLM_MODEL,
    temperature=0.7,
    max_tokens=2048,
)

# --- RAG Prompt ---
RAG_PROMPT = ChatPromptTemplate.from_messages([
    ("system", (
        "You are a helpful assistant. Answer the user's question based on the "
        "provided context. If the context doesn't contain enough information, "
        "say so honestly. Always cite your sources.\n\n"
        "Context:\n{context}"
    )),
    ("human", "{question}"),
])


def _format_docs(docs):
    return "\n\n---\n\n".join(doc.page_content for doc in docs)


def _get_sources(docs):
    sources = []
    for doc in docs:
        src = doc.metadata.get("source", "")
        if src and src not in sources:
            sources.append(src)
    return sources


def _get_retriever():
    """Get retriever — returns None if Qdrant collection doesn't exist yet."""
    try:
        vs = QdrantVectorStore.from_existing_collection(
            embedding=embeddings,
            collection_name=QDRANT_COLLECTION,
            url=QDRANT_URL,
        )
        return vs.as_retriever(search_kwargs={"k": 5})
    except Exception as e:
        logger.warning("Qdrant collection not ready: %s", e)
        return None


async def rag_chain(question: str, session_id: str | None = None) -> dict:
    retriever = _get_retriever()
    if retriever is None:
        return {
            "answer": "No documents have been uploaded yet. Please upload a PDF first using the sidebar.",
            "sources": [],
        }

    docs = await retriever.ainvoke(question)
    if not docs:
        return {
            "answer": "No relevant documents found for your question.",
            "sources": [],
        }

    context = _format_docs(docs)
    chain = RAG_PROMPT | llm | StrOutputParser()
    answer = await chain.ainvoke({"context": context, "question": question})
    return {
        "answer": answer,
        "sources": _get_sources(docs),
    }
