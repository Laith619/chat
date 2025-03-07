# OpenAI Embedding Model Fix

## Problem

Your LobeChat logs show the following error:

```
embeddingChunks error {
  message: '{"endpoint":"https://api.openai.com/v1","error":{"message":"The model `embedding-text-3-small` does not exist or you do not have access to it.","type":"invalid_request_error","param":null,"code":"model_not_found"},"errorType":"ModelNotFound","provider":"openai"}',
  name: 'EmbeddingError'
}
```

This error occurs because LobeChat is trying to use OpenAI's `embedding-text-3-small` model, which either:
1. Does not exist in your OpenAI account
2. You don't have access to it with your current API key
3. The model ID is incorrect

## Solution

You need to configure a different embedding model that is available to your OpenAI account. Here are the steps to fix this:

### 1. Using the Automated Script

Run the provided script to automatically update your embedding model to a reliable one:

```bash
./fix-lobe-chat-issues.sh
```

The script sets your embedding model to `text-embedding-ada-002`, which is widely available.

### 2. Manual Configuration

If you prefer to manually configure the embedding model:

1. Stop your LobeChat containers:
   ```bash
   docker-compose down
   ```

2. Edit your `.env` file and add or update the embedding model:
   ```
   LOBE_EMBEDDING_MODEL=text-embedding-ada-002
   ```

   Other available models you can try (depending on your OpenAI access):
   - `text-embedding-3-small` (if you have access to the new models)
   - `text-embedding-3-large` (higher quality but more expensive)

3. Restart your containers:
   ```bash
   docker-compose up -d
   ```

### 3. Configure Embedding Model in the UI

You can also configure the embedding model through the LobeChat UI:

1. Go to Settings
2. Navigate to Provider Settings
3. Select OpenAI
4. Update the Embedding Model setting
5. Save your changes

## Verifying the Fix

To verify the fix:

1. Check the LobeChat logs for any errors:
   ```bash
   docker-compose logs -f lobe-chat
   ```

2. Try to upload a file to your knowledge base. If the embedding process works properly, you should no longer see the embedding error. 