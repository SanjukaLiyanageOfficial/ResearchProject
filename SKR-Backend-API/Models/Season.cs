using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SKR_Backend_API.Models;

[Table("HarvestSeasons")]
public class Season
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [MaxLength(100)]
    [Column("seasonname")]
    public string SeasonName { get; set; } = string.Empty;

    [Column("startmonth")]
    public int StartMonth { get; set; }

    [Column("startyear")]
    public int StartYear { get; set; }

    [Column("endmonth")]
    public int EndMonth { get; set; }

    [Column("endyear")]
    public int EndYear { get; set; }

    [Required]
    [Column("farmid")]
    public Guid FarmId { get; set; }

    [Required]
    [Column("createdby")]
    public Guid CreatedBy { get; set; }
}

