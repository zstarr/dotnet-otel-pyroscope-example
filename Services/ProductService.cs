using System.Diagnostics;
using DotNetApp.Models;
using DotNetApp.Repositories;

namespace DotNetApp.Services;

/// <summary>
/// Default implementation of <see cref="IProductService"/>. Coordinates
/// business rules and delegates persistence to the repository.
/// </summary>
public class ProductService : IProductService
{
    /// <summary>
    /// ActivitySource used to emit custom spans from the service layer. The
    /// same name is registered with the tracing pipeline via AddSource(...)
    /// in Program.cs so these spans are exported over OTLP.
    /// </summary>
    public static readonly ActivitySource ActivitySource = new("DotNetApp.Services.ProductService");

    private readonly IProductRepository _repository;

    public ProductService(IProductRepository repository)
    {
        _repository = repository;
    }

    public async Task<IEnumerable<Product>> GetProductsAsync()
    {
        // Custom span nested under the active ASP.NET Core request span, so it
        // becomes part of the same trace (e.g. the GetAll request trace).
        using var activity = ActivitySource.StartActivity("GetProductsAsync");

        var products = await _repository.GetAllAsync();

        activity?.SetTag("products.count", products.Count());
        return products;
    }

    public Task<Product?> GetProductAsync(int id)
    {
        return _repository.GetByIdAsync(id);
    }

    public Task<Product> CreateProductAsync(Product product)
    {
        return _repository.AddAsync(product);
    }

    public Task<bool> UpdateProductAsync(int id, Product product)
    {
        // Ensure the route id is authoritative over the body.
        product.Id = id;
        return _repository.UpdateAsync(product);
    }

    public Task<bool> DeleteProductAsync(int id)
    {
        return _repository.DeleteAsync(id);
    }
}
