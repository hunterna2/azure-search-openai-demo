# Secure Financial Document RAG Chatbot

A production-grade Retrieval-Augmented Generation (RAG) system for banking compliance Q&A. Users ask questions in natural language and receive grounded answers with clickable citations back to the source PDF — no hallucination, no guessing.

**[Live Demo](https://aca-backend-banking-demo.mangostone-87dfdce5.eastus.azurecontainerapps.io)**

---

## What It Does

- Ask questions about internal banking policies, compliance documents, and employee benefits
- Answers are grounded exclusively in the uploaded documents — the model cannot fabricate information not present in the source material
- Every answer includes a citation linking back to the exact page of the source PDF
- Hybrid search (vector + keyword) ensures both conceptual and exact-term queries return relevant results

---

## Architecture

```
User Question
      │
      ▼
┌─────────────────────────────────────────────────┐
│              React Frontend (Vite)               │
│         Served by Python/Quart Backend           │
└────────────────────┬────────────────────────────┘
                     │  /chat
                     ▼
┌─────────────────────────────────────────────────┐
│                RAG Pipeline                      │
│                                                  │
│  1. GPT-4o rewrites question → search query      │
│  2. Hybrid search against AI Search index        │
│     ├── Keyword search (exact term matching)     │
│     └── Vector search (semantic similarity)      │
│  3. Top 3 chunks injected into GPT-4o prompt     │
│  4. GPT-4o generates grounded answer             │
└──────┬──────────────────────┬───────────────────┘
       │                      │
       ▼                      ▼
┌─────────────┐     ┌──────────────────────┐
│ Azure OpenAI│     │  Azure AI Search     │
│  gpt-4o     │     │  Hybrid Vector Index │
│  text-embed │     │  1,400+ chunks       │
└─────────────┘     └──────────┬───────────┘
                               │ citation lookup
                               ▼
                    ┌──────────────────────┐
                    │  Azure Blob Storage  │
                    │  Source PDFs         │
                    └──────────────────────┘

Hosted on: Azure Container Apps (Docker)
Image stored in: Azure Container Registry
```

---

## Document Ingestion Pipeline

Before the app runs, all source documents are pre-processed:

```
Local PDFs
    │
    ▼
prepdocs.py
    ├── Split each PDF into ~500 token chunks
    ├── Vectorize each chunk via text-embedding-3-small
    ├── Upload original PDFs to Azure Blob Storage
    └── Index chunks (text + vectors) into Azure AI Search
```

This runs once per document set. The search index stores both the raw text and the vector embeddings for every chunk, enabling hybrid retrieval at query time.

---

## How Hybrid Search Works

**Keyword search** matches exact terms. Good for policy names, section references, specific jargon.

**Vector search** converts both the query and every document chunk into high-dimensional number arrays (embeddings) that represent *meaning*. Chunks with similar meaning produce similar vectors. At query time the user's question is vectorized and compared against all stored vectors — returning semantically relevant chunks even when the exact words don't match.

Example: *"what happens if I get hurt at work?"* → matches chunks about *"workers' compensation"* and *"workplace injury"* via vector similarity, even with zero word overlap.

Both searches run in parallel. Azure AI Search merges the results using **Reciprocal Rank Fusion** — chunks that rank well in both lists float to the top.

---

## Key Technical Decisions

**Custom endpoint handling** — Azure OpenAI resources provisioned on Pay-As-You-Go use the regional endpoint format (`eastus.api.cognitive.microsoft.com`) rather than the per-resource subdomain format the SDK assumes by default. Added `azure_openai_endpoint_override` parameter to `servicesetup.py` to support both formats.

**API key credential fallback** — The regional endpoint does not support token-based (passwordless) authentication. Added explicit API key support as a fallback alongside managed identity for all three services: Azure OpenAI, Azure AI Search, and Azure Blob Storage.

**Vector search gating** — Added a runtime check in `chatreadretrieveread.py` that disables vector search when no embedding deployment is configured, preventing crashes on environments where only a chat model is deployed.

**Banking compliance prompt** — Custom system prompt in `chat_answer.system.jinja2` instructs the model to answer only from provided documents, cite sources by filename and page, and never speculate beyond the indexed content.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | React, Vite, TypeScript, Fluent UI |
| Backend | Python, Quart (async), Azure SDK |
| LLM | Azure OpenAI gpt-4o |
| Embeddings | Azure OpenAI text-embedding-3-small |
| Search | Azure AI Search (hybrid vector + keyword) |
| Storage | Azure Blob Storage |
| Hosting | Azure Container Apps |
| Registry | Azure Container Registry |
| IaC | Bicep, Azure Developer CLI (azd) |

---

## Source Documents

The index contains 13 banking and compliance documents including:

- BCBS Basel III Framework
- OCC Compliance Management Systems Handbook
- FDIC BSA/AML Manual
- Northwind Health Plus & Standard Benefits Details
- Employee Handbook, PerksPlus, Benefit Options
- Synthetic AML, Loan Underwriting, and Data Privacy policies

---

## Running Locally

```bash
# Clone and set up environment
git clone https://github.com/hunterna2/azure-search-openai-demo
cd azure-search-openai-demo

# Set up Python venv
cd app/backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Configure environment (copy and fill in your Azure resource values)
cp .env.example .env

# Start the app
cd ../..
./app/start.sh
```

Requires Azure OpenAI, Azure AI Search, and Azure Blob Storage resources with documents pre-indexed via `prepdocs.py`.

---

## Based On

Forked from [azure-samples/azure-search-openai-demo](https://github.com/azure-samples/azure-search-openai-demo) — Microsoft's official RAG reference architecture. Extended with custom banking compliance prompt, hybrid vector search configuration, credential fallback handling for regional Azure endpoints, and UI customization for financial domain use.
