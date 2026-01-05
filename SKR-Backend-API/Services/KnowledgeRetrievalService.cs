using Microsoft.EntityFrameworkCore;
using Pgvector;
using Pgvector.EntityFrameworkCore;
using SKR_Backend_API.Data;
using SKR_Backend_API.Models;

namespace SKR_Backend_API.Services;

public interface IKnowledgeRetrievalService
{
    Task<List<PepperKnowledge>> SearchAsync(Vector embedding, int? districtId, string? varietyId, int? plantAgeMonths);
}

public class KnowledgeRetrievalService : IKnowledgeRetrievalService
{
    private readonly AppDbContext _context;

    public KnowledgeRetrievalService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<List<PepperKnowledge>> SearchAsync(Vector embedding, int? districtId, string? varietyId, int? plantAgeMonths)
    {
        // 1. Map IDs to Strings (Production Refinement)
        string? districtName = null;
        if (districtId.HasValue)
        {
            var district = await _context.Districts.FindAsync(districtId.Value);
            districtName = district?.Name;
        }

        string? varietyName = null;
        if (!string.IsNullOrEmpty(varietyId))
        {
            var variety = await _context.PepperVarieties.FindAsync(varietyId);
            varietyName = variety?.Name;
        }
        
        // Mandatory Variety Logic: Fallback to "Local" if not found or null
        if (string.IsNullOrEmpty(varietyName)) 
        {
             varietyName = "Local";
        }

        // 2. Perform Vector Search with Hard Filters
        // Using Entity Framework Core with Pgvector
        
        int currentMonth = DateTime.UtcNow.Month;
        
        // Note: L2Distance is <-> operator in pgvector. OrderBy(x => x.Embedding!.L2Distance(embedding))
        
        var query = _context.PepperKnowledge.AsQueryable();

        // Apply filters - logic matches the mandatory SQL pattern provided
        query = query.Where(k => 
            (k.District == null || k.District == districtName) &&
            (k.Variety == null || k.Variety == varietyName) &&
            (k.PlantAgeMin == null || (plantAgeMonths.HasValue && k.PlantAgeMin <= plantAgeMonths.Value)) &&
            (k.PlantAgeMax == null || (plantAgeMonths.HasValue && k.PlantAgeMax >= plantAgeMonths.Value)) &&
            (k.MonthStart == null || k.MonthEnd == null || (currentMonth >= k.MonthStart && currentMonth <= k.MonthEnd))
        );
        
        // Execute Vector Search
        var results = await query
            .OrderBy(k => k.Embedding!.L2Distance(embedding))
            .Take(5)
            .ToListAsync();

        return results;
    }
}
