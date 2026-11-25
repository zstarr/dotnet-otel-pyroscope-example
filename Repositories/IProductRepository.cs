using DotNetApp.Models;

namespace DotNetApp.Repositories;

/// <summary>
/// Data-access abstraction for <see cref="Product"/> entities.
/// </summary>
public interface IProductRepository
{
    Task<IEnumerable<Product>> GetAllAsync();

    Task<Product?> GetByIdAsync(int id);

    Task<Product> AddAsync(Product product);

    Task<bool> UpdateAsync(Product product);

    Task<bool> DeleteAsync(int id);
}
