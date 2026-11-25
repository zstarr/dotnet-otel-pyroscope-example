using System.Diagnostics.Metrics;
using DotNetApp.Models;
using DotNetApp.Services;
using Microsoft.AspNetCore.Mvc;

namespace DotNetApp.Controllers;

/// <summary>
/// REST endpoints for managing products.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    
    private readonly IProductService _service;
    private readonly ILogger<ProductsController> _logger;
    private readonly Counter<long> _productsReturned;

    public ProductsController(IProductService service, IMeterFactory meterFactory, ILogger<ProductsController> logger)
    {
        var meter = meterFactory.Create("ProductsController");
        _productsReturned = meter.CreateCounter<long>("products_returned");
        _service = service;
        _logger = logger;
        
    }
    /// <summary>Gets all products.</summary>
    ///
    [HttpGet]
    public async Task<ActionResult<IEnumerable<Product>>> GetAll()
    { 
        _logger.LogInformation("Getting all products");
        var products = await _service.GetProductsAsync();
        _productsReturned.Add(products.Count(), new KeyValuePair<string, object?>("method", "GetAll()"));
        return Ok(products);
    }

    /// <summary>Gets a single product by id.</summary>
    [HttpGet("{id:int}")]
    public async Task<ActionResult<Product>> GetById(int id)
    {
        _logger.LogInformation("Getting product by id, {id}", id);
        var product = await _service.GetProductAsync(id);
        _productsReturned.Add(1, new KeyValuePair<string, object?>("method", "GetById()"));
        return product is null ? NotFound() : Ok(product);
    }

    /// <summary>Creates a new product.</summary>
    [HttpPost]
    public async Task<ActionResult<Product>> Create(Product product)
    {
        var created = await _service.CreateProductAsync(product);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    /// <summary>Updates an existing product.</summary>
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, Product product)
    {
        var updated = await _service.UpdateProductAsync(id, product);
        return updated ? NoContent() : NotFound();
    }

    /// <summary>Deletes a product.</summary>
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _service.DeleteProductAsync(id);
        return deleted ? NoContent() : NotFound();
    }
}
