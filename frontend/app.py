import os
import uuid

import httpx
import streamlit as st

BACKEND_URL = os.getenv("BACKEND_URL", "http://localhost:8080")

st.set_page_config(page_title="RAG Chatbot", page_icon="🤖", layout="centered")

# --- Sidebar: Document Upload ---
with st.sidebar:
    st.header("📄 Documents")

    uploaded_file = st.file_uploader(
        "Upload a PDF document",
        type=["pdf"],
        help="Upload a PDF to add it to the knowledge base",
    )

    if uploaded_file is not None:
        if st.button("📤 Upload & Index", use_container_width=True):
            with st.spinner(f"Processing {uploaded_file.name}..."):
                try:
                    resp = httpx.post(
                        f"{BACKEND_URL}/upload",
                        files={"file": (uploaded_file.name, uploaded_file.getvalue(), "application/pdf")},
                        timeout=300.0,
                    )
                    resp.raise_for_status()
                    data = resp.json()
                    st.success(
                        f"✅ **{data['filename']}**\n\n"
                        f"Pages: {data['pages']} | Chunks: {data['chunks']}"
                    )
                except httpx.HTTPStatusError as e:
                    detail = e.response.json().get("detail", str(e))
                    st.error(f"Upload failed: {detail}")
                except httpx.HTTPError as e:
                    st.error(f"Connection error: {e}")

    st.divider()
    st.subheader("Indexed Documents")
    try:
        docs_resp = httpx.get(f"{BACKEND_URL}/documents", timeout=10.0)
        docs_resp.raise_for_status()
        docs = docs_resp.json()
        if docs:
            for doc in docs:
                st.markdown(f"📄 {doc['source']}")
        else:
            st.caption("No documents indexed yet.")
    except Exception:
        st.caption("Could not load document list.")

# --- Main Chat Area ---
st.title("🤖 RAG Chatbot")
st.caption("Powered by Qwen3.5-9B + Qdrant + LangChain on Azure")

# Session state
if "messages" not in st.session_state:
    st.session_state.messages = []
if "session_id" not in st.session_state:
    st.session_state.session_id = str(uuid.uuid4())

# Display chat history
for msg in st.session_state.messages:
    with st.chat_message(msg["role"]):
        st.markdown(msg["content"])
        if msg.get("sources"):
            with st.expander("📄 Sources"):
                for src in msg["sources"]:
                    st.markdown(f"- {src}")

# Chat input
if prompt := st.chat_input("Ask a question about your documents..."):
    # Show user message
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)

    # Call backend
    with st.chat_message("assistant"):
        with st.spinner("Thinking..."):
            try:
                response = httpx.post(
                    f"{BACKEND_URL}/chat",
                    json={
                        "message": prompt,
                        "session_id": st.session_state.session_id,
                    },
                    timeout=120.0,
                )
                response.raise_for_status()
                data = response.json()
                answer = data["answer"]
                sources = data.get("sources", [])
            except httpx.HTTPError as e:
                answer = f"Error connecting to backend: {e}"
                sources = []

        st.markdown(answer)
        if sources:
            with st.expander("📄 Sources"):
                for src in sources:
                    st.markdown(f"- {src}")

    st.session_state.messages.append(
        {"role": "assistant", "content": answer, "sources": sources}
    )
