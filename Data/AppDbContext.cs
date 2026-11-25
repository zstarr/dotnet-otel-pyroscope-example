using DotNetApp.Models;
using Microsoft.EntityFrameworkCore;

namespace DotNetApp.Data;

/// <summary>
/// EF Core database context backed by the in-memory provider.
/// </summary>
public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options)
        : base(options)
    {
    }

    public DbSet<Product> Products => Set<Product>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Product>().Property(p => p.Price).HasPrecision(18, 2);

        // Seed a little data so the API returns something on first run.
        modelBuilder.Entity<Product>().HasData(
            new Product { Id = 1, Name = "Keyboard", Description = "Mechanical keyboard", Price = 79.99m },
            new Product { Id = 2, Name = "Mouse", Description = "Wireless mouse", Price = 39.99m },
            new Product { Id = 3, Name = "Monitor", Description = "27-inch 1440p monitor", Price = 249.99m });
    }
}
