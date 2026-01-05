using System.Text;
using OpenAI.Chat;
using SKR_Backend_API.Data;
using SKR_Backend_API.DTOs;
using SKR_Backend_API.Models;

namespace SKR_Backend_API.Services;

public class ChatService : IChatService
{
    private readonly AppDbContext _context;
    private readonly IEmbeddingService _embeddingService;
    private readonly IKnowledgeRetrievalService _retrievalService;
    private readonly ChatClient? _chatClient;
    private readonly ILogger<ChatService> _logger;

    public ChatService(
        AppDbContext context,
        IEmbeddingService embeddingService,
        IKnowledgeRetrievalService retrievalService,
        IConfiguration configuration,
        ILogger<ChatService> logger)
    {
        _context = context;
        _embeddingService = embeddingService;
        _retrievalService = retrievalService;
        _logger = logger;
        
        var apiKey = configuration["OpenAI:ApiKey"];
        if (string.IsNullOrEmpty(apiKey))
        {
             // Fallback or throw, but strict mode implies we need it.
             // For now, let's assume it's there or handle gracefully if not.
             _logger.LogWarning("OpenAI API Key is missing!");
        }
        else
        {
             _chatClient = new ChatClient("gpt-3.5-turbo", apiKey); 
        }
    }

    public async Task<RagChatResponse> ProcessMessageAsync(RagChatRequest request)
    {
        // 1. Determine Context (Guide Mode vs Farmer Mode)
        int? districtId = null;
        string? varietyId = null;
        int? plantAgeMonths = null;

        if (request.ActiveFarmId.HasValue)
        {
            var farm = await _context.Farms.FindAsync(request.ActiveFarmId.Value);
            if (farm != null)
            {
                 districtId = farm.DistrictId;
                 varietyId = farm.ChosenVarietyId;
                 
                 // Calculate Plant Age
                 if (farm.FarmStartDate.HasValue)
                 {
                     var now = DateTime.UtcNow;
                     var start = farm.FarmStartDate.Value; 
                     var startDate = start.Date;
                     plantAgeMonths = ((now.Year - startDate.Year) * 12) + now.Month - startDate.Month;
                     if (plantAgeMonths < 0) plantAgeMonths = 0;
                 }
            }
        }

        // 2. Generate Embedding
        var queryEmbedding = await _embeddingService.GenerateEmbeddingAsync(request.Message);
        var vector = new Pgvector.Vector(queryEmbedding);

        // 3. Retrieve Knowledge
        var knowledgeItems = await _retrievalService.SearchAsync(vector, districtId, varietyId, plantAgeMonths);
        
        // Guardrail: If no knowledge found, return fallback immediately
        if (knowledgeItems == null || !knowledgeItems.Any())
        {
            return new RagChatResponse 
            { 
                Reply = "No official recommendation available for this condition.",
                Sources = new List<string>() 
            };
        }

        // 4. Construct Prompt
        var sb = new StringBuilder();
        foreach (var k in knowledgeItems)
        {
            sb.AppendLine($"- {k.Content}");
            if (k.ConfidenceLevel == "Low")
            {
                sb.AppendLine("  (Note: General guideline only)");
            }
        }
        string knowledgeText = sb.ToString();

        var systemPrompt = @"You are a Sri Lankan black pepper farming assistant.

Rules:
- Use ONLY the provided knowledge
- Do NOT use external knowledge
- Do NOT guess or generalize
- If information is missing, say EXACTLY:
  'No official recommendation available for this condition.'
- Keep answers short, practical, and farmer-friendly";

        var userPrompt = $@"Knowledge:
{knowledgeText}

Question:
{request.Message}";

        // 5. Generate Response
        if (_chatClient == null)
        {
             return new RagChatResponse 
             { 
                 Reply = "AI Service is currently unavailable (API Key missing).",
                 Sources = new List<string>() 
             };
        }

        ChatCompletion completion = await _chatClient.CompleteChatAsync(new List<ChatMessage>
        {
            new SystemChatMessage(systemPrompt),
            new UserChatMessage(userPrompt)
        });

        return new RagChatResponse
        {
            Reply = completion.Content[0].Text,
            Sources = knowledgeItems.Select(k => k.Title).Distinct().ToList()
        };
    }
}
