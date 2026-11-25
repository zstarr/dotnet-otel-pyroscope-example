using DotNetApp.Models;

namespace DotNetApp.Services;

/// <summary>
/// Business-logic abstraction for working with <see cref="Product"/> entities.
/// </summary>
public interface IProductService
{
    Task<IEnumerable<Product>> GetProductsAsync();

    Task<Product?> GetProductAsync(int id);

    Task<Product> CreateProductAsync(Product product);

    Task<bool> UpdateProductAsync(int id, Product product);

    Task<bool> DeleteProductAsync(int id);
}
