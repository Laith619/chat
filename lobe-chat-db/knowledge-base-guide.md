# LobeChat Knowledge Base User Guide

This guide will walk you through how to create, manage, and effectively use knowledge bases in LobeChat.

## What is a Knowledge Base?

A knowledge base in LobeChat is a collection of documents that you can use to enhance AI responses with specific information. Using RAG (Retrieval-Augmented Generation) technology, the AI can retrieve information from your documents to answer questions more accurately.

## Setting Up Your Knowledge Base

### Prerequisites

1. A running LobeChat instance with server database mode enabled
2. External Casdoor authentication configured
3. MinIO storage service running
4. Execute the `setup-knowledge-base.sh` script to prepare test files

### Creating a Knowledge Base

1. **Access LobeChat and Log In**
   - Go to http://localhost:3210
   - Sign in with your Casdoor credentials

2. **Navigate to Knowledge Base Section**
   - In the left sidebar, locate and click on the "Knowledge" icon (book icon)
   - If this is your first time, you'll see an empty knowledge base list

3. **Create a New Knowledge Base**
   - Click the "Create Knowledge Base" button
   - Enter a name (e.g., "Test Knowledge Base")
   - Add a description (optional but recommended)
   - Select a model for embeddings (the default should work fine)
   - Click "Create"

4. **Upload Documents**
   - In your new knowledge base, click the "Upload Files" button
   - Select files from the `test-files` directory created by the setup script
   - Supported formats include PDF, TXT, and Markdown
   - Click "Upload" to start the process

5. **Wait for Processing**
   - LobeChat will process your documents and generate embeddings
   - This may take a few minutes depending on document size
   - You'll see a progress indicator during processing
   - Once complete, your documents will appear in the knowledge base

## Using Your Knowledge Base in Conversations

1. **Start a New Chat**
   - Create a new conversation or continue an existing one
   - You should see a chat interface with a text input area

2. **Enable Knowledge Base for the Chat**
   - Look for the knowledge base icon near the send button (it may look like a database or book icon)
   - Click it to open the knowledge base selector
   - Select your previously created knowledge base
   - The knowledge base status should now show "Enabled"

3. **Ask Questions Related to Your Documents**
   - Type questions that relate to information contained in your uploaded documents
   - Send the message
   - The AI will search your knowledge base for relevant information
   - The response will incorporate information from your documents

## Example Test Questions

Try asking these questions to test your knowledge base with the sample documents:

1. "What is the capital of France according to the knowledge base?"
2. "What is the chemical formula for water?"
3. "What is the speed of light mentioned in the documents?"
4. "Show me the factorial function from the Python code example."
5. "Who wrote Romeo and Juliet according to the sample data?"
6. "What is the tallest mountain in the world?"

## Advanced Usage

### Managing Your Knowledge Base

1. **Update Documents**
   - You can upload additional documents at any time
   - Select your knowledge base and click "Upload Files"

2. **Delete Documents**
   - Navigate to your knowledge base
   - Locate the document you want to delete
   - Click the delete icon (trash can) next to the document
   - Confirm deletion

3. **Rename or Edit Knowledge Base**
   - Open your knowledge base
   - Click the "Settings" icon
   - Edit the name, description, or other settings
   - Save your changes

### Optimizing Knowledge Base Usage

1. **Be Specific in Your Questions**
   - More specific questions yield better results
   - Include key terms that might be in your documents

2. **Use Context in Conversations**
   - Begin with a prompt like "Using the knowledge base, tell me about..."
   - Reference specific documents: "From the LobeChat documentation..."

3. **Check for Citations**
   - LobeChat may include citations from your documents
   - These citations help you track which information came from your knowledge base

## Troubleshooting

### Knowledge Base Not Showing Up

1. **Verify S3 Configuration**
   - Check MinIO logs for any errors: `docker-compose logs -f lobe-minio`
   - Verify the bucket exists and has proper permissions

2. **Check Database Connection**
   - Ensure PostgreSQL is running and the PGVector extension is enabled
   - Check LobeChat logs for database errors: `docker-compose logs -f lobe-chat`

### Document Upload Failures

1. **Check File Types**
   - Ensure you're uploading supported file types (PDF, TXT, Markdown)
   - Very large files may cause issues

2. **MinIO Storage Issues**
   - Verify MinIO is running correctly
   - Check bucket permissions and CORS settings

### Poor Retrieval Results

1. **Embedding Model Issues**
   - Try changing the embedding model in knowledge base settings
   - Verify your OpenAI API key is valid

2. **Document Preprocessing**
   - Some complex documents may not be processed optimally
   - Try simplifying documents or breaking them into smaller parts

## Deleting a Knowledge Base

1. Navigate to the knowledge base list
2. Click the three dots menu next to the knowledge base
3. Select "Delete"
4. Confirm deletion when prompted

## Next Steps

After creating your test knowledge base, consider:

1. Creating knowledge bases for your own documentation
2. Experimenting with different document formats
3. Testing the knowledge base with different AI models
4. Combining knowledge base queries with other LobeChat features

---

Remember that knowledge base effectiveness depends on the quality and relevance of your documents. Keep your knowledge base updated with the most current information for best results.
