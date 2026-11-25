namespace DotNetApp.Models;

/// <summary>
/// Represents a product in the catalog.
/// </summary>
public class Product
{
    public int Id { get; set; }

    public required string Name { get; set; }

    public string? Description { get; set; }

    public decimal Price { get; set; }
}
